"""Notify only for the exact successful Alpha submission, never imply approval."""
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

DIRECTORY = Path('.release/android-discord')
MESSAGE = '[WhoReads] - Android 비공개 테스트 제출 완료 (Google 심사·테스터 제공 확인 전)'


def validate(run, result, run_id):
    if not (str(run['id']) == str(run_id)
            and run['path'] == '.github/workflows/build_release.yaml'
            and run['head_branch'] == 'main'
            and run['event'] in ('push', 'workflow_dispatch')
            and run['status'] == 'completed' and run['conclusion'] == 'success'):
        raise ValueError('Expected a successful main Android release run')
    if not (result['commit'] == run['head_sha']
            and result['package'] == 'com.whoreads.mobile'
            and result['track'] == 'alpha'
            and result['status'] in (
                'submitted_to_play; review_and_tester_availability_not_confirmed',
                'already_recorded_on_alpha')
            and isinstance(result['version_code'], int) and result['version_code'] > 0
            and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', result['version_name'])):
        raise ValueError('Expected the exact verified Alpha submission result')
    return result


def send(result, webhook, run_id):
    if not re.fullmatch(r'https://discord\.com/api/webhooks/\d+/[\w-]+', webhook):
        raise ValueError('Invalid Discord webhook; value omitted')
    description = (f"{result['version_name']} ({result['version_code']})\n"
                   f"https://github.com/WhoReads-umc-9th/whoreads-frontend/actions/runs/{run_id}")
    payload = {'content': MESSAGE, 'allowed_mentions': {'parse': []},
               'embeds': [{'description': description}]}
    request = urllib.request.Request(webhook + '?wait=true',
                                     data=json.dumps(payload).encode(),
                                     headers={'Content-Type': 'application/json',
                                              'User-Agent': 'WhoReads-Release/1.0'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            receipt = json.load(response)
    except Exception:
        raise RuntimeError('Discord delivery uncertain; inspect before resending') from None
    if not (re.fullmatch(r'\d+', str(receipt.get('id', '')))
            and receipt.get('content') == MESSAGE):
        raise RuntimeError('Discord delivery not confirmed; inspect before resending')
    print(f"Discord confirmed message {receipt['id']}")


if __name__ == '__main__':
    run_id = os.environ['SOURCE_RUN_ID']
    result = validate(json.loads((DIRECTORY / 'run.json').read_text()),
                      json.loads((DIRECTORY / 'play-result.json').read_text()), run_id)
    if sys.argv[1] == 'send':
        send(result, os.environ['DISCORD_WEBHOOK_URL'], run_id)
    elif sys.argv[1] != 'verify':
        raise ValueError('Expected verify or send')
