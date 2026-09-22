package main

import (
	"encoding/json"
	"net/http/httptest"
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
