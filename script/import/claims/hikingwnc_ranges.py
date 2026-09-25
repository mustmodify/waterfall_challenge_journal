"""Read the per-waterfall detail out of hikingwnc's multi-waterfall pages.

Four pages cover a run of falls rather than one, and data/hiking_wnc_falls.json
lost their detail: it holds each of those pages several times over with
byte-identical content, the page-level row copied once per waterfall. So three
of our features each stand in for four real waterfalls, wearing the
coordinate of whichever one the page happens to be named for.

The pages hold the real thing in three shapes, so this handles three:

  table    942-945, 947-950   Name | Height | Elevation | GPS
  prose    436-439            "Height - Upper Falls 50' (2 drop), Main Falls
                              40' ..." with a "GPS Info: LAT x LONG y (Name)"
                              line per waterfall
  single   996-997            one waterfall despite the range url

Reads only data/hikingwnc/*.html, never the network -- script/import/spider/
hikingwnc.py put them there. Prints what it found; writes nothing.
"""
import html, os, re, sys

DIR = 'data/hikingwnc'


def text_of(page):
    body = re.sub(r'(?is)<(script|style).*?</\1>', ' ', page)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', body)))


def feet(raw):
    """A height in feet. Ranges and multi-drop notes take the first number,
    the same rule the rest of the pipeline uses."""
    m = re.search(r'([0-9]+(?:\.[0-9]+)?)', raw or '')
    return float(m.group(1)) if m else None


def from_table(page):
    """Name | Height | Elevation | GPS, one waterfall per row."""
    out = []
    for tbl in re.finditer(r'(?is)<table.*?</table>', page):
        rows = re.findall(r'(?is)<tr.*?</tr>', tbl.group())
        if len(rows) < 2:
            continue
        head = None
        for r in rows:
            cells = [html.unescape(re.sub(r'<[^>]+>', '', c)).strip()
                     for c in re.findall(r'(?is)<t[dh][^>]*>(.*?)</t[dh]>', r)]
            if not any(cells):
                continue
            if head is None:
                head = [c.lower() for c in cells]
                if 'name' not in head or 'gps' not in head:
                    head = None
                continue
            row = dict(zip(head, cells))
            gps = re.search(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)', row.get('gps', ''))
            if not gps:
                continue
            out.append({
                'name': row.get('name', '').strip(),
                'height_ft': feet(row.get('height', '')),
                'elevation_ft': feet(row.get('elevation', '')),
                'lat': float(gps.group(1)), 'lon': float(gps.group(2)),
            })
    return out


def from_prose(text):
    """"GPS Info: LAT x LONG y (Name)" once per waterfall, with the heights
    collected in a single labelled Height line."""
    pts = []
    for m in re.finditer(
            r'GPS Info:\s*LAT\s*(-?\d+\.\d+)\s*LONG\s*(-?\d+\.\d+)\s*\(([^)]+)\)', text):
        pts.append({'lat': float(m.group(1)), 'lon': float(m.group(2)),
                    'name': m.group(3).strip(), 'height_ft': None,
                    'elevation_ft': None})
    if not pts:
        return []

    # "Height - Upper Falls 50' (2 drop), Main Falls 40', Third Falls 15' ..."
    hm = re.search(r'Height\s*[-–—]\s*(.*?)(?=Distance\s*[-–—]|$)', text)
    if not hm:
        return pts

    heights = []
    for part in re.split(r',\s*', hm.group(1)):
        nm = re.match(r'\s*([A-Za-z][A-Za-z ]*?)\s*([0-9].*)$', part)
        if nm:
            heights.append((nm.group(1).strip().lower(), feet(nm.group(2))))

    taken, used = set(), set()
    for hi, (label, h) in enumerate(heights):
        want = set(label.split()) - {'falls'}
        for i, p in enumerate(pts):
            have = set(p['name'].lower().split()) - {'falls'}
            if i not in taken and (want & have):
                p['height_ft'] = h
                taken.add(i)
                used.add(hi)
                break

    # Both lists are in page order, so whatever is left over pairs by
    # position. That is what rescues "Final Falls 15-20'" against a GPS line
    # labelled "Last Falls" -- one waterfall under two of his own names.
    spare_h = [h for hi, (_, h) in enumerate(heights) if hi not in used]
    spare_p = [p for i, p in enumerate(pts) if i not in taken]
    for p, h in zip(spare_p, spare_h):
        p['height_ft'] = h
    return pts


def main():
    for fn in sorted(os.listdir(DIR)):
        if not fn.endswith('.html'):
            continue
        page = open(os.path.join(DIR, fn), encoding='utf-8', errors='replace').read()
        text = text_of(page)
        found = from_table(page) or from_prose(text)
        print('== %s' % fn)
        if not found:
            gps = re.search(r'GPS Info:\s*LAT\s*(-?\d+\.\d+)\s*LONG\s*(-?\d+\.\d+)', text)
            title = re.search(r'<title[^>]*>(.*?)</title>', page, re.S)
            print('   one waterfall, not a run: %s%s' % (
                html.unescape(title.group(1)).split('|')[0].strip() if title else '?',
                '  %s, %s' % gps.groups() if gps else ''))
        for w in found:
            print('   %-24s %6s ft  %7s ft elev  %s, %s' % (
                w['name'][:24],
                '' if w['height_ft'] is None else int(w['height_ft']),
                '' if w['elevation_ft'] is None else int(w['elevation_ft']),
                w['lat'], w['lon']))
        print()


if __name__ == '__main__':
    main()
