package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// Server-rendered area pages, readable with JavaScript off.
//
// A list of waterfalls is content in a way that a generated page about one
// waterfall is not. Eight features out of 956 have any prose, so a page per
// fall would be a name, a difficulty word and a distance, 934 times over --
// and a block of near-identical pages can drag down the site hosting them.
// The grouping is the part worth publishing.
//
// Names link to the map rather than to pages of their own.
type areaFeature struct {
	Slug         string
	Name         string
	Kind         string
	HikeDistance *string
	Difficulty   *string
	HeightFt     *int
}

type areaPage struct {
	Name      string
	Slug      string
	Features  []areaFeature
	Canonical string
	Title     string
	Descr     string
}

type areaListing struct {
	Name  string
	Slug  string
	Count int
}

type areaIndex struct {
	Areas     []areaListing
	Total     int
	Canonical string
	Title     string
	Descr     string
}

var pageTemplates *template.Template

func initPages() {
	pageTemplates = template.Must(template.New("").Funcs(template.FuncMap{
		"kindPath": func(kind string) string {
			if kind == "tower" {
				return "tower"
			}
			return "waterfall"
		},
	}).ParseGlob("templates/*.html"))
}

func itoa(n int) string { return fmt.Sprintf("%d", n) }

func plural(n int, word string) string {
	if n == 1 {
		return "1 " + word
	}
	return itoa(n) + " " + word + "s"
}

func render(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := pageTemplates.ExecuteTemplate(w, name, data); err != nil {
		log.Printf("render %s: %v", name, err)
	}
}

// Areas with one or two entries are listed on the index but do not get a page:
// a page for a single waterfall is the thing we decided not to build.
const areaMinimum = 3

func areasWithCounts() ([]areaListing, error) {
	rows, err := db.Query(`
		SELECT areas.name, areas.slug, count(*)
		FROM areas
		JOIN feature_areas ON feature_areas.area_id = areas.id
		JOIN features ON features.id = feature_areas.feature_id
		WHERE features.deprecated_reason IS NULL
		GROUP BY areas.name, areas.slug
		ORDER BY count(*) DESC, areas.name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []areaListing
	for rows.Next() {
		var a areaListing
		if err := rows.Scan(&a.Name, &a.Slug, &a.Count); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}

func areaIndexHandler(w http.ResponseWriter, r *http.Request) {
	areas, err := areasWithCounts()
	if err != nil {
		log.Printf("area index: %v", err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	page := areaIndex{
		Areas:     areas,
		Canonical: "https://wanderfall.app/areas",
		Title:     "Waterfalls of Western North Carolina, by area - Wanderfall",
		Descr: "Every area we carry waterfalls in, from Brevard and DuPont to " +
			"Highlands, Cashiers and the Smokies, with how many falls are in each.",
	}
	for _, a := range areas {
		page.Total += a.Count
	}
	render(w, "areas.html", page)
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

	rows, err := db.Query(`
		SELECT features.slug, features.name, features.kind,
		       features.rt_hike_distance, features.accessibility, features.height_ft
		FROM features
		JOIN feature_areas ON feature_areas.feature_id = features.id
		JOIN areas ON areas.id = feature_areas.area_id
		WHERE areas.slug = $1 AND features.deprecated_reason IS NULL
		ORDER BY features.name`, slug)
	if err != nil {
		log.Printf("area page %s: %v", slug, err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	page := areaPage{Name: name, Slug: slug,
		Canonical: "https://wanderfall.app/areas/" + slug}
	for rows.Next() {
		var f areaFeature
		if err := rows.Scan(&f.Slug, &f.Name, &f.Kind, &f.HikeDistance,
			&f.Difficulty, &f.HeightFt); err != nil {
			log.Printf("area page %s: %v", slug, err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		page.Features = append(page.Features, f)
	}

	page.Title = "Waterfalls in " + name + " - Wanderfall"
	page.Descr = describeArea(name, page.Features)
	render(w, "area.html", page)
}

func describeArea(name string, features []areaFeature) string {
	withWalk := 0
	for _, f := range features {
		if f.HikeDistance != nil && *f.HikeDistance != "" {
			withWalk++
		}
	}
	return plural(len(features), "waterfall") + " and lookout towers in " + name +
		", Western North Carolina, with round trip distance and difficulty for " +
		itoa(withWalk) + " of them."
}

// A waterfall's own address, so an open card can be shared, linked and counted
// as a page. The map is a single page, so this serves the same document and
// index.html reads the path to decide what to open.
//
// The ID LEADS AND THE SLUG IS DECORATION: /falls/378-looking-glass-falls is
// resolved entirely on the 378. Names change here -- Clingmans Dome became
// Kuwohi -- and a slug-only URL would break every link ever shared the moment
// one did. A stale or wrong slug redirects to the current spelling rather than
// 404ing, which keeps old links working and keeps one canonical URL per place
// for search engines.
func placeHandler(w http.ResponseWriter, r *http.Request) {
	ref := mux.Vars(r)["ref"]
	id, err := strconv.Atoi(strings.SplitN(ref, "-", 2)[0])
	if err != nil {
		http.NotFound(w, r)
		return
	}

	var name, slug string
	err = db.QueryRow(`SELECT name, slug FROM features WHERE id = $1`, id).Scan(&name, &slug)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("place page %s: %v", ref, err)
		http.Error(w, "Something went wrong", http.StatusInternalServerError)
		return
	}

	if canonical := strconv.Itoa(id) + "-" + slug; ref != canonical {
		http.Redirect(w, r, "/falls/"+canonical, http.StatusMovedPermanently)
		return
	}

	http.ServeFile(w, r, "./static/index.html")
}
