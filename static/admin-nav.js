// The nav every admin page shares. One file rather than five copies of the
// same links, the way ratings.js is one copy of the rating scale rather than
// three -- see ARCHITECTURE.md on index.html's inline copy of app.css for
// what happens when that discipline slips.
// The same six photographs the public pages rotate through, chosen from the
// path so a page keeps its banner between visits. Kept in step with
// pages.go's list by hand -- there are six of them and they change rarely.
const ADMIN_BANNERS = [
  ['banner-frozen-falls.jpg', 'A frozen waterfall at sunrise, mist glowing gold above the ice'],
  ['banner-creek.jpg', 'A side cascade dropping into a creek running high'],
  ['banner-blue-ridges.jpg', 'Layered blue ridges at dawn under a pink sky'],
  ['banner-red-sun.jpg', 'A red sun rising over ridge lines with fog in the valleys'],
  ['banner-cloud-light.jpg', 'Late light breaking through tall clouds over green ridges'],
  ['banner-branch-sunset.jpg', 'Sunset over wooded hills, framed by an overhanging branch'],
];

function bannerFor(path) {
  let h = 2166136261;                       // FNV-1a, to match the server's
  for (let i = 0; i < path.length; i++) {
    h ^= path.charCodeAt(i);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return ADMIN_BANNERS[h % ADMIN_BANNERS.length];
}

// The nav's appearance lived in nine copies of an inline style block, which
// is how it ends up looking different depending on which page you came from.
function ensureChrome(header) {
  if (!document.querySelector('link[data-admin-chrome]')) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = '/static/admin-chrome.css';
    link.dataset.adminChrome = '1';
    document.head.appendChild(link);
  }
  if (header && !document.querySelector('.admin-banner')) {
    const [file, alt] = bannerFor(location.pathname);
    const banner = document.createElement('div');
    banner.className = 'admin-banner';
    banner.setAttribute('role', 'img');
    banner.setAttribute('aria-label', alt);
    banner.style.backgroundImage = "url('/static/" + file + "')";
    header.parentNode.insertBefore(banner, header);
  }
}

function renderNav(current, correctionsCount) {
  const items = [
    ['map', '/', 'Map'],
    ['admin', '/admin', 'Admin'],
    ['users', '/admin/users', 'Users'],
    ['features', '/admin/features', 'Features'],
    ['review', '/admin/review', 'Review'],
    ['confusion', '/admin/confusion_sets', 'Confusion'],
    ['unresolved', '/admin/unresolved', 'Unresolved'],
    ['corrections', '/corrections/queue', 'Corrections'],
    ['account', '/account', 'Account'],
  ];
  const nav = document.getElementById('nav');
  if (!nav) return;
  ensureChrome(nav.closest('header'));
  nav.innerHTML = items.map(([key, href, label]) => {
    const text = key === 'corrections' && correctionsCount != null
      ? label + ' <span class="badge-count">' + correctionsCount + '</span>'
      : label;
    return '<a href="' + href + '"' + (key === current ? ' class="current"' : '') + '>' + text + '</a>';
  }).join('');
}
