package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"
)

// linkTTL is deliberately short. The session it creates lasts years; the link
// that creates it should not, because it travels through email and lands in
// logs, forwards and browser history.
const linkTTL = 20 * time.Minute

var emailish = regexp.MustCompile(`^[^@\s]+@[^@\s.]+\.[^@\s]+$`)

func hashToken(t string) string {
	sum := sha256.Sum256([]byte(t))
	return hex.EncodeToString(sum[:])
}

// nameFromEmail gives a new account something to show until the person says
// otherwise. "jane.doe@example.com" -> "Jane Doe".
func nameFromEmail(email string) string {
	local := strings.SplitN(email, "@", 2)[0]
	local = strings.NewReplacer(".", " ", "_", " ", "-", " ").Replace(local)
	parts := strings.Fields(local)
	for i, p := range parts {
		parts[i] = strings.ToUpper(p[:1]) + p[1:]
	}
	if len(parts) == 0 {
		return "Wanderer"
	}
	return strings.Join(parts, " ")
}

func requestMagicLink(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
		Name  string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if !emailish.MatchString(email) {
		http.Error(w, "That does not look like an email address", http.StatusBadRequest)
		return
	}

	// Sign-in and sign-up are the same act now: if we have never seen the
	// address, the link creates the account when it is followed.
	var userID int
	err := db.QueryRow(`SELECT id FROM users WHERE email = $1`, email).Scan(&userID)
	if err == sql.ErrNoRows {
		name := strings.TrimSpace(req.Name)
		if name == "" {
			name = nameFromEmail(email)
		}
		err = db.QueryRow(`INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id`,
			name, email).Scan(&userID)
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	token, err := generateToken()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if _, err := db.Exec(`
		INSERT INTO magic_links (user_id, token_hash, expires_at) VALUES ($1, $2, $3)
	`, userID, hashToken(token), time.Now().Add(linkTTL)); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	link := scheme + "://" + r.Host + "/auth/callback?token=" + url.QueryEscape(token)

	// There is no mail transport yet, so the link goes to the server log. That
	// is fine for one person on a laptop and completely unacceptable in public:
	// anyone who can read the log can sign in as anyone who asked for a link.
	log.Printf("magic link for %s: %s", email, link)

	resp := map[string]any{"ok": true}
	// Opt-in echo for local use. Off unless explicitly asked for, because
	// returning the token in the HTTP response would let anyone sign in as
	// anyone by simply requesting a link for their address.
	if os.Getenv("WANDERFALL_ECHO_LINKS") == "1" {
		resp["link"] = link
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func consumeMagicLink(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Redirect(w, r, "/?auth=missing", http.StatusSeeOther)
		return
	}

	// Single use and time limited, checked in the UPDATE so two simultaneous
	// clicks cannot both win.
	var userID int
	err := db.QueryRow(`
		UPDATE magic_links SET used_at = now()
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
		RETURNING user_id
	`, hashToken(token)).Scan(&userID)
	if err == sql.ErrNoRows {
		http.Redirect(w, r, "/?auth=expired", http.StatusSeeOther)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := startSession(w, userID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/?auth=ok", http.StatusSeeOther)
}
