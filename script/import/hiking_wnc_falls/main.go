package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sort"
	"strconv"

	_ "github.com/lib/pq"
)

const (
	DB_USER     = "johnathonwright"
	DB_PASSWORD = "postgres"
	DB_NAME     = "wc_journey_db"
)

var db *sql.DB

type Location struct {
	Latitude  *float64 `json:"Latitude,omitempty"`
	Longitude *float64 `json:"Longitude,omitempty"`
	RawData   string   `json:"-"` // Store invalid GPS data as a string
}

type Fall struct {
	Name          string      `json:"Name"`
	Beauty        string      `json:"Beauty,omitempty"`
	PhotoRating   string      `json:"Photo Rating,omitempty"`
	Solitude      string      `json:"Solitude,omitempty"`
	GPS           *Location   `json:"GPS"`
	Height        string      `json:"Height,omitempty"`
	Distance      MixedString `json:"Distance,omitempty"` // Use custom type
	Accessibility string      `json:"Accessibility,omitempty"`
	Number        string      `json:"Number,omitempty"`
	URL           string      `json:"url"`
	NewFall       bool        `json:"new_fall,omitempty"`
}

// Custom type to handle mixed string/number fields
type MixedString string

func (l *Location) UnmarshalJSON(data []byte) error {
	// Attempt to unmarshal into a struct
	type Alias Location
	var loc Alias
	if err := json.Unmarshal(data, &loc); err == nil {
		*l = Location(loc)
		return nil
	}

	// Attempt to unmarshal as a string
	var raw string
	if err := json.Unmarshal(data, &raw); err == nil {
		l.RawData = raw
		return nil
	}

	// If both fail, return an error
	return fmt.Errorf("invalid GPS data: %s", string(data))
}

func (ms *MixedString) UnmarshalJSON(data []byte) error {
	// Try unmarshalling as string
	var s string
	if err := json.Unmarshal(data, &s); err == nil {
		*ms = MixedString(s)
		return nil
	}

	// Try unmarshalling as number
	var n float64
	if err := json.Unmarshal(data, &n); err == nil {
		*ms = MixedString(fmt.Sprintf("%.2f", n))
		return nil
	}

	// Return error if neither works
	return fmt.Errorf("MixedString: invalid data %s", string(data))
}

func initDB() {
	var err error
	connStr := fmt.Sprintf("host=localhost user=%s password=%s dbname=%s sslmode=disable",
		DB_USER, DB_PASSWORD, DB_NAME)
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}

	if err = db.Ping(); err != nil {
		log.Fatal(err)
	}
	fmt.Println("Connected to the database!")
}

func parseToInt(value string) *int {
	// Return nil for empty strings
	if value == "" {
		return nil
	}
	// Parse string to integer
	intValue, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("Failed to parse integer: %s, error: %v", value, err)
		return nil
	}
	return &intValue
}

func importFalls(filename string) {
	// Open the JSON file
	file, err := os.Open(filename)
	if err != nil {
		log.Fatalf("Failed to open JSON file: %v", err)
	}
	defer file.Close()

	// Create a JSON decoder
	decoder := json.NewDecoder(file)

	// Read the opening bracket of the JSON array
	tok, err := decoder.Token()
	if err != nil || tok != json.Delim('[') {
		log.Fatalf("Invalid JSON format: expected an array")
	}

	var unmatchedFalls []Fall

	// Iterate over each JSON object in the array
	for decoder.More() {
		var fall Fall
		if err := decoder.Decode(&fall); err != nil {
			log.Printf("Error decoding JSON record: %v", err)
			continue // Skip this record and move to the next
		}

		// Convert fields
		beauty := parseToInt(fall.Beauty)
		photoRating := parseToInt(fall.PhotoRating)
		solitude := parseToInt(fall.Solitude)

		var existingID int
		err = db.QueryRow("SELECT id FROM goals WHERE name = $1", fall.Name).Scan(&existingID)

		if err != nil && err != sql.ErrNoRows {
			log.Printf("Error querying for fall %s: %v", fall.Name, err)
			continue
		}

		if err == sql.ErrNoRows {
			// Add new fall only if `new_fall` is true
			if fall.NewFall {
				var locationID sql.NullInt64

				// Insert into locations if GPS exists
				if fall.GPS != nil && fall.GPS.Latitude != nil && fall.GPS.Longitude != nil {
					log.Printf("Inserted location for fall %s", fall.Name)

					err := db.QueryRow(`
						INSERT INTO locations (latitude, longitude)
						VALUES ($1, $2) RETURNING id
					`, *fall.GPS.Latitude, *fall.GPS.Longitude).Scan(&locationID)

					if err != nil {
						log.Printf("Error inserting location for fall %s: %v", fall.Name, err)
						continue
					}
				} else if fall.GPS != nil && fall.GPS.RawData != "" {
					// Log invalid GPS data for manual correction
					log.Printf("Invalid GPS data for fall %s: %s", fall.Name, fall.GPS.RawData)
				}

				// Insert into goals
				_, err := db.Exec(`
					INSERT INTO goals (name, rt_hike_distance, beauty_rating, photo_rating, solitude_rating, feature_location_id)
					VALUES ($1, $2, $3, $4, $5, $6)`,
					fall.Name, fall.Distance, beauty, photoRating, solitude, locationID)
				if err != nil {
					log.Printf("Error inserting fall %s: %v", fall.Name, err)
					continue
				}
				fmt.Printf("Added new fall: %s\n", fall.Name)
			} else {
				unmatchedFalls = append(unmatchedFalls, fall)
			}
		} else {
			// Update existing record
			_, err := db.Exec(`
				UPDATE goals
				SET rt_hike_distance = $2,
					beauty_rating = $3,
					photo_rating = $4,
					solitude_rating = $5
				WHERE id = $1`,
				existingID, fall.Distance, beauty, photoRating, solitude)
			if err != nil {
				log.Printf("Error updating fall %s: %v", fall.Name, err)
				continue
			}

			// Check if feature_location_id is already set
			var locationID sql.NullInt64
			err = db.QueryRow("SELECT feature_location_id FROM goals WHERE id = $1", existingID).Scan(&locationID)
			if err != nil {
				log.Printf("Error checking feature_location_id for fall %s: %v", fall.Name, err)
				continue
			}

			// Insert location if not set and GPS data is valid
			if !locationID.Valid && fall.GPS != nil && fall.GPS.Latitude != nil && fall.GPS.Longitude != nil {
				err := db.QueryRow(`
					INSERT INTO locations (latitude, longitude)
					VALUES ($1, $2) RETURNING id
				`, *fall.GPS.Latitude, *fall.GPS.Longitude).Scan(&locationID)
				if err != nil {
					log.Printf("Error inserting location for existing fall %s: %v", fall.Name, err)
					continue
				}

				// Update feature_location_id in goals
				_, err = db.Exec(`
					UPDATE goals
					SET feature_location_id = $1
					WHERE id = $2`,
					locationID, existingID)
				if err != nil {
					log.Printf("Error updating feature_location_id for fall %s: %v", fall.Name, err)
					continue
				}
				fmt.Printf("Updated feature_location_id for fall: %s\n", fall.Name)
			}
			fmt.Printf("Updated existing fall: %s\n", fall.Name)
		}
	}

	// Sort unmatched falls by name
	sort.Slice(unmatchedFalls, func(i, j int) bool {
		return unmatchedFalls[i].Name < unmatchedFalls[j].Name
	})

	// Print unmatched falls
	fmt.Println("Unmatched falls:")
	for _, fall := range unmatchedFalls {
		fmt.Printf("- %s (%s)\n", fall.Name, fall.URL)
	}
}

func main() {
	initDB()
	defer db.Close()

	// Path to the JSON file
	jsonFile := "data/hiking_wnc_falls.json"

	// Import falls from JSON
	importFalls(jsonFile)
}
