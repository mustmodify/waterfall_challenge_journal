package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Email   string `json:"email"`
	IsAdmin bool   `json:"is_admin"`
}

func generateToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func startSession(w http.ResponseWriter, userID int) error {
	token, err := generateToken()
	if err != nil {
		return err
	}
	if _, err := db.Exec(`INSERT INTO sessions (token, user_id) VALUES ($1, $2)`, token, userID); err != nil {
		return err
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		// Ten years. There is no server-side expiry either: a session row lives
		// until sign-out. Losing a session here costs someone their waterfall
		// list, not their bank account.
		Expires: time.Now().Add(10 * 365 * 24 * time.Hour),
	})
	return nil
}

func currentUser(r *http.Request) *User {
	c, err := r.Cookie("session")
	if err != nil || c.Value == "" {
		return nil
	}
	var u User
	err = db.QueryRow(`
		SELECT users.id, users.name, users.email, users.is_admin
		FROM sessions JOIN users ON users.id = sessions.user_id
		WHERE sessions.token = $1
	`, c.Value).Scan(&u.ID, &u.Name, &u.Email, &u.IsAdmin)
	if err != nil {
		return nil
	}
	return &u
}

type credentials struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func signup(w http.ResponseWriter, r *http.Request) {
	var req credentials
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))
	if req.Name == "" || req.Email == "" || len(req.Password) < 8 {
		http.Error(w, "Name, email, and a password of at least 8 characters are required", http.StatusBadRequest)
		return
	}

	digest, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var u User
	err = db.QueryRow(`
		INSERT INTO users (name, email, password_digest) VALUES ($1, $2, $3)
		RETURNING id, name, email
	`, req.Name, req.Email, string(digest)).Scan(&u.ID, &u.Name, &u.Email)
	if err != nil {
		if uniqueViolation(err) {
			http.Error(w, "An account with that email already exists", http.StatusConflict)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := startSession(w, u.ID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}

func login(w http.ResponseWriter, r *http.Request) {
	var req credentials
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	var u User
	var digest string
	err := db.QueryRow(`SELECT id, name, email, password_digest FROM users WHERE email = $1`, req.Email).
		Scan(&u.ID, &u.Name, &u.Email, &digest)
	if err == sql.ErrNoRows || (err == nil && bcrypt.CompareHashAndPassword([]byte(digest), []byte(req.Password)) != nil) {
		http.Error(w, "Invalid email or password", http.StatusUnauthorized)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := startSession(w, u.ID); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

func logout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie("session"); err == nil {
		db.Exec(`DELETE FROM sessions WHERE token = $1`, c.Value)
	}
	http.SetCookie(w, &http.Cookie{Name: "session", Value: "", Path: "/", HttpOnly: true, MaxAge: -1})
	w.WriteHeader(http.StatusNoContent)
}

func me(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	if u == nil {
		http.Error(w, "Not logged in", http.StatusUnauthorized)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}
