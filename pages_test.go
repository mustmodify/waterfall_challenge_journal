package main

import "testing"

func ptrS(s string) *string { return &s }
func ptrI(i int) *int       { return &i }
func ptrF(f float64) *float64 { return &f }

func baseFeature() *pageFeature {
	return &pageFeature{Name: "Somewhere Falls", Kind: "waterfall",
		Latitude: ptrF(35.1), Longitude: ptrF(-82.8)}
}

func TestIndexingGate(t *testing.T) {
	cases := []struct {
		name string
		want bool
		with func(*pageFeature)
	}{
		{"nothing but a name and a pin", false, func(f *pageFeature) {}},
		{"no coordinate at all", false, func(f *pageFeature) { f.Latitude = nil }},
		{"deprecated", false, func(f *pageFeature) {
			f.Deprecated = ptrS("destroyed")
			f.Notes = []FeatureNote{{Text: "washed out in 2024"}}
		}},
		{"somebody's unsorted trip log", false, func(f *pageFeature) {
			f.Name = "Waterfall #3 (04-14-2022)"
			f.HikeDistance = ptrS("2.0")
			f.Difficulty = ptrS("Moderate")
			f.HeightFt = ptrI(30)
		}},
		{"prose is enough on its own", true, func(f *pageFeature) {
			f.Notes = []FeatureNote{{Text: "The ford is knee deep after rain."}}
		}},
		{"the generic set says nothing particular", false, func(f *pageFeature) {
			f.Difficulty = ptrS("Moderate")
			f.HeightFt = ptrI(40)
			f.HikeDistance = ptrS("1.4")
			f.Beauty = ptrI(6)
		}},
		{"a fall people already search for", true, func(f *pageFeature) {
			f.Beauty = ptrI(9)
		}},
		{"a trailhead is particular to this one", true, func(f *pageFeature) {
			f.ParkingLat = ptrF(35.2)
		}},
		{"a route somebody walked", true, func(f *pageFeature) {
			f.Routes = []routeRating{{Source: "dwhike", Miles: 3.5, GainFt: 525}}
		}},
		{"sources disagreeing is worth reading", true, func(f *pageFeature) {
			f.Confidence = ptrS("disputed")
		}},
		{"one source and nothing else is not", false, func(f *pageFeature) {
			f.Confidence = ptrS("single source")
			f.Difficulty = ptrS("Easy")
		}},
		{"a name people search by counts", true, func(f *pageFeature) {
			f.Aliases = []string{"Styer Mill Falls"}
			f.Difficulty = ptrS("Easy")
			f.HeightFt = ptrI(15)
		}},
	}
	for _, c := range cases {
		f := baseFeature()
		c.with(f)
		if got := indexable(f); got != c.want {
			t.Errorf("%s: indexable = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestBandsSpeakInWordsNotScores(t *testing.T) {
	cases := []struct {
		axis  string
		score int
		want  string
	}{
		{"beauty", 10, "unforgettable"},
		{"beauty", 9, "unforgettable"},
		{"beauty", 7, "beautiful"},
		{"beauty", 5, "fine"},
		{"beauty", 4, "disappointing"},
		{"photo", 10, "stunning"},
		{"photo", 9, "nice!"},
		{"solitude", 10, "pristine"},
		{"solitude", 1, "crowded"},
	}
	for _, c := range cases {
		if got := band(c.axis, &c.score); got != c.want {
			t.Errorf("%s %d = %q, want %q", c.axis, c.score, got, c.want)
		}
	}
	if got := band("beauty", nil); got != "" {
		t.Errorf("unrated read as %q", got)
	}
}
