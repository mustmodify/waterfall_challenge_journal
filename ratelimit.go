package main

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Two endpoints send mail on an anonymous request: /auth/request mails a sign-in
// link to whatever address it is given, and /corrections mails the owner. Left
// open, either one turns the app into a way to mail a stranger repeatedly from
// an address they cannot block.
//
// A bucket per address, refilled steadily, so an ordinary person who mistypes
// an email three times is never the one who notices this exists.
type limiter struct {
	mu      sync.Mutex
	seen    map[string]*bucket
	burst   float64
	perHour float64
}

type bucket struct {
	tokens float64
	last   time.Time
}

func newLimiter(burst, perHour float64) *limiter {
	return &limiter{seen: map[string]*bucket{}, burst: burst, perHour: perHour}
}

func (l *limiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	b, ok := l.seen[key]
	if !ok {
		b = &bucket{tokens: l.burst, last: now}
		l.seen[key] = b
	}
	b.tokens += now.Sub(b.last).Hours() * l.perHour
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.last = now

	// Anything at full tokens is indistinguishable from a caller we have never
	// seen, so the map cannot grow without bound.
	if len(l.seen) > 10000 {
		for k, v := range l.seen {
			if v.tokens >= l.burst && k != key {
				delete(l.seen, k)
			}
		}
	}

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

func clientIP(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		return strings.TrimSpace(strings.Split(fwd, ",")[0])
	}
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}

func (l *limiter) guard(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !l.allow(clientIP(r)) {
			w.Header().Set("Retry-After", "600")
			http.Error(w, "Too many requests. Try again in a few minutes.",
				http.StatusTooManyRequests)
			return
		}
		next(w, r)
	}
}
