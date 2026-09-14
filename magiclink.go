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

// A sign-in link is a key to the account for as long as it lasts, and it
// travels through email -- so it sits in an inbox, in forwards, and in
// whatever the mail provider keeps. Two days is a deliberate trade of that
// exposure for not making somebody ask twice because they read their mail
// after lunch. It is still single use, so the window closes the moment it is
// followed, and the hour it is most exposed is the hour it is most likely to
// already have been spent.
const linkTTL = 48 * time.Hour

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

	// A link in the log is a sign-in credential sitting in plain text for its
	// whole lifetime. Worth it on a laptop with no mail transport, where
	// the alternative is no way to sign in at all; never once mail works.
	if mailConfigured() {
		// Synchronous, unlike the correction notice. A correction is already
		// saved by the time the mail goes out, so losing it costs a
		// notification; a sign-in link that is never delivered leaves somebody
		// waiting on a mail that is not coming. They have to be told.
		subject, body := magicLinkEmail(link)
		if err := mailer.Send(email, subject, body); err != nil {
			log.Printf("magic link to %s failed: %v", email, err)
			http.Error(w, "Could not send the sign-in email. Please try again in a moment.",
				http.StatusBadGateway)
			return
		}
		log.Printf("magic link sent to %s", email)
	} else {
		log.Printf("magic link for %s: %s", email, link)
	}

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
	if err := startSession(w, r, userID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/?auth=ok", http.StatusSeeOther)
}
