package main

import (
	"encoding/xml"
	"fmt"
	"log"
	"net/http"
	"time"
)

// robots.txt and sitemap.xml, both of which were 404 until now.
//
// The sitemap is the whole point of this: the site is crawlable and always was
// -- no noindex, no blocked paths, nine thousand words of text on the map page
// -- it simply has never been discovered. Nothing links to it from anywhere.
// A sitemap plus a Search Console submission is what fixes that, and only one
// of those two is something code can do.
func robotsHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprint(w, `User-agent: *
Allow: /
Disallow: /account
Disallow: /bulk
Disallow: /corrections
Disallow: /users
Disallow: /admin/
Disallow: /auth/

Sitemap: https://wanderfall.app/sitemap.xml
`)
}

func sitemapHandler(w http.ResponseWriter, r *http.Request) {
	areas, err := areasWithCounts()
	if err != nil {
		log.Printf("sitemap: %v", err)
		http.Error(w, "unavailable", http.StatusInternalServerError)
		return
	}

	today := time.Now().UTC().Format("2006-01-02")
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	fmt.Fprint(w, xml.Header)
	fmt.Fprint(w, "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n")
	entry := func(path, priority string) {
		fmt.Fprintf(w, "  <url><loc>https://wanderfall.app%s</loc>"+
			"<lastmod>%s</lastmod><priority>%s</priority></url>\n",
			path, today, priority)
	}
	entry("/", "1.0")
	entry("/areas", "0.8")
	for _, a := range areas {
		// An area of one or two has no page to link to.
		if a.Count >= areaMinimum {
			entry("/areas/"+a.Slug, "0.6")
		}
	}
	fmt.Fprint(w, "</urlset>\n")
}
