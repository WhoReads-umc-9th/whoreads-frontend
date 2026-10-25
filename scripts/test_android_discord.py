import copy
import unittest
from unittest.mock import patch, MagicMock
import android_discord as notify


class NotificationTests(unittest.TestCase):
    def setUp(self):
        self.run = dict(id=123, path='.github/workflows/build_release.yaml',
                        head_branch='main', event='push', status='completed',
                        conclusion='success', head_sha='abc')
        self.result = dict(commit='abc', package='com.whoreads.mobile', track='alpha',
                           version_name='1.0.8', version_code=9,
                           status='submitted_to_play; review_and_tester_availability_not_confirmed')

    def test_accept_exact_submission(self):
        self.assertEqual(notify.validate(self.run, self.result, '123'), self.result)

    def test_reject_wrong_or_failed_run(self):
        for key, value in [('id', 456), ('path', 'other.yaml'), ('head_branch', 'other'),
                           ('event', 'pull_request'), ('conclusion', 'failure')]:
            run = copy.deepcopy(self.run)
            run[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                notify.validate(run, self.result, '123')

    def test_reject_mismatched_or_unsubmitted_result(self):
        for key, value in [('commit', 'old'), ('package', 'other'), ('track', 'production'),
                           ('status', 'built'), ('version_code', 0)]:
            result = dict(self.result, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                notify.validate(self.run, result, '123')

    @patch('android_discord.urllib.request.urlopen')
    def test_send_requires_confirmed_message(self, open_url):
        response = MagicMock()
        response.read.return_value = '{"id":"456","content":"wrong"}'.encode()
        open_url.return_value.__enter__.return_value = response
        with self.assertRaises(RuntimeError):
            notify.send(self.result, 'https://discord.com/api/webhooks/123/fixture', '123')
        request = open_url.call_args.args[0]
        self.assertTrue(request.full_url.endswith('?wait=true'))
        self.assertIn(b'allowed_mentions', request.data)


if __name__ == '__main__':
    unittest.main()
