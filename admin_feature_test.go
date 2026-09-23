package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/gorilla/mux"
)

// showFeatureFacts reads mux.Vars, so the route has to be exercised through a
// router. Calling the handler with a bare request would pass an empty id and
// the test would prove nothing -- which is the failure mode that let the
// shareable-URL bug ship.
func getFeatureFacts(t *testing.T, id string, r *http.Request) *httptest.ResponseRecorder {
	t.Helper()
	router := mux.NewRouter()
	router.HandleFunc("/admin/feature/{id:[0-9]+}/facts", showFeatureFacts).Methods("GET")
	req := httptest.NewRequest("GET", "/admin/feature/"+id+"/facts", nil)
	for _, c := range r.Cookies() {
		req.AddCookie(c)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

func TestFeatureFactsIsAdminOnly(t *testing.T) {
	db = borrowDB(t)

	t.Run("signed out", func(t *testing.T) {
		if w := getFeatureFacts(t, "1", httptest.NewRequest("GET", "/", nil)); w.Code != http.StatusUnauthorized {
			t.Fatalf("want 401 for a signed-out visitor, got %d", w.Code)
		}
	})

	t.Run("signed in, not admin", func(t *testing.T) {
		r := signedInAs(t, "facts-nonadmin@example.com", false)
		if w := getFeatureFacts(t, "1", r); w.Code != http.StatusForbidden {
			t.Fatalf("want 403 for a non-admin, got %d", w.Code)
		}
	})
}

// The page's whole point is that a field's readings arrive together with the
// grade for that field. Two things can break that without breaking the
// request: the group-by can split one field across several sections, or the
// left join to facts can drop the grade. Both are checked here.
func TestFeatureFactsGroupsClaimsByField(t *testing.T) {
	db = borrowDB(t)

	var id int
	err := db.QueryRow(`
		SELECT f.feature_id FROM facts f
		JOIN claims c ON c.feature_id = f.feature_id AND c.field = f.key
		GROUP BY f.feature_id
		HAVING count(DISTINCT f.key) >= 2
		LIMIT 1`).Scan(&id)
	if err != nil {
		t.Skip("no feature with two graded fields in this database")
	}

	r := signedInAs(t, "facts-admin@example.com", true)
	w := getFeatureFacts(t, strconv.Itoa(id), r)
	if w.Code != http.StatusOK {
		t.Fatalf("want 200, got %d: %s", w.Code, w.Body.String())
	}

	var got featureShow
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.ID != id {
		t.Fatalf("want feature %d, got %d", id, got.ID)
	}

	seen := map[string]bool{}
	graded := 0
	lastScore := -1.0
	for _, s := range got.Sections {
		if seen[s.Field] {
			t.Errorf("field %q appears in more than one section", s.Field)
		}
		seen[s.Field] = true

		if len(s.Claims) == 0 {
			t.Errorf("field %q has a section but no readings", s.Field)
		}
		for _, c := range s.Claims {
			if len(c.Value) == 0 {
				t.Errorf("field %q has a reading with no value", s.Field)
			}
		}

		if s.Score != nil {
			graded++
			if *s.Score < lastScore {
				t.Errorf("sections are out of order: %v after %v", *s.Score, lastScore)
			}
			lastScore = *s.Score
			if s.Stage == nil {
				t.Errorf("field %q has a score but no stage to explain it", s.Field)
			}
		}
	}
	if graded < 2 {
		t.Fatalf("want at least two graded sections, got %d", graded)
	}
}

func TestFeatureFactsMissingFeature(t *testing.T) {
	db = borrowDB(t)

	r := signedInAs(t, "facts-admin@example.com", true)
	if w := getFeatureFacts(t, "999999999", r); w.Code != http.StatusNotFound {
		t.Fatalf("want 404 for a feature that does not exist, got %d", w.Code)
	}
}

// borrowDB is testDB without the footgun.
//
// The package's init() already connects the global db, and several tests
// replace it with their own connection and then close it on the way out --
// which leaves every later test holding a closed handle. That is why the
// suite goes red as soon as TEST_DATABASE_URL is set: the failure lands on
// whichever test happens to run next, not on the one that caused it.
//
// So put the original back afterwards.
func borrowDB(t *testing.T) *sql.DB {
	t.Helper()
	conn := testDB(t)
	prev := db
	t.Cleanup(func() {
		db = prev
		conn.Close()
	})
	return conn
}
