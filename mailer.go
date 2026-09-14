package main

import (
	"fmt"
	"log"
	"net/smtp"
	"os"
	"strings"
	"time"
)

// SMTP rather than a provider SDK: Resend, Postmark, SES and Mailgun all speak
// it, so switching between them is environment variables rather than code.
type Mailer interface {
	Send(to, subject, body string) error
}

type logMailer struct{}

func (logMailer) Send(to, subject, body string) error {
	log.Printf("[no mail transport configured] would send to %s\nSubject: %s\n%s", to, subject, body)
	return nil
}

type smtpMailer struct {
	host, port, user, pass, from, envelope string
}

func (m smtpMailer) Send(to, subject, body string) error {
	msg := "From: " + m.from + "\r\n" +
		"To: " + to + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"Content-Type: text/plain; charset=utf-8\r\n\r\n" +
		body
	addr := m.host + ":" + m.port
	var auth smtp.Auth
	if m.user != "" {
		auth = smtp.PlainAuth("", m.user, m.pass, m.host)
	}
	return smtp.SendMail(addr, auth, m.envelope, []string{to}, []byte(msg))
}

var mailer Mailer = logMailer{}

var notifyAddress = "jw@mustmodify.com"

func initMailer() {
	if v := os.Getenv("WANDERFALL_NOTIFY_EMAIL"); v != "" {
		notifyAddress = v
	}
	if mg, ok := newMailgunMailer(); ok {
		mailer = mg
		log.Printf("mail via the Mailgun API as %s", mg.(mailgunMailer).from)
		return
	}
	host := os.Getenv("WANDERFALL_SMTP_HOST")
	if host == "" {
		log.Printf("no WANDERFALL_SMTP_HOST: mail will be written to this log, not sent")
		return
	}
	port := os.Getenv("WANDERFALL_SMTP_PORT")
	if port == "" {
		port = "587"
	}
	from := os.Getenv("WANDERFALL_SMTP_FROM")
	if from == "" {
		from = "wanderfall@" + host
	}
	// The header may read "Wanderfall <wanderful@mustmodify.com>"; the envelope
	// sender has to be the bare address, and Mailgun rejects the whole message
	// if it is handed the display name instead.
	envelope := from
	if i := strings.LastIndex(from, "<"); i >= 0 {
		envelope = strings.TrimSuffix(from[i+1:], ">")
	}
	mailer = smtpMailer{
		host: host, port: port, from: from, envelope: envelope,
		user: os.Getenv("WANDERFALL_SMTP_USER"),
		pass: os.Getenv("WANDERFALL_SMTP_PASS"),
	}
	log.Printf("mail via %s:%s as %s", host, port, envelope)
}

// Asks whether mail goes anywhere, by naming the one transport that does not.
// Listing the transports that do was the same shape of mistake as the handler
// that never called one: a new transport is added somewhere else, this is not
// updated, and sign-in quietly goes back to writing credentials to the log.
func mailConfigured() bool {
	_, toTheLog := mailer.(logMailer)
	return !toTheLog
}

// Errors are logged and swallowed on purpose: a report already written to the
// database is saved whether or not the notification got out, and losing it
// because a mail server was unreachable would be the worse failure.
func sendAsync(to, subject, body string) {
	go func() {
		if err := mailer.Send(to, subject, body); err != nil {
			log.Printf("mail to %s failed: %v", to, err)
		}
	}()
}

// Says a duration the way a person would, so the mail can quote linkTTL
// directly and never drift from the code that enforces it.
func humanDuration(d time.Duration) string {
	switch {
	case d >= 48*time.Hour:
		return fmt.Sprintf("%d days", int(d.Hours())/24)
	case d >= 24*time.Hour:
		return "a day"
	case d >= 2*time.Hour:
		return fmt.Sprintf("%d hours", int(d.Hours()))
	case d >= time.Hour:
		return "an hour"
	default:
		return fmt.Sprintf("%d minutes", int(d.Minutes()))
	}
}

// The link is the whole message: no HTML, no tracking, nothing to click but
// the one thing the reader asked for. The expiry is read off linkTTL so the
// sentence cannot drift away from the code that enforces it.
func magicLinkEmail(link string) (string, string) {
	subject := "Your Wanderfall sign-in link"
	body := fmt.Sprintf(
		"Follow this link to sign in:\n\n%s\n\n"+
			"It can be used once and expires in %s.\n\n"+
			"If you did not ask to sign in, nothing has happened to your account "+
			"and you can ignore this.\n",
		link, humanDuration(linkTTL))
	return subject, body
}

func fieldLabel(f string) string {
	switch f {
	case "location":
		return "the pin is in the wrong place"
	case "name":
		return "the name is wrong"
	case "access":
		return "access has changed"
	case "gone":
		return "it is not there any more"
	case "rating":
		return "a rating is wrong"
	case "missing":
		return "a place is missing"
	}
	return "something else"
}

func correctionEmail(place, field, suggested, comment, who string, featureID *int) (string, string) {
	subject := "Wanderfall correction: " + place
	var b strings.Builder
	fmt.Fprintf(&b, "%s\n\n", fieldLabel(field))
	fmt.Fprintf(&b, "Place:     %s\n", place)
	if featureID != nil {
		fmt.Fprintf(&b, "Feature:   %d\n", *featureID)
	}
	fmt.Fprintf(&b, "From:      %s\n\n", who)
	fmt.Fprintf(&b, "%s\n", comment)
	if suggested != "" {
		fmt.Fprintf(&b, "\nSuggested: %s\n", suggested)
	}
	return subject, b.String()
}
