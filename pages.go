package main

import (
	"database/sql"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"regexp"
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
	// Which nav link to mark as current. Empty on a page that is not one of
	// the nav destinations, which is right for a single area: it sits under
	// Areas without being it.
	Nav string
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
	Nav       string
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
		Nav:       "areas",
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
		WHERE areas.slug = $1
		ORDER BY features.name`, slug)
	if err != nil {
		log.Printf("area page %s: %v", slug, err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	page := areaPage{Name: name, Slug: slug,
		Nav:       "areas",
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
	var kind string
	var height *int
	var distance, owner, area *string
	err = db.QueryRow(`
		SELECT f.name, f.slug, f.kind, f.height_ft, f.rt_hike_distance, f.owner,
		       (SELECT a.name FROM feature_areas fa JOIN areas a ON a.id = fa.area_id
		         WHERE fa.feature_id = f.id ORDER BY length(a.name) LIMIT 1)
		FROM features f WHERE f.id = $1
	`, id).Scan(&name, &slug, &kind, &height, &distance, &owner, &area)
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

	renderApp(w, appHead{
		Title:     name,
		Descr:     describePlace(kind, height, distance, owner, area),
		Canonical: "https://wanderfall.app/falls/" + strconv.Itoa(id) + "-" + slug,
	})
}

// The map page is a template now, not a static file, so a link to one
// waterfall can preview as that waterfall. Everything a scraper reads --
// title, description, canonical url -- is per-place when the page is reached
// at /falls/<id>-<slug>, and site-level at /.
//
// Parsed once at startup. index.html contains no other template actions, so
// the only thing this changes about the file is those four placeholders.
var bareDistance = regexp.MustCompile(`^[0-9]+(\.[0-9]+)?$`)

var appTemplate = template.Must(template.ParseFiles("static/index.html"))

type appHead struct {
	Title     string
	Descr     string
	Canonical string
}

const siteDescr = "A map and logbook for the waterfalls and lookout towers of " +
	"Western North Carolina. Find somewhere to go, record that you went, and " +
	"track progress against the challenge lists."

func renderApp(w http.ResponseWriter, head appHead) {
	// no-cache for the same reason the static file carried it: the page and
	// the scripts it loads are edited together and a browser holding
	// yesterday's ratings.js against today's page breaks the drawer.
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := appTemplate.Execute(w, head); err != nil {
		log.Printf("rendering the map page: %v", err)
	}
}

func appHome(w http.ResponseWriter, r *http.Request) {
	renderApp(w, appHead{
		Title:     "Wanderfall",
		Descr:     siteDescr,
		Canonical: "https://wanderfall.app/",
	})
}

// describePlace writes the sentence a shared link previews with, out of
// whatever we actually hold. Each clause is skipped rather than guessed, so a
// feature with nothing on file still gets a sentence rather than "a
// waterfall of undefined feet".
func describePlace(kind string, height *int, distance, owner, area *string) string {
	noun := map[string]string{
		"waterfall":     "waterfall",
		"tower":         "lookout tower",
		"swimming_hole": "swimming hole",
	}[kind]
	if noun == "" {
		noun = "place"
	}

	s := "A "
	if height != nil && *height > 0 {
		s += fmt.Sprintf("%d ft ", *height)
	}
	s += noun
	if area != nil && *area != "" {
		s += " in " + *area
	} else if owner != nil && *owner != "" {
		s += " on " + *owner + " land"
	}
	s += "."
	// rt_hike_distance is free text from several sources: "1.9", "0.8 mi",
	// "Approx 1 mile each way", "Roadside". Only a bare number can safely
	// have "round trip" appended -- doing it to "each way" produces a
	// sentence that contradicts itself.
	if distance != nil && strings.TrimSpace(*distance) != "" {
		d := strings.TrimSpace(*distance)
		if bareDistance.MatchString(d) {
			s += " " + d + " miles round trip."
		} else {
			s += " " + strings.TrimSuffix(d, ".") + "."
		}
	}
	return s + " Open it on the map to see where it is and what the sources say."
}

// recordView increments the daily view count for the waterfall the client just
// opened. Called by the JS drawer on every open — map click, direct link, or
// search result — so the count covers all paths in, not just /falls/ page loads.
func recordView(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(mux.Vars(r)["id"])
	if err != nil {
		http.NotFound(w, r)
		return
	}
	_, err = db.Exec(`
		INSERT INTO feature_views (feature_id, date, view_count)
		VALUES ($1, CURRENT_DATE, 1)
		ON CONFLICT (feature_id, date) DO UPDATE
		SET view_count = feature_views.view_count + 1`, id)
	if err != nil {
		log.Printf("recordView %d: %v", id, err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
