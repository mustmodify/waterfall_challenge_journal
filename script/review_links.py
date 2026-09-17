"""Find links due for review and check whether they still resolve.

A link is a claim that some outside page is still there and still about this
place. That claim goes stale -- sites reorganize, hikingwnc renumbers pages,
AllTrails routes get merged -- and nothing before this caught it.

REVIEW_INTERVAL_DAYS is 180: long enough that this isn't hammering every site
in the links table twice a season, short enough that a dead link doesn't sit
unnoticed for years. reviewed_at IS NULL (never checked) always sorts first,
regardless of interval.

    python3 script/review_links.py            report only, nothing written
    python3 script/review_links.py -commit    mark live links reviewed_at = now()

A link that comes back dead is never touched automatically -- it is reported
so a person decides whether the place moved, the source restructured its
URLs, or the page is really gone. Marking a *dead* link reviewed would say
"checked, fine" about something that is not fine.
"""
import subprocess, sys, time, urllib.error, urllib.request

REVIEW_INTERVAL_DAYS = 180
UA = {'User-Agent': 'wanderfall-research/0.1 (+https://wanderfall.app)'}
PAUSE = 0.3

def psql(sql):
    out = subprocess.run(['psql', '-qAt', '-F|', '-d', 'wc_journey_db', '-c', sql],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stderr)
    return [l.split('|') for l in out.stdout.strip().split('\n') if l]

def lit(s):
    return "'" + s.replace("'", "''") + "'"

def due():
    rows = psql("""
        SELECT l.id, l.url, l.rel, f.name
        FROM links l JOIN features f ON f.id = l.feature_id
        WHERE l.reviewed_at IS NULL
           OR l.reviewed_at < now() - interval '%d days'
        ORDER BY l.reviewed_at IS NOT NULL, l.reviewed_at, l.id
    """ % REVIEW_INTERVAL_DAYS)
    return [(int(r[0]), r[1], r[2], r[3]) for r in rows]

def check(url):
    req = urllib.request.Request(url, headers=UA, method='HEAD')
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        if e.code == 405:  # HEAD not allowed; try GET before calling it dead
            try:
                req = urllib.request.Request(url, headers=UA, method='GET')
                with urllib.request.urlopen(req, timeout=15) as resp:
                    return resp.status
            except (urllib.error.HTTPError, urllib.error.URLError) as e2:
                return getattr(e2, 'code', None) or str(e2)
        return e.code
    except urllib.error.URLError as e:
        return str(e.reason)

def main():
    commit = '-commit' in sys.argv
    rows = due()
    print('%d link(s) due for review\n' % len(rows))

    live, dead = [], []
    for i, (link_id, url, rel, feature_name) in enumerate(rows):
        time.sleep(PAUSE)
        status = check(url)
        ok = isinstance(status, int) and 200 <= status < 400
        (live if ok else dead).append((link_id, url, rel, feature_name, status))
        print('  %-4s %-14s %-40s %s' % (status, rel or '', feature_name[:40], url))
        if (i + 1) % 25 == 0:
            print('  ... %d/%d' % (i + 1, len(rows)))

    print('\n%d live, %d dead' % (len(live), len(dead)))
    if dead:
        print('\nDEAD -- needs a human look, reviewed_at left alone:')
        for link_id, url, rel, feature_name, status in dead:
            print('  #%d %-40s %-14s %s (%s)' % (link_id, feature_name[:40], rel or '', url, status))

    if commit and live:
        ids = ','.join(str(i) for i, *_ in live)
        psql('UPDATE links SET reviewed_at = now() WHERE id IN (%s)' % ids)
        print('\nmarked %d live link(s) reviewed_at = now()' % len(live))
    elif live:
        print('\nDry run. Re-run with -commit to mark the %d live link(s) reviewed.' % len(live))

if __name__ == '__main__':
    main()
