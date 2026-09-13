package main

import (
	"fmt"
	"log"
	"net/smtp"
	"os"
	"strings"
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
	host, port, user, pass, from string
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
	return smtp.SendMail(addr, auth, m.from, []string{to}, []byte(msg))
}

var mailer Mailer = logMailer{}

var notifyAddress = "jw@mustmodify.com"

func initMailer() {
	if v := os.Getenv("WANDERFALL_NOTIFY_EMAIL"); v != "" {
		notifyAddress = v
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
	mailer = smtpMailer{
		host: host, port: port, from: from,
		user: os.Getenv("WANDERFALL_SMTP_USER"),
		pass: os.Getenv("WANDERFALL_SMTP_PASS"),
	}
	log.Printf("mail via %s:%s as %s", host, port, from)
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
