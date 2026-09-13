package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestMailgunSendsWhatMailgunExpects(t *testing.T) {
	var gotPath, gotUser, gotPass, gotBody string
	var hadAuth bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotUser, gotPass, hadAuth = r.BasicAuth()
		b := make([]byte, r.ContentLength)
		r.Body.Read(b)
		gotBody = string(b)
		w.WriteHeader(200)
	}))
	defer srv.Close()

	t.Setenv("WANDERFALL_MAILGUN_DOMAIN", "mustmodify.com")
	t.Setenv("WANDERFALL_MAILGUN_KEY", "key-secret")
	t.Setenv("WANDERFALL_MAILGUN_BASE", srv.URL+"/v3")
	t.Setenv("WANDERFALL_SMTP_FROM", "Wanderfall <wanderful@mustmodify.com>")
	initMailer()

	if !mailConfigured() {
		t.Fatal("mailgun config was ignored")
	}
	if err := mailer.Send("hiker@example.com", "Sign in", "here is your link"); err != nil {
		t.Fatalf("send: %v", err)
	}
	if gotPath != "/v3/mustmodify.com/messages" {
		t.Errorf("posted to %q", gotPath)
	}
	if !hadAuth || gotUser != "api" || gotPass != "key-secret" {
		t.Errorf("auth was %q/%q (present: %v)", gotUser, gotPass, hadAuth)
	}
	for _, want := range []string{"from=Wanderfall+%3Cwanderful%40mustmodify.com%3E",
		"to=hiker%40example.com", "subject=Sign+in"} {
		if !strings.Contains(gotBody, want) {
			t.Errorf("body %q is missing %q", gotBody, want)
		}
	}
}

func TestMailgunReportsWhatWentWrong(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(401)
		w.Write([]byte(`{"message":"Invalid private key"}`))
	}))
	defer srv.Close()

	m := mailgunMailer{base: srv.URL + "/v3", domain: "mustmodify.com", key: "wrong",
		from: "a@b.c", client: srv.Client()}
	err := m.Send("hiker@example.com", "Sign in", "link")
	if err == nil || !strings.Contains(err.Error(), "Invalid private key") {
		t.Fatalf("error was %v", err)
	}
}
