package main

import "testing"

func TestLimiterBurstThenRefill(t *testing.T) {
	l := newLimiter(5, 5)
	for i := 0; i < 5; i++ {
		if !l.allow("1.2.3.4") {
			t.Fatalf("request %d refused inside the burst", i+1)
		}
	}
	if l.allow("1.2.3.4") {
		t.Fatal("sixth request allowed")
	}
	if !l.allow("5.6.7.8") {
		t.Fatal("a different address was refused")
	}
}

func TestEnvelopeSenderStripsDisplayName(t *testing.T) {
	t.Setenv("WANDERFALL_SMTP_HOST", "smtp.mailgun.org")
	t.Setenv("WANDERFALL_SMTP_FROM", "Wanderfall <wanderful@mustmodify.com>")
	initMailer()
	m, ok := mailer.(smtpMailer)
	if !ok {
		t.Fatal("mailer was not configured")
	}
	if m.envelope != "wanderful@mustmodify.com" {
		t.Fatalf("envelope sender is %q", m.envelope)
	}
	if m.from != "Wanderfall <wanderful@mustmodify.com>" {
		t.Fatalf("From header is %q", m.from)
	}
}
