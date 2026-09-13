package main

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
)

// Correction is one report, as the queue shows it.
type Correction struct {
	ID             int     `json:"id"`
	FeatureID      *int    `json:"feature_id,omitempty"`
	FeatureName    *string `json:"feature_name,omitempty"`
	Subject        *string `json:"subject,omitempty"`
	Field          string  `json:"field"`
	SuggestedValue *string `json:"suggested_value,omitempty"`
	Comment        string  `json:"comment"`
	Status         string  `json:"status"`
	ReportedBy     *string `json:"reported_by,omitempty"`
	CreatedAt      string  `json:"created_at"`
}

// requireAdmin gates the queue. Reports are other people's words about places
// they have been, and the queue holds them until someone acts; neither is
// public reading.
func requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	u := currentUser(r)
	if u == nil {
		http.Error(w, "Login required", http.StatusUnauthorized)
		return false
	}
	if !u.IsAdmin {
		http.Error(w, "Not allowed", http.StatusForbidden)
		return false
	}
	return true
}

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

	// Tell someone. Fire and forget: the report is already saved, and losing
	// it because a mail server was unreachable would be the worse failure.
	place := "somewhere unnamed"
	if req.FeatureID != nil {
		var name string
		if err := db.QueryRow(`SELECT name FROM features WHERE id = $1`, *req.FeatureID).Scan(&name); err == nil {
			place = name
		}
	} else if req.Subject != "" {
		place = req.Subject
	}
	who := "an anonymous visitor"
	if u := currentUser(r); u != nil {
		who = u.Name + " <" + u.Email + ">"
	}
	subject, body := correctionEmail(place, req.Field, req.SuggestedValue, req.Comment, who, req.FeatureID)
	sendAsync(notifyAddress, subject, body)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]any{"id": id})
}

func listCorrections(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	status := r.URL.Query().Get("status")
	rows, err := db.Query(`
		SELECT c.id, c.feature_id, f.name, c.subject, c.field, c.suggested_value,
		       c.comment, c.status, u.email, c.created_at::text
		FROM corrections c
		LEFT JOIN features f ON f.id = c.feature_id
		LEFT JOIN users u ON u.id = c.user_id
		WHERE ($1 = '' OR c.status = $1)
		ORDER BY c.status = 'open' DESC, c.created_at DESC
	`, status)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	out := []Correction{}
	for rows.Next() {
		var c Correction
		if err := rows.Scan(&c.ID, &c.FeatureID, &c.FeatureName, &c.Subject, &c.Field,
			&c.SuggestedValue, &c.Comment, &c.Status, &c.ReportedBy, &c.CreatedAt); err != nil {
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

var correctionStatuses = map[string]bool{
	"open": true, "accepted": true, "rejected": true, "duplicate": true,
}

func updateCorrection(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var req struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if !correctionStatuses[req.Status] {
		http.Error(w, "Unknown status", http.StatusBadRequest)
		return
	}
	u := currentUser(r)
	// resolved_by and resolved_at are cleared when something goes back to
	// open, so they never describe a decision that has been undone.
	var resolvedBy any = u.ID
	resolvedAt := "now()"
	if req.Status == "open" {
		resolvedBy = nil
		resolvedAt = "NULL"
	}
	res, err := db.Exec(`
		UPDATE corrections SET status = $1, resolved_by = $2, resolved_at = `+resolvedAt+`
		WHERE id = $3
	`, req.Status, resolvedBy, mux.Vars(r)["id"])
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func deleteCorrection(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	res, err := db.Exec(`DELETE FROM corrections WHERE id = $1`, mux.Vars(r)["id"])
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		http.Error(w, "Not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
