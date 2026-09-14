package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// signedInAs gives the request a session cookie for a freshly made user, so
// the gate is exercised the way a browser would exercise it rather than by
// calling requireAdmin directly.
func signedInAs(t *testing.T, email string, admin bool) *http.Request {
	t.Helper()
	var id int
	if err := db.QueryRow(`
		INSERT INTO users (name, email, is_admin) VALUES ($1, $2, $3)
		ON CONFLICT (email) DO UPDATE SET is_admin = EXCLUDED.is_admin
		RETURNING id`, "Tester", email, admin).Scan(&id); err != nil {
		t.Fatalf("make user: %v", err)
	}
	token, err := generateToken()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO sessions (token, user_id) VALUES ($1, $2)`, token, id); err != nil {
		t.Fatalf("make session: %v", err)
	}
	r := httptest.NewRequest("GET", "/users", nil)
	r.AddCookie(&http.Cookie{Name: "session", Value: token})
	return r
}

// The list carries every address on the site, so the gate matters more than
// the contents.
func TestUserListIsAdminOnly(t *testing.T) {
	conn := testDB(t)
	defer conn.Close()
	db = conn

	t.Run("signed out", func(t *testing.T) {
		w := httptest.NewRecorder()
		listUsers(w, httptest.NewRequest("GET", "/users", nil))
		if w.Code != http.StatusUnauthorized {
			t.Errorf("status %d, want 401", w.Code)
		}
		if w.Body.Len() > 0 && json.Valid(w.Body.Bytes()) {
			t.Error("an unauthenticated caller got a JSON body")
		}
	})

	t.Run("signed in, not admin", func(t *testing.T) {
		w := httptest.NewRecorder()
		listUsers(w, signedInAs(t, "ordinary@example.com", false))
		if w.Code != http.StatusForbidden {
			t.Errorf("status %d, want 403", w.Code)
		}
	})

	t.Run("admin", func(t *testing.T) {
		w := httptest.NewRecorder()
		listUsers(w, signedInAs(t, "boss@example.com", true))
		if w.Code != http.StatusOK {
			t.Fatalf("status %d: %s", w.Code, w.Body.String())
		}
	})
}

// The reason this endpoint exists: somebody who asked for a link and never
// used one has to be visible as such.
func TestUserListShowsWhoNeverGotIn(t *testing.T) {
	conn := testDB(t)
	defer conn.Close()
	db = conn

	// Unique per run: the row is asserted to have exactly one link, and a
	// fixed address would accumulate one more on every run against the same
	// database.
	stranded := fmt.Sprintf("never-arrived-%d@example.com", time.Now().UnixNano())
	var id int
	if err := db.QueryRow(`
		INSERT INTO users (name, email) VALUES ('Stranded', $1)
		RETURNING id`, stranded).Scan(&id); err != nil {
		t.Fatal(err)
	}
	// A link issued and never consumed is exactly what the bug produced. The
	// hash is a real one because token_hash is unique, and a literal would
	// pass on a fresh database and collide on the second run against the same
	// one.
	token, err := generateToken()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`
		INSERT INTO magic_links (user_id, token_hash, expires_at)
		VALUES ($1, $2, now() + interval '20 minutes')`, id, hashToken(token)); err != nil {
		t.Fatal(err)
	}

	w := httptest.NewRecorder()
	listUsers(w, signedInAs(t, "boss2@example.com", true))
	if w.Code != http.StatusOK {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var rows []adminUser
	if err := json.Unmarshal(w.Body.Bytes(), &rows); err != nil {
		t.Fatalf("decode: %v", err)
	}

	var found *adminUser
	for i := range rows {
		if rows[i].Email == stranded {
			found = &rows[i]
		}
	}
	if found == nil {
		t.Fatal("the stranded account is missing from the list")
	}
	if found.SignedIn {
		t.Error("an account that never used a link reads as signed in")
	}
	if found.LinksIssued != 1 || found.LinksUsed != 0 {
		t.Errorf("issued %d used %d, want 1 and 0", found.LinksIssued, found.LinksUsed)
	}

	// The admin doing the looking has a session, so the other side reads right.
	for _, u := range rows {
		if u.Email == "boss2@example.com" && !u.SignedIn {
			t.Error("an account with a live session reads as never signed in")
		}
	}
}
