package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/mux"
)

func TestRobotsKeepsPrivatePagesOutAndNamesTheSitemap(t *testing.T) {
	w := httptest.NewRecorder()
	robotsHandler(w, httptest.NewRequest("GET", "/robots.txt", nil))
	body := w.Body.String()

	for _, want := range []string{"Sitemap: https://wanderfall.app/sitemap.xml",
		"Disallow: /account", "Disallow: /auth/"} {
		if !strings.Contains(body, want) {
			t.Errorf("robots.txt is missing %q", want)
		}
	}
	if ct := w.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/plain") {
		t.Errorf("served as %q", ct)
	}
}

func TestAreaDescriptionCountsWhatItHas(t *testing.T) {
	miles := "2.4"
	features := []areaFeature{
		{Name: "One Falls", HikeDistance: &miles},
		{Name: "Two Falls"},
		{Name: "Three Falls", HikeDistance: &miles},
	}
	got := describeArea("Brevard", features)
	for _, want := range []string{"3 waterfalls", "Brevard", "for 2 of them"} {
		if !strings.Contains(got, want) {
			t.Errorf("description %q is missing %q", got, want)
		}
	}
	if got := describeArea("Valdese", []areaFeature{{Name: "Only Falls"}}); !strings.Contains(got, "1 waterfall and") {
		t.Errorf("a single fall reads as %q", got)
	}
}

// placeRouter wires up the two routes placeHandler cares about.
// It mirrors the registration in main() so the handler sees the same mux
// vars a real request would.
func placeRouter() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/falls/{ref}", placeHandler).Methods("GET")
	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	}).Methods("GET")
	return r
}

// TestPlaceHandlerRouting covers the six routing outcomes documented in PR #33:
// canonical URL, wrong slug, bare id, non-numeric id, unknown id, and the
// legacy ?waterfall= query link at the root.
func TestPlaceHandlerRouting(t *testing.T) {
	// Pull one real waterfall from the live database so the id and slug are
	// known-good without hardcoding values that could change.
	var id int
	var slug string
	if err := db.QueryRow(
		`SELECT id, slug FROM features WHERE kind = 'waterfall' AND deprecated_reason IS NULL ORDER BY id LIMIT 1`,
	).Scan(&id, &slug); err != nil {
		t.Fatal("could not read a waterfall from the database:", err)
	}
	canonical := fmt.Sprintf("%d-%s", id, slug)

	router := placeRouter()

	cases := []struct {
		name         string
		path         string
		wantCode     int
		wantLocation string
	}{
		{
			name:     "canonical URL serves the app",
			path:     "/falls/" + canonical,
			wantCode: http.StatusOK,
		},
		{
			name:         "wrong slug redirects to canonical",
			path:         fmt.Sprintf("/falls/%d-wrong-slug", id),
			wantCode:     http.StatusMovedPermanently,
			wantLocation: "/falls/" + canonical,
		},
		{
			name:         "bare id redirects to canonical",
			path:         fmt.Sprintf("/falls/%d", id),
			wantCode:     http.StatusMovedPermanently,
			wantLocation: "/falls/" + canonical,
		},
		{
			name:     "non-numeric id is a 404",
			path:     "/falls/not-a-number",
			wantCode: http.StatusNotFound,
		},
		{
			name:     "unknown id is a 404",
			path:     "/falls/999999999-ghost",
			wantCode: http.StatusNotFound,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			router.ServeHTTP(w, httptest.NewRequest("GET", tc.path, nil))
			if w.Code != tc.wantCode {
				t.Errorf("GET %s: got %d, want %d", tc.path, w.Code, tc.wantCode)
			}
			if tc.wantLocation != "" {
				if got := w.Header().Get("Location"); got != tc.wantLocation {
					t.Errorf("GET %s: Location %q, want %q", tc.path, got, tc.wantLocation)
				}
			}
		})
	}
}

// TestRootAcceptsWaterfallQueryParam checks that the root still serves the app
// when a ?waterfall= link arrives (old share links before /falls/ URLs existed).
func TestRootAcceptsWaterfallQueryParam(t *testing.T) {
	router := placeRouter()
	w := httptest.NewRecorder()
	router.ServeHTTP(w, httptest.NewRequest("GET", "/?waterfall=dry-falls", nil))
	if w.Code != http.StatusOK {
		t.Errorf("GET /?waterfall=dry-falls: got %d, want 200", w.Code)
	}
}
