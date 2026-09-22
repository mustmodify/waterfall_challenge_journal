package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
)

// patchableFeatureFields are the columns the admin edit form may touch.
// Deliberately a small, named set rather than "whatever keys arrive" --
// the request body decides which of these to change, not which columns
// exist on the table.
var patchableFeatureFields = map[string]bool{
	"name": true, "owner": true, "deprecated_reason": true, "deprecated_note": true,
}

// patchFeature is a real partial update, unlike updateFeature's PUT (which
// replaces name/parking/feature location together and would null out
// whatever the caller left out). The admin edit form only ever means to
// change a couple of fields at a time, so this only touches the keys
// actually present in the request body.
func patchFeature(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id := mux.Vars(r)["id"]

	var body map[string]*string
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if len(body) == 0 {
		http.Error(w, "Nothing to update", http.StatusBadRequest)
		return
	}

	sets := make([]string, 0, len(body))
	args := make([]interface{}, 0, len(body)+1)
	i := 1
	for field, value := range body {
		if !patchableFeatureFields[field] {
			http.Error(w, "Unknown field: "+field, http.StatusBadRequest)
			return
		}
		sets = append(sets, fmt.Sprintf("%s=$%d", field, i))
		args = append(args, value)
		i++
	}
	args = append(args, id)

	sqlStatement := "UPDATE features SET " + joinComma(sets) + fmt.Sprintf(" WHERE id=$%d", i)
	if _, err := db.Exec(sqlStatement, args...); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func joinComma(parts []string) string {
	out := ""
	for i, p := range parts {
		if i > 0 {
			out += ", "
		}
		out += p
	}
	return out
}

// adminFeature is the admin table's row: every feature, not just the
// published ones getFeatures serves, with the confidence tier that decides
// whether it is published at all.
type adminFeature struct {
	ID               int     `json:"id"`
	Name             string  `json:"name"`
	Kind             string  `json:"kind"`
	Slug             string  `json:"slug"`
	Tier             *string `json:"tier,omitempty"`
	Owner            *string `json:"owner,omitempty"`
	DeprecatedReason *string `json:"deprecated_reason,omitempty"`
	DeprecatedNote   *string `json:"deprecated_note,omitempty"`
	ClaimCount       int     `json:"claim_count"`
}

// listFeaturesAdmin is /admin's feature table: every feature regardless of
// publication tier, with a claim count so "0 claims" is visible as its own
// signal rather than looking the same as a feature nobody has looked at yet.
func listFeaturesAdmin(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := db.Query(`
		SELECT f.id, f.name, f.kind, f.slug, confidence.tier,
		       f.owner, f.deprecated_reason, f.deprecated_note,
		       COALESCE(cc.n, 0)
		FROM features f
		LEFT JOIN coordinate_confidence confidence ON confidence.feature_id = f.id
		LEFT JOIN (
			SELECT feature_id, count(*) AS n FROM claims GROUP BY feature_id
		) cc ON cc.feature_id = f.id
		ORDER BY f.name
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []adminFeature{}
	for rows.Next() {
		var f adminFeature
		if err := rows.Scan(&f.ID, &f.Name, &f.Kind, &f.Slug, &f.Tier,
			&f.Owner, &f.DeprecatedReason, &f.DeprecatedNote, &f.ClaimCount); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		out = append(out, f)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}

type claimGroupRow struct {
	ID              int        `json:"id"`
	Source          string     `json:"source"`
	URL             *string    `json:"url,omitempty"`
	IdentityCertain bool       `json:"identity_certain"`
	Note            *string    `json:"note,omitempty"`
	Claims          []claimRow `json:"claims"`
}

type claimRow struct {
	ID       int             `json:"id"`
	Field    string          `json:"field"`
	Value    json.RawMessage `json:"value"`
	Accepted bool            `json:"accepted"`
	Note     *string         `json:"note,omitempty"`
}

// listClaims is the "links to claims" destination: every claim_group and
// claim for one feature, grouped the way the schema groups them -- one
// source's reading of the place, holding one row per field it asserted.
func listClaims(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	featureID := r.URL.Query().Get("feature")
	if featureID == "" {
		http.Error(w, "feature is required", http.StatusBadRequest)
		return
	}

	groups := map[int]*claimGroupRow{}
	var order []int

	groupRows, err := db.Query(`
		SELECT id, source, url, identity_certain, note
		FROM claim_groups WHERE feature_id = $1 ORDER BY id
	`, featureID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for groupRows.Next() {
		var g claimGroupRow
		var url, note sql.NullString
		if err := groupRows.Scan(&g.ID, &g.Source, &url, &g.IdentityCertain, &note); err != nil {
			groupRows.Close()
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if url.Valid {
			g.URL = &url.String
		}
		if note.Valid {
			g.Note = &note.String
		}
		g.Claims = []claimRow{}
		groups[g.ID] = &g
		order = append(order, g.ID)
	}
	groupRows.Close()

	claimRows, err := db.Query(`
		SELECT group_id, id, field, value, accepted, note
		FROM claims WHERE feature_id = $1 ORDER BY field, id
	`, featureID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer claimRows.Close()
	for claimRows.Next() {
		var groupID int
		var c claimRow
		var note sql.NullString
		if err := claimRows.Scan(&groupID, &c.ID, &c.Field, &c.Value, &c.Accepted, &note); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if note.Valid {
			c.Note = &note.String
		}
		if g, ok := groups[groupID]; ok {
			g.Claims = append(g.Claims, c)
		}
	}

	out := make([]*claimGroupRow, 0, len(order))
	for _, id := range order {
		out = append(out, groups[id])
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}

type unresolvedClaim struct {
	FeatureID      int    `json:"feature_id"`
	FeatureName    string `json:"name"`
	Field          string `json:"field"`
	DistinctValues int    `json:"distinct_values"`
	Accepted       int    `json:"accepted"`
	Sources        string `json:"sources"`
}

// listUnresolvedClaims reads claim_conflicts: every (feature, field) with
// either disagreeing values or nothing accepted yet. This is Stage 3 of
// MATCHING.md's pipeline made visible -- what survives automated matching
// and is waiting on a person.
func listUnresolvedClaims(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := db.Query(`
		SELECT feature_id, name, field, distinct_values, accepted, sources
		FROM claim_conflicts
		ORDER BY accepted, distinct_values DESC, name
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []unresolvedClaim{}
	for rows.Next() {
		var u unresolvedClaim
		if err := rows.Scan(&u.FeatureID, &u.FeatureName, &u.Field,
			&u.DistinctValues, &u.Accepted, &u.Sources); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		out = append(out, u)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}

// reviewItem is one fact that wants a human's attention, with the competing
// readings inline. Showing "1 of 2 sources agree" without showing what the
// two sources actually say makes a page you have to click out of to use.
type reviewItem struct {
	FeatureID int             `json:"feature_id"`
	Name      string          `json:"name"`
	Key       string          `json:"key"`
	Value     *string         `json:"value,omitempty"`
	Stage     string          `json:"confidence_stage"`
	Score     *float64        `json:"confidence_score,omitempty"`
	Notes     *string         `json:"notes,omitempty"`
	Readings  []reviewReading `json:"readings"`
}

type reviewReading struct {
	Source string  `json:"source"`
	Value  string  `json:"value"`
	URL    *string `json:"url,omitempty"`
}

// The review queue: facts whose confidence says a person should look. Ordered
// by score, so active conflicts come before merely unconfirmed ones -- a
// disputed coordinate is a wrong pin on the map, a single-source one is only
// an unchecked pin.
func listReviewQueue(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	stage := r.URL.Query().Get("stage")
	if stage == "" {
		stage = "disputed"
	}

	rows, err := db.Query(`
		SELECT f.id, f.name, fa.key, fa.value, fa.confidence_stage,
		       fa.confidence_score, fa.notes
		FROM facts fa
		JOIN features f ON f.id = fa.feature_id
		WHERE fa.confidence_stage = $1
		ORDER BY fa.confidence_score, f.name
	`, stage)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	items := []reviewItem{}
	for rows.Next() {
		var it reviewItem
		if err := rows.Scan(&it.FeatureID, &it.Name, &it.Key, &it.Value,
			&it.Stage, &it.Score, &it.Notes); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		it.Readings = []reviewReading{}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// The competing readings, one query for the whole page rather than one
	// per row. coordinate is stored as jsonb and everything else as a scalar,
	// so the value is rendered here rather than in the browser.
	for i := range items {
		cr, err := db.Query(`
			SELECT cg.source,
			       CASE WHEN c.value ? 'lat'
			            THEN (c.value->>'lat') || ', ' || (c.value->>'lon')
			            ELSE c.value #>> '{}' END,
			       cg.url
			FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
			WHERE c.feature_id = $1 AND c.field = $2 AND cg.identity_certain
			ORDER BY cg.source
		`, items[i].FeatureID, items[i].Key)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		for cr.Next() {
			var rd reviewReading
			if err := cr.Scan(&rd.Source, &rd.Value, &rd.URL); err != nil {
				cr.Close()
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			items[i].Readings = append(items[i].Readings, rd)
		}
		cr.Close()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(items)
}

type confusionSet struct {
	ID      int               `json:"id"`
	Name    string            `json:"name"`
	Members []confusionMember `json:"members"`
	Entries []confusionEntry  `json:"entries"`
}

type confusionMember struct {
	FeatureID int    `json:"feature_id"`
	Name      string `json:"name"`
	Kind      string `json:"kind"`
}

type confusionEntry struct {
	ID        int    `json:"id"`
	Body      string `json:"body"`
	Author    string `json:"author"`
	CreatedAt string `json:"created_at"`
}

// One set with its members and its journal, newest entry first so the current
// conclusion is on top and the history reads below it.
func getConfusionSet(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	id := mux.Vars(r)["id"]

	var set confusionSet
	err := db.QueryRow(`SELECT id, name FROM confusion_sets WHERE id = $1`, id).
		Scan(&set.ID, &set.Name)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	set.Members = []confusionMember{}
	mrows, err := db.Query(`
		SELECT f.id, f.name, f.kind FROM confusion_set_members m
		JOIN features f ON f.id = m.feature_id
		WHERE m.confusion_set_id = $1 ORDER BY f.name
	`, set.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	for mrows.Next() {
		var m confusionMember
		if err := mrows.Scan(&m.FeatureID, &m.Name, &m.Kind); err != nil {
			mrows.Close()
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		set.Members = append(set.Members, m)
	}
	mrows.Close()

	set.Entries = []confusionEntry{}
	erows, err := db.Query(`
		SELECT id, body, author, created_at::text FROM confusion_set_entries
		WHERE confusion_set_id = $1 ORDER BY created_at DESC, id DESC
	`, set.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer erows.Close()
	for erows.Next() {
		var e confusionEntry
		if err := erows.Scan(&e.ID, &e.Body, &e.Author, &e.CreatedAt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		set.Entries = append(set.Entries, e)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(set)
}

func listConfusionSets(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	rows, err := db.Query(`
		SELECT cs.id, cs.name,
		       (SELECT count(*) FROM confusion_set_members m WHERE m.confusion_set_id = cs.id),
		       (SELECT count(*) FROM confusion_set_entries e WHERE e.confusion_set_id = cs.id)
		FROM confusion_sets cs ORDER BY cs.name
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type row struct {
		ID      int    `json:"id"`
		Name    string `json:"name"`
		Members int    `json:"members"`
		Entries int    `json:"entries"`
	}
	out := []row{}
	for rows.Next() {
		var x row
		if err := rows.Scan(&x.ID, &x.Name, &x.Members, &x.Entries); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		out = append(out, x)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}

// Appending is the only write. There is no edit and no delete: a changed
// conclusion is a new entry, and the database enforces that rather than
// trusting this handler to.
func addConfusionEntry(w http.ResponseWriter, r *http.Request) {
	user := currentUser(r)
	if !requireAdmin(w, r) {
		return
	}
	var req struct {
		Body   string `json:"body"`
		Author string `json:"author"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(req.Body) == "" {
		http.Error(w, "An entry needs something in it", http.StatusBadRequest)
		return
	}
	// Default to whoever is signed in rather than letting the browser claim an
	// author. Signing an entry as jw is only honest when the words are his.
	author := req.Author
	if strings.TrimSpace(author) == "" && user != nil {
		author = user.Name
	}

	var id int
	err := db.QueryRow(`
		INSERT INTO confusion_set_entries (confusion_set_id, body, author)
		VALUES ($1, $2, $3) RETURNING id
	`, mux.Vars(r)["id"], strings.TrimSpace(req.Body), author).Scan(&id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]any{"id": id})
}
