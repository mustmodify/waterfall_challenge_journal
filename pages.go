package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
)

// A page for each waterfall, tower and area, rendered on the server so it
// works with JavaScript off and can be read by a crawler. These sit beside the
// map rather than replacing it; /features stays JSON on that exact path.
type pageFeature struct {
	ID           int
	Slug         string
	Name         string
	Kind         string
	Areas        []areaRef
	Challenges   []string
	Aliases      []string
	Notes        []FeatureNote
	Links        []Link
	Latitude     *float64
	Longitude    *float64
	ParkingLat   *float64
	ParkingLon   *float64
	ViewLat      *float64
	ViewLon      *float64
	HeightFt     *int
	ElevationFt  *int
	HikeDistance *string
	Difficulty   *string
	Beauty       *int
	Photo        *int
	Solitude     *int
	Confidence   *string
	Sources      int
	SourcesApart *int
	Routes       []routeRating
	Deprecated   *string
}

type areaRef struct {
	Name string
	Slug string
}

type routeRating struct {
	Source   string
	Miles    float64
	GainFt   int
	Petzoldt float64
	Band     string
}

// Rendering these as words rather than numbers is deliberate: the 1-10 scores
// are hikingwnc's work, and they stay out of published pages until he says
// otherwise. See static/ratings.js, which bands them the same way.
var bands = map[string][]int{
	"beauty":   {5, 7, 9},
	"photo":    {6, 8, 10},
	"solitude": {6, 8, 10},
}

var bandWords = map[string][4]string{
	"beauty":   {"disappointing", "fine", "beautiful", "unforgettable"},
	"photo":    {"nope", "mediocre", "nice!", "stunning"},
	"solitude": {"crowded", "a few people", "had it to myself", "pristine"},
}

func band(axis string, score *int) string {
	if score == nil {
		return ""
	}
	cuts, words := bands[axis], bandWords[axis]
	switch {
	case *score >= cuts[2]:
		return words[3]
	case *score >= cuts[1]:
		return words[2]
	case *score >= cuts[0]:
		return words[1]
	}
	return words[0]
}

// Whether a page is worth putting in front of a search engine.
//
// Every page exists, is linked, and is useful to a person either way. This
// decides only what goes in the index, and the honest answer for most of this
// catalogue is "not yet": a page built from a name, a difficulty word and a
// distance is the same page 900 times over, and a large block of those can
// drag down the site hosting them.
//
// So a page needs something of its own. Either prose, or a fact particular to
// this waterfall -- another name it goes by, a route somebody walked, a
// viewpoint, a trailhead -- or enough beauty that people are already searching
// for it by name. A fall rated 9 or 10 by someone who has seen nine hundred of
// them has search demand whether or not our page is detailed.
//
// The bar lives here, alone, so moving it is one edit and one test. 155 of 955
// clear it today; the rest lift themselves as visits, ratings and corrections
// arrive.
func indexable(f *pageFeature) bool {
	if f.Deprecated != nil || f.Latitude == nil {
		return false
	}
	// "Waterfall #3 (04-14-2022)" is somebody's unsorted trip log. There is no
	// question it answers, because nobody can search for it.
	if strings.HasPrefix(f.Name, "Waterfall #") {
		return false
	}

	// Something particular to this one.
	if len(f.Notes) > 0 || len(f.Aliases) > 0 || len(f.Routes) > 0 {
		return true
	}
	if f.ViewLat != nil || f.ParkingLat != nil {
		return true
	}
	// Sources disagreeing about where a waterfall is, or three of them agreeing,
	// is a sentence no other page carries.
	if f.Confidence != nil && (*f.Confidence == "confirmed" || *f.Confidence == "disputed") {
		return true
	}
	// Searched for by name regardless of what we say about it.
	if f.Beauty != nil && *f.Beauty >= 9 {
		return true
	}
	return false
}

var pageTemplates *template.Template

func initPages() {
	funcs := template.FuncMap{
		"band": band,
		"coord": func(lat, lon *float64) string {
			if lat == nil || lon == nil {
				return ""
			}
			return fmt.Sprintf("%.5f, %.5f", *lat, *lon)
		},
		"kindPath": func(kind string) string {
			if kind == "tower" {
				return "towers"
			}
			return "waterfalls"
		},
		"join": strings.Join,
	}
	pageTemplates = template.Must(template.New("").Funcs(funcs).
		ParseGlob("templates/*.html"))
}

const featureColumns = `
	features.id, features.slug, features.name, features.kind,
	locations.latitude, locations.longitude,
	parking.latitude, parking.longitude,
	viewpoint.latitude, viewpoint.longitude,
	features.height_ft, features.elevation_ft, features.rt_hike_distance,
	features.accessibility, features.beauty_rating, features.photo_rating,
	features.solitude_rating, features.deprecated_reason,
	confidence.tier, confidence.sources, confidence.sources_apart_m`

const featureJoins = `
	FROM features
	LEFT JOIN locations            ON locations.id  = features.feature_location_id
	LEFT JOIN locations parking    ON parking.id    = features.parking_location_id
	LEFT JOIN locations viewpoint  ON viewpoint.id  = features.view_location_id
	LEFT JOIN coordinate_confidence confidence ON confidence.feature_id = features.id`

func scanFeature(row interface{ Scan(...any) error }) (*pageFeature, error) {
	var f pageFeature
	var apart *float64
	var sources *int
	err := row.Scan(&f.ID, &f.Slug, &f.Name, &f.Kind,
		&f.Latitude, &f.Longitude, &f.ParkingLat, &f.ParkingLon,
		&f.ViewLat, &f.ViewLon, &f.HeightFt, &f.ElevationFt, &f.HikeDistance,
		&f.Difficulty, &f.Beauty, &f.Photo, &f.Solitude, &f.Deprecated,
		&f.Confidence, &sources, &apart)
	if err != nil {
		return nil, err
	}
	if sources != nil {
		f.Sources = *sources
	}
	if apart != nil {
		m := int(*apart)
		f.SourcesApart = &m
	}
	return &f, nil
}

func loadFeatureExtras(f *pageFeature) error {
	rows, err := db.Query(`
		SELECT DISTINCT areas.name, areas.slug FROM feature_areas
		JOIN areas ON areas.id = feature_areas.area_id
		WHERE feature_areas.feature_id = $1 ORDER BY areas.name`, f.ID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var a areaRef
		if err := rows.Scan(&a.Name, &a.Slug); err != nil {
			rows.Close()
			return err
		}
		f.Areas = append(f.Areas, a)
	}
	rows.Close()

	rows, err = db.Query(`
		SELECT challenges.name FROM goals
		JOIN challenges ON challenges.id = goals.challenge_id
		WHERE goals.feature_id = $1 ORDER BY challenges.name`, f.ID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			return err
		}
		f.Challenges = append(f.Challenges, name)
	}
	rows.Close()

	rows, err = db.Query(`
		SELECT DISTINCT value#>>'{}' FROM claims
		WHERE feature_id = $1 AND field = 'alias' ORDER BY 1`, f.ID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var alias string
		if err := rows.Scan(&alias); err != nil {
			rows.Close()
			return err
		}
		f.Aliases = append(f.Aliases, alias)
	}
	rows.Close()

	rows, err = db.Query(`
		SELECT text, coalesce(source, '') FROM notes
		WHERE feature_id = $1 ORDER BY id`, f.ID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var n FeatureNote
		if err := rows.Scan(&n.Text, &n.Source); err != nil {
			rows.Close()
			return err
		}
		f.Notes = append(f.Notes, n)
	}
	rows.Close()

	rows, err = db.Query(`
		SELECT coalesce(rel, ''), url FROM links
		WHERE feature_id = $1 ORDER BY id`, f.ID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var l Link
		if err := rows.Scan(&l.Rel, &l.URL); err != nil {
			rows.Close()
			return err
		}
		f.Links = append(f.Links, l)
	}
	rows.Close()

	rows, err = db.Query(`
		SELECT source, miles, gain_ft, petzoldt, band FROM route_ratings
		WHERE feature_id = $1 ORDER BY petzoldt`, f.ID)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var r routeRating
		if err := rows.Scan(&r.Source, &r.Miles, &r.GainFt, &r.Petzoldt, &r.Band); err != nil {
			return err
		}
		f.Routes = append(f.Routes, r)
	}
	return nil
}

type featurePage struct {
	Feature   *pageFeature
	Indexable bool
	Canonical string
	Title     string
	Descr     string
}

func featureHandler(kind string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		slug := mux.Vars(r)["slug"]
		row := db.QueryRow(`SELECT `+featureColumns+featureJoins+
			` WHERE features.slug = $1 AND features.kind = $2`, slug, kind)
		f, err := scanFeature(row)
		if err == sql.ErrNoRows {
			http.NotFound(w, r)
			return
		}
		if err != nil {
			log.Printf("feature page %s: %v", slug, err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		if err := loadFeatureExtras(f); err != nil {
			log.Printf("feature page %s: %v", slug, err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}

		page := featurePage{
			Feature:   f,
			Indexable: indexable(f),
			Canonical: "https://wanderfall.app/" + kindPlural(kind) + "/" + f.Slug,
			Title:     f.Name + " - " + describeKind(f) + " - Wanderfall",
			Descr:     metaDescription(f),
		}
		render(w, "feature.html", page)
	}
}

func kindPlural(kind string) string {
	if kind == "tower" {
		return "towers"
	}
	return "waterfalls"
}

func describeKind(f *pageFeature) string {
	if f.Kind == "tower" {
		return "lookout tower"
	}
	if len(f.Areas) > 0 {
		return "waterfall near " + f.Areas[0].Name
	}
	return "waterfall in Western North Carolina"
}

func metaDescription(f *pageFeature) string {
	var parts []string
	parts = append(parts, f.Name)
	if f.HeightFt != nil {
		parts = append(parts, fmt.Sprintf("%d feet", *f.HeightFt))
	}
	if d := f.HikeDistance; d != nil && *d != "" {
		if strings.EqualFold(*d, "roadside") {
			parts = append(parts, "roadside")
		} else {
			parts = append(parts, *d+" round trip")
		}
	}
	if f.Difficulty != nil {
		parts = append(parts, strings.ToLower(*f.Difficulty))
	}
	if len(f.Areas) > 0 {
		parts = append(parts, "in "+f.Areas[0].Name)
	}
	return strings.Join(parts, ", ") + "."
}

func render(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := pageTemplates.ExecuteTemplate(w, name, data); err != nil {
		log.Printf("render %s: %v", name, err)
	}
}
