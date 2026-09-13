"""One request at a time, with a pause between and a retreat when refused.

The Wayback Machine will start refusing connections outright if you ask for
replay pages at any speed it dislikes, and it does not always say so with a
status code -- the first sign is ECONNREFUSED on every request. Backing off and
waiting is the only thing that helps, so a refusal is retried rather than
counted as a missing page.
"""
import sys, time, urllib.error, urllib.request

UA = {'User-Agent': 'wanderfall-research/0.1 (+https://wanderfall.app)'}

class Fetcher:
    def __init__(self, pause=0.25, tries=5, timeout=90):
        self.pause = pause
        self.tries = tries
        self.timeout = timeout

    def backoff(self, wait, err, url):
        wait = min(max(wait * 4, 5), 60)
        print('  retrying in %gs after %s: %s' % (wait, type(err).__name__, url[:90]),
              file=sys.stderr)
        return wait

    def get(self, url):
        wait = self.pause
        for attempt in range(self.tries):
            time.sleep(wait)
            try:
                req = urllib.request.Request(url, headers=UA)
                with urllib.request.urlopen(req, timeout=self.timeout) as f:
                    return f.read()
            except urllib.error.HTTPError as e:
                if e.code in (429, 503, 504) and attempt < self.tries - 1:
                    wait = self.backoff(wait, e, url)
                    continue
                raise
            except (urllib.error.URLError, OSError) as e:
                if attempt < self.tries - 1:
                    wait = self.backoff(wait, e, url)
                    continue
                raise
        return None
