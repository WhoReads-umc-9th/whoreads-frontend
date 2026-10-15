import unittest
from unittest.mock import patch
from register_play_review import Backend, endpoint, payload


class RegistrationTest(unittest.TestCase):
    def setUp(self):
        self.result = {'package': 'com.whoreads.mobile', 'track': 'alpha', 'version_code': 6,
                       'commit': 'a' * 40, 'status': 'submitted_to_play; review_and_tester_availability_not_confirmed'}

    def test_only_confirmed_alpha_submissions_can_start_a_monitor(self):
        self.assertEqual(6, payload(self.result)['version_code'])
        for key, value in [('status', 'build_success'), ('track', 'production'), ('package', 'other'),
                           ('commit', 'bad'), ('version_code', 0), ('version_code', True)]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                payload(dict(self.result, **{key: value}))

    def test_api_root_is_normalized_and_unsafe_destinations_are_rejected(self):
        for base in ['https://api.example.test', 'https://api.example.test/api/']:
            self.assertEqual('https://api.example.test/api/internal/play-review', endpoint(base))
        for base in ['http://example.test', 'https://token@example.test', 'https://example.test?key=secret',
                     'https://example.test/other', 'https://example.test/#fragment']:
            with self.assertRaises(ValueError):
                endpoint(base)

    def test_ambiguous_registration_response_retries_only_the_same_version(self):
        backend = Backend('https://example.test/api', 'a' * 64)
        release = payload(self.result)
        with patch.object(backend, 'request', side_effect=[RuntimeError('timeout'),
                {'version_code': 6, 'state': 'ACTIVE'}]) as request, patch('register_play_review.time.sleep'):
            backend.register(release)
        self.assertEqual(2, request.call_count)
        self.assertEqual(request.call_args_list[0], request.call_args_list[1])


if __name__ == '__main__':
    unittest.main()
