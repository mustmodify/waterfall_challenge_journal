package main

import (
	"encoding/json"
	"net/http"
	"strings"
)

// correctionFields are the things a person can tell us are wrong. Constrained
// so the queue can be grouped and worked through, with "other" as the escape
// hatch rather than a free-text field nobody can sort.
var correctionFields = map[string]bool{
	"location": true, "name": true, "access": true,
	"rating": true, "gone": true, "missing": true, "other": true,
}

const maxCorrectionLen = 2000

func createCorrection(w http.ResponseWriter, r *http.Request) {
	var req struct {
		FeatureID      *int   `json:"feature_id"`
		Subject        string `json:"subject"`
		Field          string `json:"field"`
		SuggestedValue string `json:"suggested_value"`
		Comment        string `json:"comment"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}

	req.Comment = strings.TrimSpace(req.Comment)
	req.Subject = strings.TrimSpace(req.Subject)
	req.SuggestedValue = strings.TrimSpace(req.SuggestedValue)

	if req.Comment == "" {
		http.Error(w, "Tell me what is wrong", http.StatusBadRequest)
		return
	}
	if len(req.Comment) > maxCorrectionLen || len(req.SuggestedValue) > maxCorrectionLen {
		http.Error(w, "That is longer than I can store", http.StatusBadRequest)
		return
	}
	if !correctionFields[req.Field] {
		req.Field = "other"
	}
	// The table wants one or the other; a report about nothing is not useful.
	if req.FeatureID == nil && req.Subject == "" {
		http.Error(w, "Say which place this is about", http.StatusBadRequest)
		return
	}

	// Signed in is not required. The people most likely to notice a wrong
	// coordinate are the ones standing at the waterfall, and making them make
	// an account first loses the report.
	var userID *int
	if u := currentUser(r); u != nil {
		userID = &u.ID
	}

	var id int
	err := db.QueryRow(`
		INSERT INTO corrections (user_id, feature_id, subject, field, suggested_value, comment)
		VALUES ($1, $2, NULLIF($3, ''), $4, NULLIF($5, ''), $6)
		RETURNING id
	`, userID, req.FeatureID, req.Subject, req.Field, req.SuggestedValue, req.Comment).Scan(&id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]any{"id": id})
}
