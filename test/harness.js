// Executes index.html's inline scripts against stubs with the real 900-feature
// payload, then drives the pin/heat rule through each filter combination.
const fs = require('fs'), vm = require('vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
const FEATURES = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
const blocks = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);

let pins = 0, added = 0, icons = [], clusterOpts = null, mapOpts = {}, made = [], groupCount = 0, perGroup = [], panes = [], plainGroups = 0, plainAdded = 0;
const els = new Map();
const el = (id) => {
  if (!els.has(id)) els.set(id, { id, hidden: false, value: '', innerHTML: '', textContent: '',
    dataset: {}, style: {}, classList: { add(){}, remove(){}, toggle(){}, contains: () => false }, setAttribute(){}, offsetWidth: 0,
    getAttribute: () => null, addEventListener(){}, querySelectorAll: () => [],
    appendChild(){}, insertBefore(){}, focus(){}, closest: () => null,
    querySelector: () => ({ classList:{add(){},remove(){}}, offsetWidth: 0 }) });
  return els.get(id);
};
const bounds = { isValid: () => true, extend(){}, contains: () => true,
  getCenter: () => ({ lat: 35.4, lng: -82.8 }) };
const stub = () => ({ addTo(){ return this; }, setUrl(){}, remove(){}, bindTooltip(){ return this; }, on(){ return this; } });
const L = {
  map: (id, opts) => { mapOpts = opts || {}; return map; },
  tileLayer: () => stub(),
  marker: () => { pins++; const m = stub(); made.push(m); return m; },
  divIcon: (o) => { icons.push(o.html); return o; },
  markerClusterGroup: (o) => { clusterOpts = o; groupCount++; return {
    // MarkerClusterGroup.onAdd throws this if the map has no maxZoom
    addTo(){ if (mapOpts.maxZoom === undefined) throw new Error('Map has no maxZoom specified'); return this; }, clearLayers(){ added = 0; }, on(){ return this; },
    addLayers(l){ added += l.length; perGroup.push(l.length); }, hasLayer: () => true, zoomToShowLayer(m, cb){ cb(); } }; },
  latLngBounds: () => bounds,
  layerGroup: () => { plainGroups++; return { addTo(){ return this; }, clearLayers(){},
    addLayer(){ plainAdded++; }, hasLayer: () => true }; },
  control: { zoom: () => ({ addTo(){} }) },
};
const Z = Number(process.argv[4] || 8);
const map = { setView(){ return map; }, removeLayer(){}, on(){}, getZoom: () => Z,
  setZoom(){}, getCenter: () => ({ lat: 35.4, lng: -82.8 }),
  getBounds: () => bounds, fitBounds(){}, flyTo(){}, getMaxZoom: () => 20,
  createPane: (n) => { panes.push(n); return { style: {} }; }, getPane: () => ({ style: {} }),
  latLngToContainerPoint: ([lat, lon]) => {
    const n = 256 * Math.pow(2, Z), la = lat * Math.PI / 180;
    return { x: (lon + 180) / 360 * n,
             y: (1 - Math.log(Math.tan(la) + 1 / Math.cos(la)) / Math.PI) / 2 * n };
  } };

const sandbox = { L, console, setTimeout: () => 0, clearTimeout: () => {}, URLSearchParams,
  window: { matchMedia: () => ({ matches: false, addEventListener(){} }), addEventListener(){},
    location: { search: '', hash: '' } },
  self: null,
  localStorage: { getItem: () => null, setItem(){} },
  getComputedStyle: () => ({ getPropertyValue: (n) => (({'--c-visited':'#5e6462','--c-azure':'#007fff','--c-tower':'#8a6a4f','--c-sel':'#16302a','--r1':'#5e1687','--r2':'#7d35a6','--r3':'#9d63c2','--r4':'#bf96da','--r5':'#e0cdee'})[n] || '#000') }),
  fetch: (u) => Promise.resolve({ ok: true,
    json: () => Promise.resolve(u === '/features' ? FEATURES : []), text: () => Promise.resolve('') }),
  document: { documentElement: { dataset: {} }, getElementById: el,
    querySelector: () => el('generic'),
    createElement: () => ({ classList: { add(){}, contains: () => false },
      addEventListener(){}, appendChild(){}, insertBefore(){}, style: {}, dataset: {} }),
    querySelectorAll: (s) => (s.includes('theme-set') || s.includes('tile')) ? [el('t1'), el('t2'), el('t3')] : [],
    addEventListener(){} },
};
vm.createContext(sandbox);
// index.html expects the globals ratings.js defines
vm.runInContext(fs.readFileSync('static/ratings.js','utf8'), sandbox, {filename:'ratings.js'});
// in a browser window.foo is also a bare global; the sandbox's window is not
Object.keys(sandbox.window).forEach((k) => { if (!(k in sandbox)) sandbox[k] = sandbox.window[k]; });
blocks.forEach((b, i) => {
  const src = i === blocks.length - 1
    ? b + '\n;globalThis.__t = { state, renderMarkers, visibleGoals, colorOf: markerColor, openDrawer };'
    : b;
  try { vm.runInContext(src, sandbox, { filename: `block${i}` }); }
  catch (e) { console.error(`block ${i} THREW: ${e.constructor.name}: ${e.message}\n${e.stack}`); process.exit(1); }
});

setTimeout(() => {
  const t = sandbox.__t;
  if (!t || !t.state.features.length) { console.error('features never loaded'); process.exit(1); }
  console.log('loaded %d features, no exception during init\n', t.state.features.length);
  const run = (label, mut) => {
    Object.assign(t.state, { showKinds: new Set(['waterfall','tower']), visited: 'mute', challenge: 'all', area: '', ratings: new Set() });
    mut(t.state);
    pins = 0; added = 0; icons = []; made = []; perGroup = []; plainAdded = 0;
    t.renderMarkers(false);
    const n = t.visibleGoals().length;
    console.log('%-34s %4d shown -> %s', label, n,
      `clustered ${added} in ${perGroup.length} group(s)${perGroup.length?' ['+perGroup.join('+')+']':''}, ${plainAdded} unclustered`,
    '| card says:', el('showing').innerHTML);
  };
  run('Everything, no filters', () => {});
  run('Challenge: WC100', (s) => { s.challenge = 'WC100'; });
  run('Area: Brevard North', (s) => { s.area = 'Brevard North'; });
  run('Area: Lake Toxaway', (s) => { s.area = 'Lake Toxaway'; });
  run('Area: nonsense', (s) => { s.area = 'Nowhere At All'; });
  run('Only towers', (s) => { s.showKinds = new Set(['tower']); });
  // the hike filter. stops: [0,.25,.5,.75,1,1.5,2,2.5,3,4,5,6,7,8,10,12,15,20,36]
  run('Hike: roadside only', (s) => { s.walk = { min: 0, max: 0 }; });
  run('Hike: up to 2 miles', (s) => { s.walk = { min: 0, max: 6 }; });
  run('Hike: 1 to 3 miles', (s) => { s.walk = { min: 4, max: 8 }; });
  run('Hike: over 7 miles', (s) => { s.walk = { min: 12, max: 18 }; });
  run('Only waterfalls', (s) => { s.showKinds = new Set(['waterfall']); });
  run('Challenge: LTC', (s) => { s.challenge = 'LTC'; });
  run('Visited: hide', (s) => { s.visited = 'hide'; });
  run('Rate by: photo', (s) => { s.ratings = new Set(['photo']); });
  run('Rate by: solitude + beauty', (s) => { s.ratings = new Set(['solitude','beauty']); });
  run('WC100 + hide visited', (s) => { s.challenge='WC100'; s.visited='hide'; });
  run('Everything (again, for pies)', () => {});
  const dump = (label, n) => console.log('\n  ' + label + ', cluster of ' + n + ':\n    ' +
    ic({ getChildCount: () => n, getAllChildMarkers: () => kids(n) }).html.split('><span')[0] + '>');
  console.log('\npanes created:', panes.join(', ') || '(none)');
  console.log('cluster opts (last group):', JSON.stringify(clusterOpts, (k,v) => typeof v === 'function' ? '[fn]' : v));
  const ic = clusterOpts.iconCreateFunction;
  // real child markers, so pieFill tallies actual markerColor output
  // cycle with a stride so a sample cluster spans several categories
  const kids = (n) => Array.from({ length: n },
    (_, i) => made[(i * 7) % made.length]);
  console.log('\n  count -> bubble px');
  [2,3,5,10,20,40,60,80].forEach(n => {
    const m = ic({ getChildCount: () => n, getAllChildMarkers: () => kids(n) }).html
      .match(/width:(\d+)px/);
    console.log(`    ${String(n).padStart(3)} -> ${m[1]}px`);
  });
  [4, 40].forEach(n => dump('default', n));
  t.state.ratings = new Set(['photo']); made.length = 0; t.renderMarkers(false);
  dump('rate by photo', 300);
  // a climbed tower must stay a tower
  t.state.ratings = new Set();
  const tower = t.state.features.find(f => f.kind === 'tower');
  const fall  = t.state.features.find(f => f.kind === 'waterfall');
  const probe = (g, label) => {
    const was = g.last_visited;
    g.last_visited = null;  console.log(`  ${label.padEnd(10)} unvisited -> ${t.colorOf(g)}`);
    g.last_visited = '2026-09-11'; console.log(`  ${label.padEnd(10)} visited   -> ${t.colorOf(g)}`);
    g.last_visited = was;
  };
  console.log('');
  probe(tower, 'tower'); probe(fall, 'waterfall');
}, 150);

// opening the drawer is the one path the filter runs never touch
setTimeout(() => {
  const t = sandbox.__t;
  if (!t || !t.openDrawer) { console.error('openDrawer not exported'); return; }
  const pick = t.state.features.find((f) => f.beauty_rating) || t.state.features[0];
  try {
    t.openDrawer(pick, false);
    console.log('\nopenDrawer("%s") ok', pick.name);
  } catch (e) {
    console.error('\nopenDrawer THREW: %s: %s\n%s', e.constructor.name, e.message, e.stack.split('\n').slice(0,4).join('\n'));
  }
}, 60);
