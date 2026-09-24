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

// The header is lifted out of the page's 900px column and into a full-bleed
// hero, so the photograph reads as the top of the page rather than as an
// illustration boxed in beside the title. The nav's appearance moves with it:
// it had been living in nine copies of an inline style block, which is how it
// ends up looking different depending on which page you came from.
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
  // The photograph is decoration here -- the title carries the meaning -- so
  // it is labelled but not announced as the page's subject.
  hero.setAttribute('role', 'img');
  hero.setAttribute('aria-label', alt);

  // The pin and the wordmark together, the way the public pages do it. The
  // hero says which site you are on; the page says which page you are on, and
  // those are different jobs that were sharing one line.
  const brand = document.createElement('a');
  brand.className = 'brand';
  brand.href = '/';

  const mark = document.createElement('img');
  mark.className = 'mark';
  mark.src = '/static/logo-192.png';
  mark.alt = '';
  mark.width = 38;
  mark.height = 38;
  brand.appendChild(mark);
  brand.appendChild(document.createTextNode('Wanderfall'));

  document.body.insertBefore(hero, document.body.firstChild);
  hero.appendChild(header);
  header.insertBefore(brand, header.firstChild);

  // The page's own name is one level of breadcrumb, so it belongs at the top
  // of the content rather than competing with the wordmark over a photograph.
  // If it ever grows a second level, this is where the trail goes.
  const title = header.querySelector('h1');
  const column = document.querySelector('.wrap');
  if (title && column) {
    title.classList.add('page-title');
    column.insertBefore(title, column.firstChild);
  }

  // The nine pages use four different column widths -- 820, 880, 900, 1000 --
  // so a hero with one hardcoded width would sit a few pixels off the content
  // on five of them, which is exactly the kind of small wrongness that reads
  // as sloppy. Take the width from whatever this page actually uses.
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
