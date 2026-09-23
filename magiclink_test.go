package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

// recordingMailer stands in for a transport so the test can ask the question
// that matters: did the handler hand the link to anything at all. The bug this
// guards against was not a broken transport -- Mailgun worked, and its own
// test passed the whole time. The handler simply never called it.
type recordingMailer struct {
	to, subject, body string
	sent              int
	fail              error
}

func (m *recordingMailer) Send(to, subject, body string) error {
	if m.fail != nil {
		return m.fail
	}
	m.to, m.subject, m.body = to, subject, body
	m.sent++
	return nil
}

// The handler writes a user and a magic_links row, so it needs a real
// database. Point TEST_DATABASE_URL at a scratch one to run these.
func testDB(t *testing.T) *sql.DB {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set TEST_DATABASE_URL to run the sign-in tests")
	}
	conn, err := sql.Open("postgres", url)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := conn.Ping(); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return conn
}

func postSignIn(t *testing.T, email string) *httptest.ResponseRecorder {
	t.Helper()
	w := httptest.NewRecorder()
	r := httptest.NewRequest("POST", "/auth/request",
		strings.NewReader(`{"email":"`+email+`"}`))
	r.Header.Set("X-Forwarded-Proto", "https")
	requestMagicLink(w, r)
	return w
}

func TestSignInActuallyMailsTheLink(t *testing.T) {
	db = borrowDB(t)

	rec := &recordingMailer{}
	old := mailer
	mailer = rec
	defer func() { mailer = old }()

	w := postSignIn(t, "harness-sends@example.com")

	if w.Code != http.StatusOK {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	if rec.sent != 1 {
		t.Fatalf("handler sent %d mails, want 1 -- the link was never handed to the transport", rec.sent)
	}
	if rec.to != "harness-sends@example.com" {
		t.Errorf("sent to %q", rec.to)
	}
	if !strings.Contains(rec.body, "/auth/callback?token=") {
		t.Errorf("body carries no sign-in link: %q", rec.body)
	}
	if rec.subject == "" {
		t.Error("no subject")
	}
	// The token belongs in the mail and nowhere else.
	var resp map[string]any
	json.Unmarshal(w.Body.Bytes(), &resp)
	if _, leaked := resp["link"]; leaked {
		t.Error("the HTTP response carried the link")
	}
}

func TestSignInSaysSoWhenTheMailFails(t *testing.T) {
	db = borrowDB(t)

	rec := &recordingMailer{fail: http.ErrServerClosed}
	old := mailer
	mailer = rec
	defer func() { mailer = old }()

	w := postSignIn(t, "harness-fails@example.com")

	// Reporting success here is what would leave somebody waiting on a mail
	// that is never coming.
	if w.Code == http.StatusOK {
		t.Fatalf("a failed send reported success: %s", w.Body.String())
	}
	if w.Code != http.StatusBadGateway {
		t.Errorf("status %d, want 502", w.Code)
	}
}
