"""Append-only page cache: one JSON record per line, gzipped.

Written with a flush after every page, and read with a tolerance for a
truncated tail, because a spider that is killed mid-write should cost you the
page it was fetching and nothing else.
"""
import gzip, json, os, zlib

def read(path):
    """Every record the file still holds, around any damage in the middle.

    Each run appends a new gzip member, and a run that is killed mid-write
    leaves a torn one. Decompressing the file as a single stream stops dead at
    the tear and loses every member after it, so the members are found by their
    magic number and decompressed one at a time.
    """
    if not os.path.exists(path):
        return
    with open(path, 'rb') as f:
        raw = f.read()

    starts = [i for i in range(len(raw) - 2)
              if raw[i] == 0x1f and raw[i + 1] == 0x8b and raw[i + 2] == 0x08]
    if not starts:
        return
    tail = ''
    for n, start in enumerate(starts):
        end = starts[n + 1] if n + 1 < len(starts) else len(raw)
        d = zlib.decompressobj(31)
        try:
            chunk = d.decompress(raw[start:end])
        except zlib.error:
            continue
        text = tail + chunk.decode('utf-8', 'replace')
        lines = text.split('\n')
        tail = lines.pop()            # a record split across members
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except ValueError:
                continue              # torn by the kill, not recoverable

def latest(path):
    """One record per URL, the most recently fetched. A resumed run can write a
    second copy of a page whose first copy was hidden behind damage."""
    best = {}
    for rec in read(path):
        url = rec.get('url')
        if url and (url not in best or rec.get('fetched_at', '') >= best[url].get('fetched_at', '')):
            best[url] = rec
    return list(best.values())

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
