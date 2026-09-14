package main

import (
	"log"
	"net/http"
)

// The two landing pages. A curated list is content in a way a generated page
// about one waterfall is not, so these carry no thin-content risk and are the
// part of this worth ranking.
//
// They cannot be two filters over one list. 857 of 900 located falls stand
// inside the Blue Ridge province, so "Blue Ridge waterfalls" and "WNC
// waterfalls" would be the same page twice. They differ in how they are
// organised instead, which is also how people actually decide: the escarpment
// page groups by how much walking a fall costs, and the WNC page groups by
// where you are staying.
type landingGroup struct {
	Heading  string
	Blurb    string
	Features []*pageFeature
	MoreLink string
	MoreText string
}

type landingPage struct {
	Title     string
	Descr     string
	Canonical string
	Indexable bool
	Heading   string
	Intro     []string
	Groups    []landingGroup
	Note      string
}

// Round trip miles, or nothing. rt_hike_distance is free text from several
// sources: "Roadside", "4.4", "0.6 Miles (out and back)", and one "2.8.30".
const milesExpr = `
	CASE WHEN features.rt_hike_distance ILIKE 'roadside' THEN 0
	     WHEN features.rt_hike_distance ~ '^[0-9]+(\.[0-9]+)?( |$)'
	     THEN substring(features.rt_hike_distance from '^[0-9]+(?:\.[0-9]+)?')::numeric
	END`

func landingFeatures(where string, args ...any) ([]*pageFeature, error) {
	rows, err := db.Query(`SELECT `+featureColumns+featureJoins+`
		WHERE features.deprecated_reason IS NULL
		  AND features.feature_location_id IS NOT NULL
		  AND features.kind = 'waterfall' AND `+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*pageFeature
	for rows.Next() {
		f, err := scanFeature(rows)
		if err != nil {
			return nil, err
		}
		if err := loadAreasOnly(f); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, nil
}

// The listings show an area beside each name; the rest of a feature's detail is
// its own page's job.
func loadAreasOnly(f *pageFeature) error {
	rows, err := db.Query(`
		SELECT DISTINCT areas.name, areas.slug FROM feature_areas
		JOIN areas ON areas.id = feature_areas.area_id
		WHERE feature_areas.feature_id = $1 ORDER BY areas.name`, f.ID)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
		var a areaRef
		if err := rows.Scan(&a.Name, &a.Slug); err != nil {
			return err
		}
		f.Areas = append(f.Areas, a)
	}
	return nil
}

func blueRidgeHandler(w http.ResponseWriter, r *http.Request) {
	page := landingPage{
		Title:     "Blue Ridge Waterfalls: 857 Falls on the Escarpment - Wanderfall",
		Descr:     "Waterfalls of the Blue Ridge province in North and South Carolina, sorted by how far you have to walk: roadside pull-offs, short trails, day hikes and the ones that take all day.",
		Canonical: "https://wanderfall.app/blue-ridge-waterfalls",
		Indexable: true,
		Heading:   "Blue Ridge waterfalls",
		Intro: []string{
			"The Blue Ridge Escarpment is the reason this many waterfalls exist in one place. The mountains end here, not gradually but in a wall, and every creek that crosses that edge has to fall. 857 of the falls we carry stand inside the Blue Ridge physiographic province, measured against the USGS boundary rather than guessed at.",
			"Sorted below by the thing that actually decides your day, which is not height or beauty but how far you have to walk. 72 of these are roadside. Another 157 are under a mile round trip. At the other end, 109 are over six miles, and a few of those climb three thousand feet on the way.",
		},
		Note: "Distances are round trip where the source said so. Where two sources disagreed, the feature's own page says by how much.",
	}

	groups := []struct {
		heading, blurb, where string
		args                  []any
	}{
		{"Roadside", "You can see these from the car, or from a few steps of it. Good for a day when the weather has other plans.",
			`features.in_blue_ridge AND ` + milesExpr + ` = 0`, nil},
		{"Under a mile", "Short enough to do three in an afternoon.",
			`features.in_blue_ridge AND ` + milesExpr + ` > 0 AND ` + milesExpr + ` < 1`, nil},
		{"One to three miles", "The ordinary shape of a waterfall walk here.",
			`features.in_blue_ridge AND ` + milesExpr + ` BETWEEN 1 AND 3`, nil},
		{"Three to six miles", "A morning, and boots rather than trainers.",
			`features.in_blue_ridge AND ` + milesExpr + ` > 3 AND ` + milesExpr + ` <= 6`, nil},
		{"All day", "Over six miles round trip. Several of these are in gorges, which means the climb is on the way out, when you are tired.",
			`features.in_blue_ridge AND ` + milesExpr + ` > 6`, nil},
	}

	for _, g := range groups {
		feats, err := landingFeatures(g.where+` ORDER BY features.beauty_rating DESC NULLS LAST, features.name LIMIT 40`, g.args...)
		if err != nil {
			log.Printf("blue ridge page: %v", err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		page.Groups = append(page.Groups, landingGroup{
			Heading: g.heading, Blurb: g.blurb, Features: feats,
		})
	}
	render(w, "landing.html", page)
}

func wncHandler(w http.ResponseWriter, r *http.Request) {
	page := landingPage{
		Title:     "WNC Waterfalls by Area: Brevard, Highlands, Cashiers and the Rest - Wanderfall",
		Descr:     "Waterfalls of Western North Carolina grouped by where you are staying, from Brevard and DuPont to Highlands, Cashiers, Boone and the Smokies.",
		Canonical: "https://wanderfall.app/wnc-waterfalls",
		Indexable: true,
		Heading:   "Waterfalls in Western North Carolina",
		Intro: []string{
			"Nobody plans a waterfall trip by browsing every waterfall. You are staying somewhere, and you want to know what is within half an hour of it. So this is grouped by area rather than by name, height or rating.",
			"The areas come from the sources themselves rather than from drawing circles on a map, which is why they are uneven: Brevard has 65 and Valdese has one. A fall can belong to more than one.",
		},
		Note: "Every name links to what we know about that fall: the walk, the climb, where to park, and how many independent sources agree on where it is.",
	}

	rows, err := db.Query(`
		SELECT areas.name, areas.slug, count(*) AS n
		FROM areas
		JOIN feature_areas ON feature_areas.area_id = areas.id
		JOIN features ON features.id = feature_areas.feature_id
		WHERE features.deprecated_reason IS NULL
		  AND features.feature_location_id IS NOT NULL
		GROUP BY areas.name, areas.slug
		HAVING count(*) >= 5
		ORDER BY count(*) DESC`)
	if err != nil {
		log.Printf("wnc page: %v", err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}
	type areaRow struct {
		name, slug string
		n          int
	}
	var areas []areaRow
	for rows.Next() {
		var a areaRow
		if err := rows.Scan(&a.name, &a.slug, &a.n); err != nil {
			rows.Close()
			log.Printf("wnc page: %v", err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		areas = append(areas, a)
	}
	rows.Close()

	for _, a := range areas {
		feats, err := landingFeatures(`features.id IN (
				SELECT feature_id FROM feature_areas
				JOIN areas ON areas.id = feature_areas.area_id WHERE areas.slug = $1)
			ORDER BY features.beauty_rating DESC NULLS LAST, features.name LIMIT 12`, a.slug)
		if err != nil {
			log.Printf("wnc page %s: %v", a.slug, err)
			http.Error(w, "unavailable", http.StatusInternalServerError)
			return
		}
		g := landingGroup{Heading: a.name, Features: feats}
		if a.n > len(feats) {
			g.MoreLink = "/areas/" + a.slug
			g.MoreText = "all " + plural(a.n, "waterfall") + " in " + a.name
		}
		page.Groups = append(page.Groups, g)
	}
	render(w, "landing.html", page)
}

func plural(n int, word string) string {
	if n == 1 {
		return "1 " + word
	}
	return itoa(n) + " " + word + "s"
}
