package main

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// Mailgun takes mail either over SMTP or over its own HTTP endpoint. The
// endpoint is the safer bet on a host: outbound SMTP ports are a favourite
// thing for platforms to block, and a blocked port fails as a timeout deep
// inside net/smtp, while a rejected API call comes back as a sentence saying
// what was wrong.
type mailgunMailer struct {
	base, domain, key, from string
	client                  *http.Client
}

func (m mailgunMailer) Send(to, subject, body string) error {
	form := url.Values{
		"from":    {m.from},
		"to":      {to},
		"subject": {subject},
		"text":    {body},
	}
	endpoint := strings.TrimSuffix(m.base, "/") + "/" + m.domain + "/messages"
	req, err := http.NewRequest("POST", endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth("api", m.key)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := m.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		said, _ := io.ReadAll(io.LimitReader(resp.Body, 500))
		return fmt.Errorf("mailgun %s: %s", resp.Status, strings.TrimSpace(string(said)))
	}
	return nil
}

func newMailgunMailer() (Mailer, bool) {
	domain := os.Getenv("WANDERFALL_MAILGUN_DOMAIN")
	key := os.Getenv("WANDERFALL_MAILGUN_KEY")
	if domain == "" || key == "" {
		return nil, false
	}
	base := os.Getenv("WANDERFALL_MAILGUN_BASE")
	if base == "" {
		base = "https://api.mailgun.net/v3"
	}
	from := os.Getenv("WANDERFALL_SMTP_FROM")
	if from == "" {
		from = "Wanderfall <wanderfall@" + domain + ">"
	}
	return mailgunMailer{base: base, domain: domain, key: key, from: from,
		client: &http.Client{Timeout: 15 * time.Second}}, true
}
