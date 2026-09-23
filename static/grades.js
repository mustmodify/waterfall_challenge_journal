// Confidence scores as letter grades.
//
// The 0-4.3 scale is a GPA, so it already has letters -- each grade's
// canonical GPA value is the bottom of its band, and a score sits in the band
// of the highest value it reaches. 3.0 is a B, 3.29 is still a B, 3.3 is a
// B+. Nothing here is a wanderfall invention; it is the same table a
// transcript uses.
//
// One file rather than a copy per admin page, the same reason admin-nav.js
// is one file -- see ARCHITECTURE.md on what happens when that slips.
const GRADE_BANDS = [
  [4.3, 'A+'],
  [4.0, 'A'],
  [3.7, 'A-'],
  [3.3, 'B+'],
  [3.0, 'B'],
  [2.7, 'B-'],
  [2.3, 'C+'],
  [2.0, 'C'],
  [1.7, 'C-'],
  [1.3, 'D+'],
  [1.0, 'D'],
  [0.7, 'D-'],
  [0.0, 'F'],
];

// The letter for a score, or null when there is no score at all -- which is
// "nobody has graded this", a different thing from grading it an F.
function letterGrade(score) {
  if (score == null || isNaN(score)) return null;
  const band = GRADE_BANDS.find(([min]) => score >= min);
  return band ? band[1] : 'F';
}

// Which end of the alphabet a grade sits at, for colouring. Deliberately
// coarse: the point is "is this fine, or does it want me", not a gradient.
function gradeClass(score) {
  const letter = letterGrade(score);
  if (letter == null) return 'g-none';
  return 'g-' + letter[0].toLowerCase();
}
