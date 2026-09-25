// Import spidered waterfalls into features, matching on coordinates.
//
//	go run script/import/waterfalls.go              # dry run, prints the plan
//	go run script/import/waterfalls.go -commit      # actually writes
//
// Matching: <=40m is the same fall whatever it's called -- GPS says it's the
// same spot. >250m is a different fall. In between, the name decides, because
// that band is exactly where Upper/Lower/Little pairs live: they sit 100-200m
// apart by nature and are genuinely separate waterfalls.
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"

	_ "github.com/lib/pq"
)

const (
	dbUser = "johnathonwright"
	dbPass = "postgres"
	dbName = "wc_journey_db"

	sameDist  = 40.0  // metres: same fall regardless of name
	maybeDist = 250.0 // metres: beyond this, always a different fall
)

// ---------- source records ----------

type gps struct {
	Lat *float64 `json:"Latitude"`
	Lon *float64 `json:"Longitude"`
	Raw string   `json:"-"`
}

func (g *gps) UnmarshalJSON(b []byte) error {
	type alias gps
	var a alias
	if err := json.Unmarshal(b, &a); err == nil {
		*g = gps(a)
		return nil
	}
	var s string
	if err := json.Unmarshal(b, &s); err == nil {
		g.Raw = s
		return nil
	}
	return nil // unparseable GPS is not fatal; the record still has a name
}

type mixed string

func (m *mixed) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err == nil {
		*m = mixed(s)
		return nil
	}
	var f float64
	if err := json.Unmarshal(b, &f); err == nil {
		*m = mixed(strconv.FormatFloat(f, 'f', -1, 64))
		return nil
	}
	return nil
}

type fall struct {
	Name          string `json:"Name"`
	Beauty        mixed  `json:"Beauty"`
	Photo         mixed  `json:"Photo Rating"`
	Solitude      mixed  `json:"Solitude"`
	GPS           *gps   `json:"GPS"`
	Height        string `json:"Height"`
	Distance      mixed  `json:"Distance"`
	Accessibility string `json:"Accessibility"`
	Number        string `json:"Number"`
	URL           string `json:"url"`
}

// ---------- geo ----------

func haversine(aLat, aLon, bLat, bLon float64) float64 {
	const R = 6371000.0
	p1, p2 := aLat*math.Pi/180, bLat*math.Pi/180
	dp := p2 - p1
	dl := (bLon - aLon) * math.Pi / 180
	h := math.Sin(dp/2)*math.Sin(dp/2) + math.Cos(p1)*math.Cos(p2)*math.Sin(dl/2)*math.Sin(dl/2)
	return 2 * R * math.Asin(math.Sqrt(h))
}

var rawGPS = regexp.MustCompile(`LAT\s+(-?\d+\.\d+)\s+LONG\s+(-?\d+\.\d+)`)

// coords returns the record's position, or ok=false when it has none we can use.
func (f fall) coords() (lat, lon float64, ok bool) {
	if f.GPS == nil {
		return 0, 0, false
	}
	if f.GPS.Lat != nil && f.GPS.Lon != nil {
		lat, lon = *f.GPS.Lat, *f.GPS.Lon
	} else if m := rawGPS.FindStringSubmatch(f.GPS.Raw); m != nil {
		lat, _ = strconv.ParseFloat(m[1], 64)
		lon, _ = strconv.ParseFloat(m[2], 64)
	} else {
		return 0, 0, false
	}
	// Southern Appalachians. Anything outside this is corrupt, not a real place.
	if lat < 30 || lat > 40 || lon < -90 || lon > -78 {
		return 0, 0, false
	}
	return lat, lon, true
}

// ---------- name comparison ----------

var (
	nonWord = regexp.MustCompile(`[^a-z0-9 ]+`)
	spaces  = regexp.MustCompile(`\s+`)
	// Words that carry no identity: dropping them lets "Cedar Rock Creek Falls"
	// meet "Cedar Rock Falls". Upper/Lower/Little are deliberately NOT here --
	// they are the whole point.
	filler = map[string]bool{
		"creek": true, "branch": true, "river": true, "run": true, "prong": true,
		"the": true, "on": true, "of": true, "a": true, "at": true,
		"waterfall": true, "waterfalls": true, "cascade": true, "cascades": true,
	}
)

// nameCore reduces a name to the words before the first "falls", minus filler.
// Truncating at "falls" is what keeps "Bridalveil Falls (DuPont)- Little River"
// together with "Bridalveil Falls (DuPont)" -- that trailing "Little" names a
// river, not a smaller waterfall.
func nameCore(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, "'", "")
	s = nonWord.ReplaceAllString(s, " ")
	s = spaces.ReplaceAllString(strings.TrimSpace(s), " ")

	var out []string
	for _, w := range strings.Fields(s) {
		if w == "falls" || w == "fall" {
			break
		}
		if filler[w] {
			continue
		}
		out = append(out, w)
	}
	if len(out) == 0 {
		for _, w := range strings.Fields(s) {
			if !filler[w] {
				out = append(out, w)
			}
		}
	}
	sort.Strings(out)
	return strings.Join(out, " ")
}

// namesAgree compares two names by core, tolerating lost word breaks:
// hikingwnc writes "Craborchard Falls" where the CMC list says "Crab Orchard Falls".
func namesAgree(a, b string) bool {
	ca, cb := nameCore(a), nameCore(b)
	if ca == cb {
		return true
	}
	return strings.ReplaceAll(ca, " ", "") == strings.ReplaceAll(cb, " ", "")
}

// ---------- existing features ----------

type feature struct {
	id       int
	name     string
	lat, lon float64
	hasCoord bool
}

func loadFeatures(db *sql.DB) []feature {
	rows, err := db.Query(`
		SELECT f.id, f.name, l.latitude, l.longitude
		FROM features f LEFT JOIN locations l ON l.id = f.feature_location_id`)
	if err != nil {
		log.Fatal(err)
	}
	defer rows.Close()

	var out []feature
	for rows.Next() {
		var f feature
		var lat, lon sql.NullFloat64
		if err := rows.Scan(&f.id, &f.name, &lat, &lon); err != nil {
			log.Fatal(err)
		}
		if lat.Valid && lon.Valid {
			f.lat, f.lon, f.hasCoord = lat.Float64, lon.Float64, true
		}
		out = append(out, f)
	}
	if err := rows.Err(); err != nil {
		log.Fatal(err)
	}
	return out
}

// ---------- planning ----------

type verdict int

const (
	matchCertain verdict = iota // <=40m
	matchNamed                  // 40-250m, names agree
	newFar                      // >250m
	newNamed                    // 40-250m, names disagree
	newNoCoord                  // no usable coordinates, no name match
	matchNoCoord                // no coordinates, but the name is already known
)

func (v verdict) isMatch() bool {
	return v == matchCertain || v == matchNamed || v == matchNoCoord
}

type plan struct {
	rec      fall
	v        verdict
	target   *feature
	distance float64
	note     string
	dupOf    *plan // set when another source record describes this same fall
}

func main() {
	commit := flag.Bool("commit", false, "write to the database (default: dry run)")
	dbTarget := flag.String("db", dbName, "database to import into")
	flag.Parse()

	records := loadSource("data/hiking_wnc_falls.json", "data/hiking_wnc_falls_supplement.json")
	fmt.Printf("source: %d unique records (by url)\n\n", len(records))

	db, err := sql.Open("postgres",
		fmt.Sprintf("host=localhost user=%s password=%s dbname=%s sslmode=disable", dbUser, dbPass, *dbTarget))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		log.Fatal(err)
	}

	existing := loadFeatures(db)
	byCore := map[string][]*feature{}
	for i := range existing {
		c := nameCore(existing[i].name)
		byCore[c] = append(byCore[c], &existing[i])
	}

	plans := make([]plan, 0, len(records))
	for _, r := range records {
		plans = append(plans, decide(r, existing, byCore))
	}

	collapseDuplicates(plans)
	report(plans)

	if *commit {
		apply(db, plans)
	} else {
		fmt.Println("\nDry run. Nothing written. Re-run with -commit to apply.")
	}
}

func decide(r fall, existing []feature, byCore map[string][]*feature) plan {
	lat, lon, ok := r.coords()
	if !ok {
		// Fall back to the name alone.
		if fs := byCore[nameCore(r.Name)]; len(fs) == 1 {
			return plan{rec: r, v: matchNoCoord, target: fs[0], note: "no coordinates; matched on name"}
		}
		return plan{rec: r, v: newNoCoord, note: "no coordinates"}
	}

	var best *feature
	bestD := math.Inf(1)
	for i := range existing {
		if !existing[i].hasCoord {
			continue
		}
		d := haversine(lat, lon, existing[i].lat, existing[i].lon)
		if d < bestD {
			bestD, best = d, &existing[i]
		}
	}

	switch {
	case best == nil || bestD > maybeDist:
		return plan{rec: r, v: newFar, distance: bestD}
	case bestD <= sameDist:
		return plan{rec: r, v: matchCertain, target: best, distance: bestD}
	case namesAgree(r.Name, best.name):
		return plan{rec: r, v: matchNamed, target: best, distance: bestD,
			note: fmt.Sprintf("names agree (%q ~ %q)", r.Name, best.name)}
	default:
		return plan{rec: r, v: newNamed, target: best, distance: bestD,
			note: fmt.Sprintf("nearest is %q at %.0fm, but the names distinguish them", best.name, bestD)}
	}
}

// collapseDuplicates finds source records that describe the same fall as each
// other -- hikingwnc lists some falls twice under different numbers, e.g. "The
// Chute" at 097 and again at 103. Without this each copy becomes its own
// feature. The duplicate contributes its url as a second link instead.
func collapseDuplicates(plans []plan) {
	var accepted []*plan
	for i := range plans {
		p := &plans[i]
		if p.v.isMatch() {
			continue
		}
		lat, lon, ok := p.rec.coords()
		for _, q := range accepted {
			if !namesAgree(p.rec.Name, q.rec.Name) {
				continue
			}
			qlat, qlon, qok := q.rec.coords()
			switch {
			case ok && qok && haversine(lat, lon, qlat, qlon) <= sameDist:
				p.dupOf = q
			case !ok && !qok:
				// Neither has coordinates; the name is all we have to go on.
				p.dupOf = q
			}
			if p.dupOf != nil {
				break
			}
		}
		if p.dupOf == nil {
			accepted = append(accepted, p)
		}
	}
}

func report(plans []plan) {
	counts := map[verdict]int{}
	dupes := 0
	for _, p := range plans {
		if p.dupOf != nil {
			dupes++
			continue
		}
		counts[p.v]++
	}
	fmt.Println("PLAN")
	fmt.Printf("  match, <=%.0fm                    %4d\n", sameDist, counts[matchCertain])
	fmt.Printf("  match, %.0f-%.0fm, names agree    %4d\n", sameDist, maybeDist, counts[matchNamed])
	fmt.Printf("  match, no coords, name known    %4d\n", counts[matchNoCoord])
	fmt.Printf("  new, >%.0fm                      %4d\n", maybeDist, counts[newFar])
	fmt.Printf("  new, %.0f-%.0fm, names differ     %4d\n", sameDist, maybeDist, counts[newNamed])
	fmt.Printf("  new, no coordinates             %4d\n", counts[newNoCoord])
	fmt.Printf("  duplicate within source         %4d  (folded in as extra links)\n", dupes)

	fmt.Printf("\nAMBIGUOUS BAND (%.0f-%.0fm) -- every judgement call, review these\n", sameDist, maybeDist)
	var band []plan
	for _, p := range plans {
		if p.dupOf == nil && (p.v == matchNamed || p.v == newNamed) {
			band = append(band, p)
		}
	}
	sort.Slice(band, func(i, j int) bool { return band[i].distance < band[j].distance })
	for _, p := range band {
		what := "NEW  "
		if p.v.isMatch() {
			what = "MERGE"
		}
		fmt.Printf("  %s %5.0fm  %-46s -> %s\n", what, p.distance, trunc(p.rec.Name, 46), p.target.name)
	}

	fmt.Println("\nNO USABLE COORDINATES -- will import with no location (invisible on the map)")
	n := 0
	for _, p := range plans {
		if p.dupOf == nil && p.v == newNoCoord {
			n++
			if n <= 25 {
				fmt.Printf("  %-52s %s\n", trunc(p.rec.Name, 52), p.rec.URL)
			}
		}
	}
	if n > 25 {
		fmt.Printf("  ... and %d more\n", n-25)
	}
}

func trunc(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}

func loadSource(paths ...string) []fall {
	seen := map[string]bool{}
	var out []fall
	for _, p := range paths {
		raw, err := os.ReadFile(p)
		if err != nil {
			log.Fatalf("%s: %v", p, err)
		}
		// The supplement has a trailing comma before its closing bracket.
		txt := regexp.MustCompile(`,(\s*])\s*$`).ReplaceAllString(strings.TrimSpace(string(raw)), "$1")
		var fs []fall
		if err := json.Unmarshal([]byte(txt), &fs); err != nil {
			log.Fatalf("%s: %v", p, err)
		}
		for _, f := range fs {
			if f.URL == "" || seen[f.URL] {
				continue
			}
			seen[f.URL] = true
			out = append(out, f)
		}
	}
	return out
}

// ---------- writing ----------

var heightRe = regexp.MustCompile(`(\d+)`)

// rating parses a 1-10 score. The source contains a Beauty of 46; anything
// outside the range is dropped rather than clamped, since we can't know which
// digit was the typo.
func rating(m mixed) *int {
	n, err := strconv.Atoi(strings.TrimSpace(string(m)))
	if err != nil || n < 1 || n > 10 {
		return nil
	}
	return &n
}

func heightFt(s string) *int {
	m := heightRe.FindStringSubmatch(s)
	if m == nil {
		return nil
	}
	n, err := strconv.Atoi(m[1])
	if err != nil || n <= 0 || n > 1000 {
		return nil
	}
	return &n
}

func text(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}

func apply(db *sql.DB, plans []plan) {
	tx, err := db.Begin()
	if err != nil {
		log.Fatal(err)
	}
	defer tx.Rollback()

	var inserted, linked, backfilled, dupLinks int
	newID := map[*plan]int{} // plan -> the feature id it created, for dupOf

	for i := range plans {
		p := &plans[i]

		// Which feature does this record belong to?
		var featureID int
		switch {
		case p.dupOf != nil:
			id, ok := newID[p.dupOf]
			if !ok {
				log.Fatalf("duplicate %q has no feature", p.rec.Name)
			}
			featureID = id
			dupLinks++
		case p.v.isMatch():
			featureID = p.target.id
			if backfill(tx, featureID, p.rec) {
				backfilled++
			}
		default:
			featureID = insertFeature(tx, p.rec)
			newID[p] = featureID
			inserted++
		}

		if addLink(tx, featureID, p) {
			linked++
		}
	}

	if err := tx.Commit(); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("\ncommitted: %d features inserted, %d links written (%d of them duplicates), %d existing features backfilled\n",
		inserted, linked, dupLinks, backfilled)
}

// insertFeature writes the location and the feature together, so a failure
// can't leave a location behind with nothing pointing at it.
func insertFeature(tx *sql.Tx, r fall) int {
	var locID *int
	if lat, lon, ok := r.coords(); ok {
		var id int
		if err := tx.QueryRow(
			`INSERT INTO locations (latitude, longitude) VALUES ($1, $2) RETURNING id`,
			lat, lon).Scan(&id); err != nil {
			log.Fatalf("location for %q: %v", r.Name, err)
		}
		locID = &id
	}

	name := r.Name
	if len(name) > 100 {
		name = name[:100]
	}

	var id int
	err := tx.QueryRow(`
		INSERT INTO features (name, kind, feature_location_id, rt_hike_distance,
		                      accessibility, height_ft, beauty_rating, photo_rating, solitude_rating)
		VALUES ($1, 'waterfall', $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
		name, locID, text(string(r.Distance)), text(r.Accessibility), heightFt(r.Height),
		rating(r.Beauty), rating(r.Photo), rating(r.Solitude)).Scan(&id)
	if err != nil {
		log.Fatalf("feature %q: %v", r.Name, err)
	}
	return id
}

// backfill fills gaps on an existing feature without touching curated values.
// COALESCE means hikingwnc can only add, never overwrite.
func backfill(tx *sql.Tx, id int, r fall) bool {
	res, err := tx.Exec(`
		UPDATE features SET
			rt_hike_distance = COALESCE(rt_hike_distance, $2),
			accessibility    = COALESCE(accessibility,    $3),
			height_ft        = COALESCE(height_ft,        $4),
			beauty_rating    = COALESCE(beauty_rating,    $5),
			photo_rating     = COALESCE(photo_rating,     $6),
			solitude_rating  = COALESCE(solitude_rating,  $7)
		WHERE id = $1
		  AND (rt_hike_distance IS NULL OR accessibility IS NULL OR height_ft IS NULL
		       OR beauty_rating IS NULL OR photo_rating IS NULL OR solitude_rating IS NULL)`,
		id, text(string(r.Distance)), text(r.Accessibility), heightFt(r.Height),
		rating(r.Beauty), rating(r.Photo), rating(r.Solitude))
	if err != nil {
		log.Fatalf("backfill %d: %v", id, err)
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// addLink records where this feature came from, and why the importer decided
// what it decided -- so any of these calls can be found and reversed later.
func addLink(tx *sql.Tx, featureID int, p *plan) bool {
	note := fmt.Sprintf("hikingwnc #%s", p.rec.Number)
	switch {
	case p.dupOf != nil:
		note += fmt.Sprintf("; same fall as %q elsewhere in the source", p.dupOf.rec.Name)
	case p.v == matchCertain:
		note += fmt.Sprintf("; matched %q at %.0fm", p.target.name, p.distance)
	case p.v == matchNamed:
		note += fmt.Sprintf("; matched %q at %.0fm, %s", p.target.name, p.distance, p.note)
	case p.v == matchNoCoord:
		note += "; " + p.note
	case p.v == newNamed:
		note += fmt.Sprintf("; imported as new -- %s", p.note)
	case p.v == newNoCoord:
		note += "; imported with no location (source has no usable coordinates)"
	}

	res, err := tx.Exec(`
		INSERT INTO links (feature_id, url, rel, comments) VALUES ($1, $2, 'hikingwnc', $3)
		ON CONFLICT (feature_id, url) DO NOTHING`, featureID, p.rec.URL, note)
	if err != nil {
		log.Fatalf("link for %q: %v", p.rec.Name, err)
	}
	n, _ := res.RowsAffected()
	return n > 0
}
