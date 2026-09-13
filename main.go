package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
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

func init() {
	var err error
	dbInfo := fmt.Sprintf("host=localhost user=%s password=%s dbname=%s sslmode=disable",
		DB_USER, DB_PASSWORD, DB_NAME)
	db, err = sql.Open("postgres", dbInfo)
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
	ID                int       `json:"id"`
	Name              string    `json:"name"`
	Kind              string    `json:"kind"`
	FeatureLocationID *int      `json:"feature_location_id"`
	ParkingLocationID *int      `json:"parking_location_id"`
	RtHikeDistance    *string   `json:"rt_hike_distance,omitempty"`
	DifficultyRating  *string   `json:"difficulty_rating,omitempty"`
	Accessibility     *string   `json:"accessibility,omitempty"`
	HeightFt          *int      `json:"height_ft,omitempty"`
	BeautyRating      *int      `json:"beauty_rating,omitempty"`
	PhotoRating       *int      `json:"photo_rating,omitempty"`
	SolitudeRating    *int      `json:"solitude_rating,omitempty"`
	HwncID            *int      `json:"hwnc_id,omitempty"`
	CmcHikeNo         *int      `json:"cmc_hike_no,omitempty"`
	BookPage          *int      `json:"book_page,omitempty"`
	Location          *Location `json:"location,omitempty"`
	LastVisited       *string   `json:"last_visited,omitempty"`
	Challenges        []string  `json:"challenges"`
	Links             []Link    `json:"links"`
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
		SELECT features.id, name, kind, parking_location_id, feature_location_id, rt_hike_distance,
			difficulty_rating, accessibility, height_ft, beauty_rating, photo_rating, solitude_rating,
			hwnc_id, cmc_hike_no, book_page,
			locations.id as location_id, longitude, latitude,
			`+lastVisited+` AS last_visited,
			(SELECT string_agg(challenges.name, ',') FROM goals
				JOIN challenges ON challenges.id = goals.challenge_id
				WHERE goals.feature_id = features.id) AS challenge_names,
			-- rel and url joined per row, rows joined by newline. Neither
			-- character occurs in either column, so the split is unambiguous.
			(SELECT string_agg(coalesce(links.rel, '') || E'\t' || links.url, E'\n'
				ORDER BY links.id)
				FROM links WHERE links.feature_id = features.id) AS link_rows
		FROM features LEFT JOIN locations ON locations.id = features.feature_location_id
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
		var lastVisited sql.NullString
		var challengeNames sql.NullString
		var linkRows sql.NullString

		err := rows.Scan(
			&f.ID,
			&f.Name,
			&f.Kind,
			&f.ParkingLocationID,
			&f.FeatureLocationID,
			&f.RtHikeDistance,
			&f.DifficultyRating,
			&f.Accessibility,
			&f.HeightFt,
			&f.BeautyRating,
			&f.PhotoRating,
			&f.SolitudeRating,
			&f.HwncID,
			&f.CmcHikeNo,
			&f.BookPage,
			&locationID,
			&longitude,
			&latitude,
			&lastVisited,
			&challengeNames,
			&linkRows,
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
	r.HandleFunc("/features/{id}", deleteFeature).Methods("DELETE")

	r.HandleFunc("/signup", signup).Methods("POST")
	r.HandleFunc("/login", login).Methods("POST")
	r.HandleFunc("/logout", logout).Methods("POST")
	r.HandleFunc("/me", me).Methods("GET")

	r.HandleFunc("/auth/request", requestMagicLink).Methods("POST")
	r.HandleFunc("/auth/callback", consumeMagicLink).Methods("GET")
	r.HandleFunc("/challenges", getChallenges).Methods("GET")
	r.HandleFunc("/visits", createVisit).Methods("POST")
	r.HandleFunc("/visits/batch", createVisits).Methods("POST")
	r.HandleFunc("/visits", getVisits).Methods("GET")
	r.HandleFunc("/visits/{id}", deleteVisit).Methods("DELETE")

	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("static/"))))

	r.HandleFunc("/bulk", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/bulk.html")
	}).Methods("GET")
	r.HandleFunc("/account", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/account.html")
	}).Methods("GET")

	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	}).Methods("GET")

	fmt.Println("Server running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}
