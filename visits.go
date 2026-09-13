package main

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/lib/pq"
)

type Visit struct {
	ID          int    `json:"id"`
	FeatureID   int    `json:"feature_id"`
	FeatureName string `json:"feature_name,omitempty"`
	VisitedOn   string `json:"visited_on"`
	// The visitor's own scores for this trip, distinct from the HikingWNC
	// numbers on features. Pointers so "not rated" survives the round trip as
	// null instead of collapsing into a zero.
	Beauty   *int `json:"beauty_rating"`
	Photo    *int `json:"photo_rating"`
	Solitude *int `json:"solitude_rating"`
}

// validRating accepts an absent rating, or one on the 4-point visit scale.
// Not the same as the 1-10 on features: those are HikingWNC's numbers for the
// fall itself, these are one person's impression of one trip. The DB enforces
// it too; checking here turns a 500 into a 400 with a message worth reading.
func validRating(v *int) bool {
	return v == nil || (*v >= 1 && *v <= 4)
}

// uniqueViolation reports whether err is a duplicate-key error. Matching on the
// pq code rather than the constraint name means renaming an index doesn't
// silently turn a 409 into a 500.
func uniqueViolation(err error) bool {
	e, ok := err.(*pq.Error)
	return ok && e.Code == "23505"
}

func createVisit(w http.ResponseWriter, r *http.Request) {
	user := currentUser(r)
	if user == nil {
		http.Error(w, "Login required", http.StatusUnauthorized)
		return
	}

	var req struct {
		FeatureID int    `json:"feature_id"`
		VisitedOn string `json:"visited_on"`
		Beauty    *int   `json:"beauty_rating"`
		Photo     *int   `json:"photo_rating"`
		Solitude  *int   `json:"solitude_rating"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if req.FeatureID == 0 || req.VisitedOn == "" {
		http.Error(w, "Missing feature_id or visited_on", http.StatusBadRequest)
		return
	}
	if !validRating(req.Beauty) || !validRating(req.Photo) || !validRating(req.Solitude) {
		http.Error(w, "Ratings must be between 1 and 4", http.StatusBadRequest)
		return
	}

	v := Visit{
		FeatureID: req.FeatureID,
		VisitedOn: req.VisitedOn,
		Beauty:    req.Beauty,
		Photo:     req.Photo,
		Solitude:  req.Solitude,
	}
	err := db.QueryRow(`
		INSERT INTO visits (user_id, feature_id, visited_on,
		                    beauty_rating, photo_rating, solitude_rating)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, user.ID, req.FeatureID, req.VisitedOn,
		req.Beauty, req.Photo, req.Solitude).Scan(&v.ID)
	if err != nil {
		if uniqueViolation(err) {
			http.Error(w, "Already recorded for that date", http.StatusConflict)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(v)
}

// createVisits takes a batch, because the bulk page submits a whole page of
// rows at once. Each row succeeds or fails on its own -- one duplicate date in
// row 9 must not discard the eight good rows above it -- so the response is
// per-row rather than a single status.
func createVisits(w http.ResponseWriter, r *http.Request) {
	user := currentUser(r)
	if user == nil {
		http.Error(w, "Login required", http.StatusUnauthorized)
		return
	}

	var req struct {
		Visits []struct {
			FeatureID int    `json:"feature_id"`
			VisitedOn string `json:"visited_on"`
			Beauty    *int   `json:"beauty_rating"`
			Photo     *int   `json:"photo_rating"`
			Solitude  *int   `json:"solitude_rating"`
		} `json:"visits"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if len(req.Visits) == 0 {
		http.Error(w, "No visits supplied", http.StatusBadRequest)
		return
	}
	if len(req.Visits) > 200 {
		http.Error(w, "Too many visits in one request", http.StatusBadRequest)
		return
	}

	type result struct {
		Index int    `json:"index"`
		OK    bool   `json:"ok"`
		ID    int    `json:"id,omitempty"`
		Error string `json:"error,omitempty"`
	}
	results := make([]result, 0, len(req.Visits))
	saved := 0

	for i, v := range req.Visits {
		switch {
		case v.FeatureID == 0 || v.VisitedOn == "":
			results = append(results, result{i, false, 0, "Missing place or date"})
			continue
		case !validRating(v.Beauty) || !validRating(v.Photo) || !validRating(v.Solitude):
			results = append(results, result{i, false, 0, "Ratings must be between 1 and 4"})
			continue
		}
		var id int
		err := db.QueryRow(`
			INSERT INTO visits (user_id, feature_id, visited_on,
			                    beauty_rating, photo_rating, solitude_rating)
			VALUES ($1, $2, $3, $4, $5, $6)
			RETURNING id
		`, user.ID, v.FeatureID, v.VisitedOn, v.Beauty, v.Photo, v.Solitude).Scan(&id)
		switch {
		case err == nil:
			results = append(results, result{i, true, id, ""})
			saved++
		case uniqueViolation(err):
			results = append(results, result{i, false, 0, "Already recorded for that date"})
		default:
			results = append(results, result{i, false, 0, err.Error()})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	if saved == 0 {
		w.WriteHeader(http.StatusConflict)
	} else {
		w.WriteHeader(http.StatusCreated)
	}
	json.NewEncoder(w).Encode(map[string]any{"saved": saved, "results": results})
}

func getVisits(w http.ResponseWriter, r *http.Request) {
	user := currentUser(r)
	if user == nil {
		http.Error(w, "Login required", http.StatusUnauthorized)
		return
	}

	rows, err := db.Query(`
		SELECT visits.id, visits.feature_id, features.name, visits.visited_on::text,
		       visits.beauty_rating, visits.photo_rating, visits.solitude_rating
		FROM visits JOIN features ON features.id = visits.feature_id
		WHERE user_id = $1
		ORDER BY visited_on DESC
	`, user.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	visits := []Visit{}
	for rows.Next() {
		var v Visit
		if err := rows.Scan(&v.ID, &v.FeatureID, &v.FeatureName, &v.VisitedOn,
			&v.Beauty, &v.Photo, &v.Solitude); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		visits = append(visits, v)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(visits)
}

func deleteVisit(w http.ResponseWriter, r *http.Request) {
	user := currentUser(r)
	if user == nil {
		http.Error(w, "Login required", http.StatusUnauthorized)
		return
	}
	id := mux.Vars(r)["id"]

	result, err := db.Exec(`DELETE FROM visits WHERE id = $1 AND user_id = $2`, id, user.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Challenge describes a list and how much of it you have to do. Goals is the
// number of places on the list; Target is how many of them completion needs,
// which for the WC100 is fewer than the list length.
type Challenge struct {
	Name   string `json:"name"`
	Goals  int    `json:"goals"`
	Target int    `json:"target"`
}

func getChallenges(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`
		SELECT c.name, count(g.id) AS goals, COALESCE(c.target, count(g.id)) AS target
		FROM challenges c
		LEFT JOIN goals g ON g.challenge_id = c.id
		GROUP BY c.id, c.name, c.target
		ORDER BY c.name
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []Challenge{}
	for rows.Next() {
		var c Challenge
		if err := rows.Scan(&c.Name, &c.Goals, &c.Target); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(out)
}
