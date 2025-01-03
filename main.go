package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

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

type Goal struct {
    ID                int     `json:"id"`
    Name              string  `json:"name"`
    FeatureLocationID *int     `json:"feature_location_id"`
    ParkingLocationID *int    `json:"parking_location_id"`
    RtHikeDistance    *float64`json:"rt_hike_distance,omitempty"`
    DifficultyRating  *string `json:"difficulty_rating,omitempty"`
    BeautyRating      *int    `json:"beauty_rating,omitempty"`
    PhotoRating       *int    `json:"photo_rating,omitempty"`
    SolitudeRating    *int    `json:"solitude_rating,omitempty"`
    HwncID            *int    `json:"hwnc_id,omitempty"`
    CmcHikeNo         *int    `json:"cmc_hike_no,omitempty"`
    BookPage          *int    `json:"book_page,omitempty"`
}

type Note struct {
    ID        int    `json:"id"`
    GoalID    int    `json:"goal_id"`
    CreatedAt string `json:"created_at"`
    UpdatedAt string `json:"updated_at"`
    Text      string `json:"text"`
}

type Location struct {
	ID        int     `json:"id"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Visit struct {
    ID        int       `json:"id"`
    GoalID    int       `json:"goal_id"`
    VisitedOn string    `json:"visited_on"`
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

// Create a new goal
func createGoal(w http.ResponseWriter, r *http.Request) {
	var goal Goal
	json.NewDecoder(r.Body).Decode(&goal)
	sqlStatement := `INSERT INTO goals (name, parking_location_id, feature_location_id) VALUES ($1, $2, $3) RETURNING id`
	err := db.QueryRow(sqlStatement, goal.Name, goal.ParkingLocationID, goal.FeatureLocationID).Scan(&goal.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(goal)
}

func getGoals(w http.ResponseWriter, r *http.Request) {
    rows, err := db.Query(`
        SELECT id, name, parking_location_id, feature_location_id, rt_hike_distance,
               difficulty_rating, beauty_rating, photo_rating, solitude_rating, hwnc_id, cmc_hike_no, book_page
        FROM goals
    `)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    goals := []Goal{}
    for rows.Next() {
        var goal Goal
        err := rows.Scan(
            &goal.ID,
            &goal.Name,
            &goal.ParkingLocationID,
            &goal.FeatureLocationID,
            &goal.RtHikeDistance,
            &goal.DifficultyRating,
            &goal.BeautyRating,
            &goal.PhotoRating,
            &goal.SolitudeRating,
            &goal.HwncID,
            &goal.CmcHikeNo,
            &goal.BookPage,
        )
        if err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        goals = append(goals, goal)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(goals)
}

// Update a goal
func updateGoal(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var goal Goal
	json.NewDecoder(r.Body).Decode(&goal)

	sqlStatement := `UPDATE goals SET name=$1, parking_location_id=$2, feature_location_id=$3 WHERE id=$4`
	_, err := db.Exec(sqlStatement, goal.Name, goal.ParkingLocationID, goal.FeatureLocationID, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Delete a goal
func deleteGoal(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	sqlStatement := `DELETE FROM goals WHERE id=$1`
	_, err := db.Exec(sqlStatement, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func createVisit(w http.ResponseWriter, r *http.Request) {
    var visit Visit
    json.NewDecoder(r.Body).Decode(&visit)

    sqlStatement := `INSERT INTO visits (goal_id) VALUES ($1) RETURNING id, visit_time`
    err := db.QueryRow(sqlStatement, visit.GoalID).Scan(&visit.ID, &visit.VisitedOn)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(visit)
}

func getVisitsForGoal(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    goalID := vars["id"]

    rows, err := db.Query("SELECT id, goal_id, visit_time FROM visits WHERE goal_id = $1", goalID)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    visits := []Visit{}
    for rows.Next() {
        var visit Visit
        err := rows.Scan(&visit.ID, &visit.GoalID, &visit.VisitedOn)
        if err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        visits = append(visits, visit)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(visits)
}

func main() {
	r := mux.NewRouter()

	// Routes
	r.HandleFunc("/locations", createLocation).Methods("POST")
	r.HandleFunc("/locations", getLocations).Methods("GET")
	r.HandleFunc("/locations/{id}", updateLocation).Methods("PUT")
	r.HandleFunc("/locations/{id}", deleteLocation).Methods("DELETE")

        r.HandleFunc("/goals", createGoal).Methods("POST")
        r.HandleFunc("/goals", getGoals).Methods("GET")
        r.HandleFunc("/goals/{id}", updateGoal).Methods("PUT")
        r.HandleFunc("/goals/{id}", deleteGoal).Methods("DELETE")

	r.HandleFunc("/visits", createVisit).Methods("POST")
        r.HandleFunc("/goals/{id}/visits", getVisitsForGoal).Methods("GET")

        r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("static/"))))

        r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
            http.ServeFile(w, r, "./static/index.html")
        }).Methods("GET")


	fmt.Println("Server running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}

