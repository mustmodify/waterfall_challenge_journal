package main

import (
	"net/http/httptest"
	"strings"
	"testing"
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
