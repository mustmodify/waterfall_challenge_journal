// Resolve the theme before first paint so there is no flash of the wrong one.
// Shared by every page; the switch itself only exists on the map.
(function () {
  var stored = null;
  try { stored = localStorage.getItem('wj-theme'); } catch (e) { /* private mode */ }
  var ok = stored === 'light' || stored === 'dark' || stored === 'topo';
  var sys = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  document.documentElement.dataset.theme = ok ? stored : (sys ? 'dark' : 'light');
})();
