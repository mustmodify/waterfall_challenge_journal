package main

import "testing"

func TestLimiterBurstThenRefill(t *testing.T) {
	l := newLimiter(5, 5)
	for i := 0; i < 5; i++ {
		if !l.allow("1.2.3.4") {
			t.Fatalf("request %d refused inside the burst", i+1)
		}
	}
	if l.allow("1.2.3.4") {
		t.Fatal("sixth request allowed")
	}
	if !l.allow("5.6.7.8") {
		t.Fatal("a different address was refused")
	}
}
