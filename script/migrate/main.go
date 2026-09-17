// Applies db/migrations in order, once each, recording what it has run, then
// dumps the resulting schema to db/schema.sql -- the way Rails' db:migrate
// leaves schema.rb updated, so nobody has to remember DEPLOY.md's pg_dump
// command by hand after adding a table.
//
// The migrations were hand-applied with psql for the whole of development,
// which works when one person holds the whole sequence in their head and fails
// the first time a second database exists. A fresh production database has to
// receive 47 files in order with nothing skipped and nothing run twice.
//
//	go run ./script/migrate            apply anything unapplied, then dump schema.sql
//	go run ./script/migrate -baseline  record every file as applied, run none
//	go run ./script/migrate -status    list what has run and what has not
//
// -baseline is for the development database, which already has all 53 applied
// by hand: it writes the ledger without touching the schema, and does not
// dump schema.sql either -- baselining doesn't change what the database looks
// like, only what the ledger says about it.
//
// Requires pg_dump on PATH, matching the server the DATABASE_URL (or the
// default connection) points at. A dump failure is a warning, not a fatal
// error: the migrations already committed, and a stale schema.sql is a
// smaller problem than pretending the migration didn't happen.
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"

	_ "github.com/lib/pq"
)

const dir = "db/migrations"
const schemaFile = "db/schema.sql"

func main() {
	baseline := flag.Bool("baseline", false, "record every migration as applied without running it")
	status := flag.Bool("status", false, "show which migrations have run")
	flag.Parse()

	url := os.Getenv("DATABASE_URL")
	if url == "" {
		url = "host=localhost user=johnathonwright password=postgres dbname=wc_journey_db sslmode=disable"
	}
	db, err := sql.Open("postgres", url)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if err := db.Ping(); err != nil {
		log.Fatalf("cannot reach the database: %v", err)
	}

	if _, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename   text PRIMARY KEY,
			applied_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
		)`); err != nil {
		log.Fatal(err)
	}

	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		log.Fatal(err)
	}
	sort.Strings(files)
	if len(files) == 0 {
		log.Fatalf("no migrations found in %s -- run this from the repository root", dir)
	}

	applied := map[string]bool{}
	rows, err := db.Query(`SELECT filename FROM schema_migrations`)
	if err != nil {
		log.Fatal(err)
	}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			log.Fatal(err)
		}
		applied[name] = true
	}
	rows.Close()

	// A database loaded from db/schema.sql already contains everything the
	// numbered files would do, and an empty ledger would send us to replay them
	// from 001 against tables that exist. That fails halfway through with
	// "relation users already exists", which describes the symptom and not the
	// problem. Say the problem.
	if len(applied) == 0 && !*baseline && !*status {
		var exists bool
		if err := db.QueryRow(`SELECT to_regclass('public.features') IS NOT NULL`).
			Scan(&exists); err != nil {
			log.Fatal(err)
		}
		if exists {
			log.Fatalf("this database has tables but no migration ledger, so it was " +
				"loaded from db/schema.sql rather than built by these files. Run " +
				"`migrate -baseline` once to record them as applied.")
		}
	}

	if *status {
		for _, path := range files {
			name := filepath.Base(path)
			mark := "  "
			if applied[name] {
				mark = "ok"
			}
			fmt.Printf("%s  %s\n", mark, name)
		}
		return
	}

	ran := 0
	for _, path := range files {
		name := filepath.Base(path)
		if applied[name] {
			continue
		}
		if *baseline {
			if _, err := db.Exec(`INSERT INTO schema_migrations (filename) VALUES ($1)`, name); err != nil {
				log.Fatal(err)
			}
			ran++
			continue
		}

		body, err := os.ReadFile(path)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("applying %s\n", name)

		// Several migrations open their own transaction. Running them inside
		// another one turns the inner COMMIT into a warning and leaves the
		// ledger insert outside the work it describes, so each file is handed
		// to the server whole and the ledger is written immediately after.
		//
		// Some older migrations record themselves as part of their own
		// transaction (a convention that predates this tool always doing it).
		// ON CONFLICT DO NOTHING covers both: it is a no-op when the file
		// already recorded itself, and the only write when it did not.
		if _, err := db.Exec(string(body)); err != nil {
			log.Fatalf("%s failed: %v", name, err)
		}
		if _, err := db.Exec(`INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT (filename) DO NOTHING`, name); err != nil {
			log.Fatalf("%s ran but was not recorded: %v", name, err)
		}
		ran++
	}

	switch {
	case *baseline:
		fmt.Printf("recorded %d migration(s) as applied\n", ran)
	case ran == 0:
		fmt.Println("nothing to apply")
	default:
		fmt.Printf("applied %d migration(s)\n", ran)
		dumpSchema(url)
	}
}

// dumpSchema keeps db/schema.sql the way Rails keeps schema.rb: a snapshot
// nobody has to remember to regenerate by hand, written the moment a
// migration actually changes the database. DEPLOY.md documents the same
// pg_dump command for exactly this reason -- this just runs it automatically
// instead of trusting it gets run.
func dumpSchema(url string) {
	out, err := exec.Command("pg_dump", "--dbname="+url, "--schema-only", "--no-owner", "--no-privileges").Output()
	if err != nil {
		msg := err.Error()
		if ee, ok := err.(*exec.ExitError); ok {
			msg = string(ee.Stderr)
		}
		log.Printf("warning: could not update db/schema.sql: %s", msg)
		return
	}
	if err := os.WriteFile(schemaFile, out, 0644); err != nil {
		log.Printf("warning: could not write %s: %v", schemaFile, err)
		return
	}
	fmt.Printf("updated %s\n", schemaFile)
}
