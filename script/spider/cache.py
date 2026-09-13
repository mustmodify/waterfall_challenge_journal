"""Append-only page cache: one JSON record per line, gzipped.

Written with a flush after every page, and read with a tolerance for a
truncated tail, because a spider that is killed mid-write should cost you the
page it was fetching and nothing else.
"""
import gzip, json, os

def read(path):
    if not os.path.exists(path):
        return
    try:
        with gzip.open(path, 'rt', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except ValueError:
                    continue          # a half-written last line
    except EOFError:
        return                        # the stream itself was cut short

def urls(path):
    return {rec['url'] for rec in read(path) if 'url' in rec}

class Writer:
    def __init__(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.f = gzip.open(path, 'at', encoding='utf-8')

    def add(self, record):
        self.f.write(json.dumps(record) + '\n')
        self.f.flush()

    def close(self):
        self.f.close()
