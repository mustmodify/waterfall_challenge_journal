package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

const (
	DB_USER     = "johnathonwright"
	DB_PASSWORD = "postgres"
	DB_NAME     = "wc_journey_db"
)

var db *sql.DB

// A host hands you one connection string and expects the app to use it. The
// constants above stay as the development fallback so a local checkout still
// runs with no environment at all.
func dbSource() string {
	if url := os.Getenv("DATABASE_URL"); url != "" {
		return url
	}
	return fmt.Sprintf("host=localhost user=%s password=%s dbname=%s sslmode=disable",
		DB_USER, DB_PASSWORD, DB_NAME)
}

func init() {
	var err error
	db, err = sql.Open("postgres", dbSource())
	if err != nil {
		log.Fatal(err)
	}
	if err = db.Ping(); err != nil {
		log.Fatal(err)
	}
	fmt.Println("Connected to the database!")
}

type Location struct {
	ID        int      `json:"id"`
	Latitude  *float64 `json:"latitude,omitempty"`
	Longitude *float64 `json:"longitude,omitempty"`
}

type Feature struct {
	ID                int           `json:"id"`
	Name              string        `json:"name"`
	Slug              *string       `json:"slug,omitempty"`
	Kind              string        `json:"kind"`
	FeatureLocationID *int          `json:"feature_location_id"`
	ParkingLocationID *int          `json:"parking_location_id"`
	RtHikeDistance    *string       `json:"rt_hike_distance,omitempty"`
	DifficultyRating  *string       `json:"difficulty_rating,omitempty"`
	Accessibility     *string       `json:"accessibility,omitempty"`
	HeightFt          *int          `json:"height_ft,omitempty"`
	ElevationFt       *int          `json:"elevation_ft,omitempty"`
	BeautyRating      *int          `json:"beauty_rating,omitempty"`
	PhotoRating       *int          `json:"photo_rating,omitempty"`
	SolitudeRating    *int          `json:"solitude_rating,omitempty"`
	HwncID            *int          `json:"hwnc_id,omitempty"`
	CmcHikeNo         *int          `json:"cmc_hike_no,omitempty"`
	BookPage          *int          `json:"book_page,omitempty"`
	Location          *Location     `json:"location,omitempty"`
	ParkingLocation   *Location     `json:"parking_location,omitempty"`
	LastVisited       *string       `json:"last_visited,omitempty"`
	Challenges        []string      `json:"challenges"`
	Links             []Link        `json:"links"`
	Areas             []string      `json:"areas"`
	Notes             []FeatureNote  `json:"notes"`
	AccessNotes       []AccessNote   `json:"access_notes"`
	Confidence        *string        `json:"confidence,omitempty"`
	Owner             *string       `json:"owner,omitempty"`
	DeprecatedReason  *string       `json:"deprecated_reason,omitempty"`
	DeprecatedNote    *string       `json:"deprecated_note,omitempty"`
	DeprecatedOn      *string       `json:"deprecated_on,omitempty"`
}

// FeatureNote is the trimmed form of a note carried inside a Feature. Source
// is empty for the account owner's own notes and names the publication
// otherwise, so an editorial warning is not mistaken for something you wrote.
type FeatureNote struct {
	Text   string `json:"text"`
	Source string `json:"source,omitempty"`
}

// AccessNote is a structured condition worth knowing before visiting: a
// closure, fee, permit requirement, or hazard. Severity is one of
// closed/urgent/restricted/fee/info in ascending order of urgency.
type AccessNote struct {
	Severity   string  `json:"severity"`
	Text       string  `json:"text"`
	Source     string  `json:"source"`
	ObservedOn *string `json:"observed_on,omitempty"`
}

// Link is an outside page about a feature -- almost always its hikingwnc.com
// entry, which carries directions, photos and current trail conditions that
// this app has no business duplicating.
type Link struct {
	URL string `json:"url"`
	Rel string `json:"rel,omitempty"`
}

type Note struct {
	ID        int    `json:"id"`
	FeatureID int    `json:"feature_id"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	Text      string `json:"text"`
}

// Create a new location
func createLocation(w http.ResponseWriter, r *http.Request) {
	var loc Location
	json.NewDecoder(r.Body).Decode(&loc)
	sqlStatement := `INSERT INTO locations (latitude, longitude) VALUES ($1, $2) RETURNING id`
	err := db.QueryRow(sqlStatement, loc.Latitude, loc.Longitude).Scan(&loc.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(loc)
}

// Get all locations
func getLocations(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, latitude, longitude FROM locations")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	locations := []Location{}
	for rows.Next() {
		var loc Location
		err := rows.Scan(&loc.ID, &loc.Latitude, &loc.Longitude)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		locations = append(locations, loc)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(locations)
}

// Update a location
func updateLocation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var loc Location
	json.NewDecoder(r.Body).Decode(&loc)

	sqlStatement := `UPDATE locations SET latitude=$1, longitude=$2 WHERE id=$3`
	_, err := db.Exec(sqlStatement, loc.Latitude, loc.Longitude, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Delete a location
func deleteLocation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	sqlStatement := `DELETE FROM locations WHERE id=$1`
	_, err := db.Exec(sqlStatement, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Create a new feature
func createFeature(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	var f Feature
	if err := json.NewDecoder(r.Body).Decode(&f); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}
	if f.Kind == "" {
		f.Kind = "waterfall"
	}
	sqlStatement := `INSERT INTO features (name, kind, parking_location_id, feature_location_id) VALUES ($1, $2, $3, $4) RETURNING id`
	err := db.QueryRow(sqlStatement, f.Name, f.Kind, f.ParkingLocationID, f.FeatureLocationID).Scan(&f.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(f)
}

func getFeatures(w http.ResponseWriter, r *http.Request) {
	// last_visited is per-user: anonymous visitors see no visit history.
	lastVisited := `NULL::text`
	args := []interface{}{}
	if user := currentUser(r); user != nil {
		lastVisited = `(SELECT MAX(visited_on)::text FROM visits WHERE visits.feature_id = features.id AND visits.user_id = $1)`
		args = append(args, user.ID)
	}
	rows, err := db.Query(`
		SELECT features.id, features.name, features.slug, kind, parking_location_id, feature_location_id,
			rt_hike_distance, difficulty_rating, accessibility, height_ft, elevation_ft,
			beauty_rating, photo_rating, solitude_rating,
			hwnc_id, cmc_hike_no, book_page,
			locations.id as location_id, locations.longitude, locations.latitude,
			parking_loc.id as parking_location_id_out, parking_loc.longitude as parking_lon, parking_loc.latitude as parking_lat,
			`+lastVisited+` AS last_visited,
			(SELECT string_agg(challenges.name, ',') FROM goals
				JOIN challenges ON challenges.id = goals.challenge_id
				WHERE goals.feature_id = features.id) AS challenge_names,
			-- rel and url joined per row, rows joined by newline. Neither
			-- character occurs in either column, so the split is unambiguous.
			(SELECT string_agg(coalesce(links.rel, '') || E'\t' || links.url, E'\n'
				ORDER BY links.id)
				FROM links WHERE links.feature_id = features.id) AS link_rows,
			(SELECT string_agg(DISTINCT areas.name, E'\n')
				FROM feature_areas JOIN areas ON areas.id = feature_areas.area_id
				WHERE feature_areas.feature_id = features.id) AS area_names,
			-- JSON rather than a delimiter: note text is free-form and could
			-- contain whatever character we picked to split on.
			(SELECT json_agg(json_build_object('text', notes.text, 'source',
				coalesce(notes.source, '')) ORDER BY notes.id)
				FROM notes WHERE notes.feature_id = features.id) AS note_json,
			(SELECT json_agg(json_build_object(
				'severity', feature_notes.severity,
				'text', feature_notes.text,
				'source', feature_notes.source,
				'observed_on', feature_notes.observed_on::text)
				ORDER BY feature_notes.severity, feature_notes.id)
				FROM feature_notes WHERE feature_notes.feature_id = features.id) AS access_note_json,
			confidence.tier,
			features.owner, deprecated_reason, deprecated_note,
			deprecated_on::text
		FROM features
			LEFT JOIN locations ON locations.id = features.feature_location_id
		LEFT JOIN locations parking_loc ON parking_loc.id = features.parking_location_id
			LEFT JOIN coordinate_confidence confidence ON confidence.feature_id = features.id
		-- A tower carries no source claims at all, so tiering would hide every
		-- one of them.
		WHERE features.kind <> 'waterfall'
		   OR confidence.tier IN ('confirmed', 'corroborated')
	`, args...)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	features := []Feature{}
	for rows.Next() {
		var f Feature
		var latitude, longitude sql.NullFloat64
		var locationID sql.NullInt64
		var parkingLat, parkingLon sql.NullFloat64
		var parkingLocID sql.NullInt64
		var lastVisited sql.NullString
		var challengeNames sql.NullString
		var linkRows sql.NullString
		var areaNames sql.NullString
		var noteJSON []byte
		var accessNoteJSON []byte
		var confidence sql.NullString

		err := rows.Scan(
			&f.ID,
			&f.Name,
			&f.Slug,
			&f.Kind,
			&f.ParkingLocationID,
			&f.FeatureLocationID,
			&f.RtHikeDistance,
			&f.DifficultyRating,
			&f.Accessibility,
			&f.HeightFt,
			&f.ElevationFt,
			&f.BeautyRating,
			&f.PhotoRating,
			&f.SolitudeRating,
			&f.HwncID,
			&f.CmcHikeNo,
			&f.BookPage,
			&locationID,
			&longitude,
			&latitude,
			&parkingLocID,
			&parkingLon,
			&parkingLat,
			&lastVisited,
			&challengeNames,
			&linkRows,
			&areaNames,
			&noteJSON,
			&accessNoteJSON,
			&confidence,
			&f.Owner,
			&f.DeprecatedReason,
			&f.DeprecatedNote,
			&f.DeprecatedOn,
		)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if lastVisited.Valid {
			f.LastVisited = &lastVisited.String
		}

		f.Challenges = []string{}
		if challengeNames.Valid && challengeNames.String != "" {
			f.Challenges = strings.Split(challengeNames.String, ",")
		}

		if confidence.Valid {
			tier := confidence.String
			f.Confidence = &tier
		}

		f.Areas = []string{}
		if areaNames.Valid && areaNames.String != "" {
			f.Areas = strings.Split(areaNames.String, "\n")
			sort.Strings(f.Areas)
		}

		f.Notes = []FeatureNote{}
		if len(noteJSON) > 0 {
			if err := json.Unmarshal(noteJSON, &f.Notes); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		}

		f.AccessNotes = []AccessNote{}
		if len(accessNoteJSON) > 0 {
			if err := json.Unmarshal(accessNoteJSON, &f.AccessNotes); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		}

		f.Links = []Link{}
		if linkRows.Valid && linkRows.String != "" {
			for _, row := range strings.Split(linkRows.String, "\n") {
				parts := strings.SplitN(row, "\t", 2)
				if len(parts) == 2 && parts[1] != "" {
					f.Links = append(f.Links, Link{Rel: parts[0], URL: parts[1]})
				}
			}
		}

		if latitude.Valid && longitude.Valid {
			f.Location = &Location{
				ID:        int(locationID.Int64),
				Latitude:  &latitude.Float64,
				Longitude: &longitude.Float64,
			}
		}

		if parkingLat.Valid && parkingLon.Valid {
			f.ParkingLocation = &Location{
				ID:        int(parkingLocID.Int64),
				Latitude:  &parkingLat.Float64,
				Longitude: &parkingLon.Float64,
			}
		}

		features = append(features, f)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(features)
}

// Update a feature
func updateFeature(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	vars := mux.Vars(r)
	id := vars["id"]

	var f Feature
	if err := json.NewDecoder(r.Body).Decode(&f); err != nil {
		http.Error(w, "Invalid input data", http.StatusBadRequest)
		return
	}

	sqlStatement := `UPDATE features SET name=$1, parking_location_id=$2, feature_location_id=$3 WHERE id=$4`
	_, err := db.Exec(sqlStatement, f.Name, f.ParkingLocationID, f.FeatureLocationID, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Delete a feature
func deleteFeature(w http.ResponseWriter, r *http.Request) {
	if !requireAdmin(w, r) {
		return
	}
	vars := mux.Vars(r)
	id := vars["id"]

	sqlStatement := `DELETE FROM features WHERE id=$1`
	_, err := db.Exec(sqlStatement, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// index.html and the scripts it loads are edited together and have to arrive
// together. A browser holding yesterday's ratings.js against today's page
// throws "wjBand is not a function" and the details drawer stops opening.
// no-cache still allows a 304, so this costs a conditional request, not a
// download.
// A tile key has to reach the browser to be used, so it cannot be secret. It
// can still be kept out of the repository and rotated without a commit, which
// is what this is for. Stadia scopes a key to the domains on its property, so
// a copied one is worth nothing elsewhere.
func clientConfig(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")
	key, _ := json.Marshal(os.Getenv("WANDERFALL_STADIA_KEY"))
	fmt.Fprintf(w, "window.WJ_CONFIG = { stadiaKey: %s };\n", key)
}

func noCache(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-cache")
		h.ServeHTTP(w, r)
	})
}

func main() {
	r := mux.NewRouter()

	// Routes
	r.HandleFunc("/locations", createLocation).Methods("POST")
	r.HandleFunc("/locations", getLocations).Methods("GET")
	r.HandleFunc("/locations/{id}", updateLocation).Methods("PUT")
	r.HandleFunc("/locations/{id}", deleteLocation).Methods("DELETE")

	r.HandleFunc("/features", createFeature).Methods("POST")
	r.HandleFunc("/features", getFeatures).Methods("GET")
	r.HandleFunc("/features/{id}", updateFeature).Methods("PUT")
	r.HandleFunc("/features/{id}", patchFeature).Methods("PATCH")
	r.HandleFunc("/features/{id}", deleteFeature).Methods("DELETE")

	r.HandleFunc("/signup", signup).Methods("POST")
	r.HandleFunc("/login", login).Methods("POST")
	r.HandleFunc("/logout", logout).Methods("POST")
	r.HandleFunc("/me", me).Methods("GET")
	r.HandleFunc("/config.js", clientConfig).Methods("GET")

	initPages()
	r.HandleFunc("/areas", areaIndexHandler).Methods("GET")
	r.HandleFunc("/areas/{slug}", areaHandler).Methods("GET")
	r.HandleFunc("/robots.txt", robotsHandler).Methods("GET")
	r.HandleFunc("/sitemap.xml", sitemapHandler).Methods("GET")

	signInLimit := newLimiter(5, 5)
	fixLimit := newLimiter(10, 10)

	r.HandleFunc("/auth/request", signInLimit.guard(requestMagicLink)).Methods("POST")
	r.HandleFunc("/auth/callback", consumeMagicLink).Methods("GET")
	r.HandleFunc("/challenges", getChallenges).Methods("GET")
	r.HandleFunc("/corrections", fixLimit.guard(createCorrection)).Methods("POST")
	r.HandleFunc("/corrections", listCorrections).Methods("GET")
	r.HandleFunc("/corrections/{id}", updateCorrection).Methods("PATCH")
	r.HandleFunc("/corrections/{id}", deleteCorrection).Methods("DELETE")
	r.HandleFunc("/users", listUsers).Methods("GET")
	r.HandleFunc("/visits", createVisit).Methods("POST")
	r.HandleFunc("/visits/batch", createVisits).Methods("POST")
	r.HandleFunc("/visits", getVisits).Methods("GET")
	r.HandleFunc("/visits/{id}", deleteVisit).Methods("DELETE")

	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", noCache(http.FileServer(http.Dir("static/")))))

	r.HandleFunc("/bulk", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/bulk.html")
	}).Methods("GET")
	r.HandleFunc("/corrections/queue", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/corrections.html")
	}).Methods("GET")
	r.HandleFunc("/admin/users", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/users.html")
	}).Methods("GET")
	r.HandleFunc("/admin", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/admin.html")
	}).Methods("GET")
	r.HandleFunc("/admin/features", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/admin_features.html")
	}).Methods("GET")
	r.HandleFunc("/admin/claims", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/admin_claims.html")
	}).Methods("GET")
	r.HandleFunc("/admin/unresolved", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/admin_unresolved.html")
	}).Methods("GET")
	r.HandleFunc("/admin/feature-list", listFeaturesAdmin).Methods("GET")
	r.HandleFunc("/claims", listClaims).Methods("GET")
	r.HandleFunc("/claims/unresolved", listUnresolvedClaims).Methods("GET")
	r.HandleFunc("/falls/{ref}", placeHandler).Methods("GET")
	r.HandleFunc("/account", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/account.html")
	}).Methods("GET")

	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	}).Methods("GET")

	initMailer()

	addr := ":8080"
	if port := os.Getenv("PORT"); port != "" {
		addr = ":" + port
	}
	log.Printf("Server running on http://localhost%s", addr)
	log.Fatal(http.ListenAndServe(addr, r))
}
