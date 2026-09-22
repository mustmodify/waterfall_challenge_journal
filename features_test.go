package main

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
)

// The map builds a shareable URL from a feature's slug: open a pin and the
// address bar becomes /falls/<id>-<slug>. That worked in the browser code
// from the day it was written and did nothing for months, because /features
// never returned slug -- so goal.slug was always undefined and the branch
// that sets the URL never ran.
//
// Nothing caught it. The one slug test we had (pages_test.go) exercises the
// /falls redirect and reads slug straight from the database, so it passes
// whether or not the API ever sends the field. This asserts the API's side of
// that boundary instead: the shape the front end actually consumes.
func TestFeaturesServesSlugForEveryFeature(t *testing.T) {
	w := httptest.NewRecorder()
	getFeatures(w, httptest.NewRequest("GET", "/features", nil))

	if w.Code != 200 {
		t.Fatalf("GET /features returned %d", w.Code)
	}

	var features []Feature
	if err := json.Unmarshal(w.Body.Bytes(), &features); err != nil {
		t.Fatalf("response is not a feature list: %v", err)
	}
	if len(features) == 0 {
		t.Fatal("no features served, so this proves nothing")
	}

	missing := 0
	for _, f := range features {
		if f.Slug == nil || *f.Slug == "" {
			missing++
			if missing <= 3 {
				t.Errorf("feature %d (%s) has no slug, so its card cannot be linked",
					f.ID, f.Name)
			}
		}
	}
	if missing > 3 {
		t.Errorf("%d features in total have no slug", missing)
	}
}

// describePlace writes what a shared link previews with, so it has to cope
// with rt_hike_distance being free text from several sources. Appending
// "round trip" to everything produced "Approx 1 mile each way round trip",
// which contradicts itself.
func TestDescribePlaceOnlyCallsBareNumbersRoundTrip(t *testing.T) {
	str := func(s string) *string { return &s }
	ft := func(n int) *int { return &n }

	cases := []struct {
		name            string
		kind            string
		height          *int
		distance        *string
		owner, area     *string
		wantContains    []string
		wantNotContains []string
	}{
		{
			name: "a bare number is round trip",
			kind: "waterfall", height: ft(60), distance: str("1.9"), area: str("Brevard"),
			wantContains: []string{"A 60 ft waterfall in Brevard.", "1.9 miles round trip."},
		},
		{
			name: "each way is left as the source wrote it",
			kind: "waterfall", distance: str("Approx 1 mile each way"),
			wantContains:    []string{"Approx 1 mile each way."},
			wantNotContains: []string{"each way round trip"},
		},
		{
			name: "roadside is not a distance to annotate",
			kind: "waterfall", distance: str("Roadside"),
			wantContains:    []string{"Roadside."},
			wantNotContains: []string{"Roadside round trip", "Roadside miles"},
		},
		{
			name:            "nothing on file still reads as a sentence",
			kind:            "waterfall",
			wantContains:    []string{"A waterfall."},
			wantNotContains: []string{"undefined", "0 ft", "<nil>"},
		},
		{
			name:         "kind is named in plain English",
			kind:         "swimming_hole",
			wantContains: []string{"A swimming hole."},
		},
		{
			name: "owner stands in when no area is known",
			kind: "tower", owner: str("Federal"),
			wantContains: []string{"lookout tower on Federal land."},
		},
	}

	for _, c := range cases {
		got := describePlace(c.kind, c.height, c.distance, c.owner, c.area)
		for _, want := range c.wantContains {
			if !strings.Contains(got, want) {
				t.Errorf("%s: %q is missing %q", c.name, got, want)
			}
		}
		for _, bad := range c.wantNotContains {
			if strings.Contains(got, bad) {
				t.Errorf("%s: %q should not contain %q", c.name, got, bad)
			}
		}
	}
}
