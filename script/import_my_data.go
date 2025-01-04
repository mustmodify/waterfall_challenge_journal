package main

import (
	"database/sql"
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"strconv"

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

func main() {
	file, err := os.Open("data/seed.csv")
	if err != nil {
		log.Fatal("Unable to open CSV file:", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		log.Fatal("Unable to parse CSV file:", err)
	}

	for i, record := range records {
		if i == 0 {
			continue // Skip the header row
		}

		// Extract fields from CSV
		name := record[0]
		dateVisited := record[1]
		notes := record[2]
		rtHikeDistance := parseDecimal(record[6])
		difficulty := parseString(record[7])
		beautyRating := parseInt(record[8])
		photoRating := parseInt(record[9])
		solitudeRating := parseInt(record[10])
		hwncID := parseInt(record[11])
		cmcHikeNo := parseInt(record[14])
		bookPage := parseInt(record[15])

		// Insert into goals table
		var goalID int
		err := db.QueryRow(`
			INSERT INTO goals (name, rt_hike_distance, difficulty_rating, beauty_rating, photo_rating, solitude_rating, hwnc_id, cmc_hike_no, book_page)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id
		`, name, rtHikeDistance, difficulty, beautyRating, photoRating, solitudeRating, hwncID, cmcHikeNo, bookPage).Scan(&goalID)
		if err != nil {
			log.Printf("Failed to insert goal %s: %v", name, err)
			continue
		}

		// Insert into visits table (if dateVisited is provided)
		if dateVisited != "" {
			_, err := db.Exec(`
				INSERT INTO visits (goal_id, visited_on) VALUES ($1, $2)
			`, goalID, dateVisited)
			if err != nil {
				log.Printf("Failed to insert visit for goal %s: %v", name, err)
			}
		}

		// Insert into notes table (if notes are provided)
		if notes != "" {
			_, err := db.Exec(`
				INSERT INTO notes (goal_id, text) VALUES ($1, $2)
			`, goalID, notes)
			if err != nil {
				log.Printf("Failed to insert note for goal %s: %v", name, err)
			}
		}
	}

	fmt.Println("CSV import completed successfully!")
}

// Utility functions to parse optional fields
func parseDecimal(value string) *float64 {
	if value == "" {
		return nil
	}
	v, err := strconv.ParseFloat(value, 64)
	if err != nil {
		log.Printf("Failed to parse decimal value %s: %v", value, err)
		return nil
	}
	return &v
}

func parseInt(value string) *int {
	if value == "" {
		return nil
	}
	v, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("Failed to parse integer value %s: %v", value, err)
		return nil
	}
	return &v
}

func parseString(value string) *string {
	if value == "" {
		return nil
	}
	return &value
}

