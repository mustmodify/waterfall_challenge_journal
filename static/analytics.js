// Google Analytics config. The loader itself is a separate async <script> tag
// on each page; this is only the initialisation that would otherwise be copied
// inline four times, drifting the moment the property id changes.
window.dataLayer = window.dataLayer || [];
function gtag() { dataLayer.push(arguments); }
gtag('js', new Date());

// Our own visits would otherwise be the busiest user on the site. ?internal=1
// marks this browser for good, ?internal=0 clears it, and signing in as an
// admin sets it on its own -- see wjMarkInternal below.
//
// This only labels the traffic. Dropping it needs a data filter on
// traffic_type = internal in the GA4 property; without one these hits are
// counted like any other, just tagged.
(function () {
  let internal = false;
  try {
    const asked = new URLSearchParams(location.search).get('internal');
    if (asked === '1') localStorage.setItem('wj-internal', '1');
    if (asked === '0') localStorage.removeItem('wj-internal');
    internal = localStorage.getItem('wj-internal') === '1';
  } catch (e) { /* private mode */ }

  window.wjInternal = internal;
  gtag('config', 'G-Z01BFBJM7V', internal ? { traffic_type: 'internal' } : {});
})();

// Called once the page knows who is signed in. The flag survives signing out,
// which is the point: testing signed-out is still our traffic.
window.wjMarkInternal = function (isAdmin) {
  if (!isAdmin || window.wjInternal) return;
  try { localStorage.setItem('wj-internal', '1'); } catch (e) { /* private mode */ }
  window.wjInternal = true;
  gtag('config', 'G-Z01BFBJM7V', { traffic_type: 'internal' });
};
