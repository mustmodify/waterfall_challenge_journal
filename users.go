package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"
)

// The account list exists to answer an operational question rather than to
// admire the membership: did the person who asked to sign in actually get in.
// For twenty-four hours the answer was no for everybody, because the sign-in
// handler built a link and never handed it to the mailer, and nothing in the
// app could see that. A row here that has been issued links and never used one
// is that failure, visible.
type adminUser struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	IsAdmin   bool   `json:"is_admin"`
	CreatedAt string `json:"created_at"`

	LinksIssued int     `json:"links_issued"`
	LinksUsed   int     `json:"links_used"`
	LastLinkAt  *string `json:"last_link_at,omitempty"`

	Sessions      int     `json:"sessions"`
	LastSessionAt *string `json:"last_session_at,omitempty"`

	Visits int `json:"visits"`

	// SignedIn is the summary worth reading: a link was consumed, or a session
	// exists from the password era. False with LinksIssued above zero is
	// somebody who asked and never arrived.
	SignedIn bool `json:"signed_in"`
}

func stamp(t sql.NullTime) *string {
	if !t.Valid {
		return nil
	}
	s := t.Time.UTC().Format(time.RFC3339)
	return &s
}

// Aggregated in subqueries rather than by joining the three tables directly:
// a user with two links, one session and forty visits would otherwise appear
// eighty times and be counted that way.
func listUsers(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}

	rows, err := db.Query(`
		SELECT u.id, u.name, u.email, u.is_admin, u.created_at,
		       COALESCE(l.issued, 0), COALESCE(l.used, 0), l.last_issued,
		       COALESCE(s.sessions, 0), s.last_session,
		       COALESCE(v.visits, 0)
		FROM users u
		LEFT JOIN (
			SELECT user_id,
			       count(*)         AS issued,
			       count(used_at)   AS used,
			       max(created_at)  AS last_issued
			FROM magic_links GROUP BY user_id
		) l ON l.user_id = u.id
		LEFT JOIN (
			SELECT user_id,
			       count(*)        AS sessions,
			       max(created_at) AS last_session
			FROM sessions GROUP BY user_id
		) s ON s.user_id = u.id
		LEFT JOIN (
			SELECT user_id, count(*) AS visits
			FROM visits GROUP BY user_id
		) v ON v.user_id = u.id
		ORDER BY u.created_at DESC, u.id DESC
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []adminUser{}
	for rows.Next() {
		var u adminUser
		var created time.Time
		var lastLink, lastSession sql.NullTime
		if err := rows.Scan(&u.ID, &u.Name, &u.Email, &u.IsAdmin, &created,
			&u.LinksIssued, &u.LinksUsed, &lastLink,
			&u.Sessions, &lastSession, &u.Visits); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		u.CreatedAt = created.UTC().Format(time.RFC3339)
		u.LastLinkAt = stamp(lastLink)
		u.LastSessionAt = stamp(lastSession)
		u.SignedIn = u.LinksUsed > 0 || u.Sessions > 0
		out = append(out, u)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}
