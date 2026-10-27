"""Read-only catalog audit: compare declared files and hashes with Hugging Face.

This reads metadata only. It never downloads weights, loads models or sends chat.
A matching artifact is evidence of identity, not of runtime compatibility.
"""
import concurrent.futures
import datetime
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/audits/navigation-models-2026-10-20'


def entries():
    """Read positional catalog fields, keeping each source URL and declared hash."""
    for path in sorted((ROOT / 'lib/core/models').glob('catalog_entries_*.dart')):
        for block in re.findall(r'LmCatalogEntry\((.*?)\n  \),', path.read_text(encoding='utf-8'), re.S):
            fields = re.findall(r"'([^']*)'", block)
            if len(fields) >= 6:
                yield dict(name=fields[0], file=fields[3], url=fields[4], expected_sha256=fields[5])


def inspect(entry):
    """Query the exact revision from the catalog, including pinned historical files."""
    result = dict(entry)
    parts = urllib.parse.urlparse(entry['url']).path.strip('/').split('/')
    repo = '/'.join(parts[:2])
    revision = parts[3] if len(parts) > 3 and parts[2] == 'resolve' else 'main'
    api = f'https://huggingface.co/api/models/{repo}/revision/{revision}?blobs=true'
    try:
        request = urllib.request.Request(api, headers={'User-Agent': 'NanoCatalogAudit/1.0'})
        with urllib.request.urlopen(request, timeout=25) as response:
            metadata = json.load(response)
        result['resolved_revision'] = metadata.get('sha')
        if len(parts) <= 2:
            result['status'] = 'package_requires_per_file_verification'
            return result
        file = next((x for x in metadata.get('siblings', []) if x['rfilename'] == entry['file']), None)
        if not file:
            result['status'] = 'file_missing'
            return result
        result['actual_sha256'] = file.get('lfs', {}).get('sha256')
        result['actual_size_bytes'] = file.get('size', file.get('lfs', {}).get('size'))
        result['status'] = ('hash_matches' if result['actual_sha256'] == entry['expected_sha256']
                            else 'hash_changed_or_unavailable')
    except (urllib.error.URLError, ValueError, TimeoutError) as error:
        result['status'] = 'not_verified'
        result['error'] = str(error)
    return result


def main():
    """Persist evidence with timestamps; do not silently correct catalog hashes."""
    OUT.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(inspect, entries()))
    report = {'checked_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'scope': 'Public metadata only; no inference or device performance verified.',
              'models': results}
    (OUT / 'catalog-source-evidence.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    counts = {status: sum(x['status'] == status for x in results) for status in sorted({x['status'] for x in results})}
    print(json.dumps({'total': len(results), 'counts': counts, 'attention': [x['name'] for x in results if x['status'] not in ('hash_matches', 'package_requires_per_file_verification')]}, ensure_ascii=False))


if __name__ == '__main__':
    main()
