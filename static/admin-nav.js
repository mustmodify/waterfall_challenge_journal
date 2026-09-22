// The nav every admin page shares. One file rather than five copies of the
// same links, the way ratings.js is one copy of the rating scale rather than
// three -- see ARCHITECTURE.md on index.html's inline copy of app.css for
// what happens when that discipline slips.
function renderNav(current, correctionsCount) {
  const items = [
    ['map', '/', 'Map'],
    ['admin', '/admin', 'Admin'],
    ['users', '/admin/users', 'Users'],
    ['features', '/admin/features', 'Features'],
    ['review', '/admin/review', 'Review'],
    ['unresolved', '/admin/unresolved', 'Unresolved'],
    ['corrections', '/corrections/queue', 'Corrections'],
    ['account', '/account', 'Account'],
  ];
  const nav = document.getElementById('nav');
  if (!nav) return;
  nav.innerHTML = items.map(([key, href, label]) => {
    const text = key === 'corrections' && correctionsCount != null
      ? label + ' <span class="badge-count">' + correctionsCount + '</span>'
      : label;
    return '<a href="' + href + '"' + (key === current ? ' class="current"' : '') + '>' + text + '</a>';
  }).join('');
}
