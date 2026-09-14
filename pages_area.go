package main

import (
	"database/sql"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

// An area page is a list, and a list of waterfalls is content in a way that a
// generated page about one waterfall is not: the grouping is the thing a
// person came for.
type areaPage struct {
	Name      string
	Slug      string
	Features  []*pageFeature
	Canonical string
	Title     string
	Descr     string
	Indexable bool
}

func areaHandler(w http.ResponseWriter, r *http.Request) {
	slug := mux.Vars(r)["slug"]
	var name string
	err := db.QueryRow(`SELECT name FROM areas WHERE slug = $1`, slug).Scan(&name)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("area page %s: %v", slug, err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}

	rows, err := db.Query(`SELECT `+featureColumns+featureJoins+`
		JOIN feature_areas ON feature_areas.feature_id = features.id
		JOIN areas ON areas.id = feature_areas.area_id
		WHERE areas.slug = $1 AND features.deprecated_reason IS NULL
		ORDER BY features.beauty_rating DESC NULLS LAST, features.name`, slug)
	if err != nil {
		log.Printf("area page %s: %v", slug, err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	page := areaPage{Name: name, Slug: slug,
		Canonical: "https://wanderfall.app/areas/" + slug}
	for rows.Next() {
		f, err := scanFeature(rows)
		if err != nil {
			log.Printf("area page %s: %v", slug, err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		page.Features = append(page.Features, f)
	}

	page.Title = "Waterfalls in " + name + " - Wanderfall"
	page.Descr = "Every waterfall we carry in " + name +
		", with hike distances, difficulty and where to park."
	// A list of one is the feature page again under another name.
	page.Indexable = len(page.Features) > 2
	render(w, "area.html", page)
}
