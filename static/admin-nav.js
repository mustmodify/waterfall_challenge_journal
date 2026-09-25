// The nav every admin page shares. One file rather than five copies of the
// same links, the way ratings.js is one copy of the rating scale rather than
// three -- see ARCHITECTURE.md on index.html's inline copy of app.css for
// what happens when that discipline slips.
// A second copy of pages.go's banner list, kept in step by hand.
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

function ensureChrome(header) {
  if (!document.querySelector('link[data-admin-chrome]')) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = '/static/admin-chrome.css';
    link.dataset.adminChrome = '1';
    document.head.appendChild(link);
  }
  if (!header || document.querySelector('.admin-hero')) return;

  const [file, alt] = bannerFor(location.pathname);
  const hero = document.createElement('div');
  hero.className = 'admin-hero';
  hero.style.backgroundImage = "url('/static/" + file + "')";
  // Labelled but not announced: the photograph is decoration, so this is
  // deliberately an aria-label rather than alt text on a real <img>.
  hero.setAttribute('role', 'img');
  hero.setAttribute('aria-label', alt);

  const brand = document.createElement('a');
  brand.className = 'brand';
  brand.href = '/';

  const mark = document.createElement('img');
  mark.className = 'mark';
  mark.src = '/static/logo-192.png';
  mark.alt = '';
  mark.width = 57;
  mark.height = 57;
  brand.appendChild(mark);
  brand.appendChild(document.createTextNode('Wanderfall'));

  document.body.insertBefore(hero, document.body.firstChild);
  hero.appendChild(header);
  header.insertBefore(brand, header.firstChild);

  const title = header.querySelector('h1');
  const column = document.querySelector('.wrap');
  if (title && column) {
    title.classList.add('page-title');
    column.insertBefore(title, column.firstChild);
  }

  // Measured, not hardcoded: the admin pages use four different column
  // widths, so one fixed number would misalign the hero on five of them.
  const wrap = document.querySelector('.wrap');
  if (wrap) {
    const w = getComputedStyle(wrap).maxWidth;
    if (w && w !== 'none') header.style.maxWidth = w;
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
