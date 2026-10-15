"""Arm the backend monitor only after a confirmed Play submission; never uploads apps."""

import argparse
import json
import os
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


def endpoint(base):
    parsed = urlsplit(base.rstrip('/'))
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password
            or parsed.query or parsed.fragment or parsed.path not in ('', '/api')):
        raise ValueError('BASE_URL must be an HTTPS API root')
    root = base.rstrip('/')
    return root + ('' if parsed.path == '/api' else '/api') + '/internal/play-review'


def payload(result):
    if result.get('package') != 'com.whoreads.mobile' or result.get('track') != 'alpha':
        raise ValueError('Only the existing WhoReads Alpha release may be monitored')
    code, commit = result.get('version_code'), result.get('commit', '')
    if type(code) is not int or not 1 <= code <= 2_100_000_000:
        raise ValueError('Invalid submitted version code')
    import re
    if not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('Invalid submitted commit')
    if result.get('status') not in ('already_recorded_on_alpha',
            'submitted_to_play; review_and_tester_availability_not_confirmed'):
        raise ValueError('Play submission was not confirmed; refusing to start a monitor')
    return {'version_code': code, 'commit': commit}


class Backend:
    def __init__(self, base, token):
        self.base = endpoint(base)
        if len(token) < 43:
            raise ValueError('Missing backend review monitor token')
        self.token = token

    def request(self, path, data=None):
        request = Request(self.base + path, method='GET' if data is None else 'POST',
            data=None if data is None else json.dumps(data).encode(),
            headers={'X-Play-Review-Token': self.token, 'Content-Type': 'application/json',
                     'User-Agent': 'WhoReads Play submission monitor registration'})
        try:
            with urlopen(request, timeout=30) as response:
                return json.load(response)
        except HTTPError as error:
            raise RuntimeError(f'Backend monitor returned HTTP {error.code}; credentials and body omitted') from None
        except (URLError, TimeoutError):
            raise RuntimeError('Backend monitor connection failed; credentials omitted') from None

    def register(self, release):
        # Same version is an idempotency key, so a lost response can safely retry.
        for attempt in range(3):
            try:
                result = self.request('/jobs', release)
                if result.get('version_code') != release['version_code']:
                    raise RuntimeError('Backend registered an unexpected release')
                print(f"Backend monitor: versionCode {release['version_code']}, state {result.get('state')}")
                return result
            except RuntimeError:
                if attempt == 2:
                    raise
                time.sleep(2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('result', type=Path)
    parser.add_argument('--probe', action='store_true')
    args = parser.parse_args()
    release = payload(json.loads(args.result.read_text()))
    backend = Backend(os.environ['BASE_URL'], os.environ['PLAY_REVIEW_MONITOR_TOKEN'])
    if not args.probe:
        backend.register(release)
        return
    health = backend.request('/health')
    if not health.get('play_connected') or not health.get('discord_connected'):
        raise RuntimeError('Backend external connections are not healthy')
    print('Backend health:', json.dumps(health, ensure_ascii=False))
    prior = os.environ.get('PLAY_REVIEW_PRIOR_MESSAGE_ID', '')
    if prior:
        backend.register(dict(release, prior_message_id=prior))
    # A probe is explicit and uses a clearly labelled test notification.
    probe = backend.request('/probes', release)
    key = probe['job_key']
    print('Registered backend scheduler probe:', key)
    for _ in range(40):
        status = backend.request('/jobs/' + key)
        if status.get('state') == 'SENT':
            print('Backend scheduler probe confirmed:', json.dumps(status, ensure_ascii=False))
            return
        if status.get('state') in ('DELIVERY_UNCERTAIN', 'REJECTED', 'SUPERSEDED'):
            raise RuntimeError('Backend scheduler probe did not complete: ' + status['state'])
        time.sleep(3)
    raise RuntimeError('Backend scheduler probe timed out; inspect the existing job before retrying')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, KeyError, OSError) as error:
        raise SystemExit(str(error)) from None
