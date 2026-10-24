"""Verify signing scope and the actual exported IPA metadata checks."""
from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ios_release


class IosReleaseTest(unittest.TestCase):
    def profile(self):
        return {"ExpirationDate": datetime.now(timezone.utc) + timedelta(days=30),
                "TeamIdentifier": [ios_release.TEAM_ID],
                "UUID": "12345678-1234-1234-1234-123456789abc",
                "DeveloperCertificates": [b"certificate fixture"],
                "Entitlements": {"application-identifier": f"{ios_release.TEAM_ID}.{ios_release.BUNDLE_ID}",
                                 "get-task-allow": False}}

    def test_distribution_profile_scope(self):
        ios_release.validate_profile(self.profile())
        for changes in ({"TeamIdentifier": ["OTHER"]}, {"ProvisionedDevices": []},
                        {"ProvisionsAllDevices": True},
                        {"ExpirationDate": datetime.now(timezone.utc) - timedelta(days=1)}):
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError):
                    ios_release.validate_profile(dict(self.profile(), **changes))

    def test_debug_profile_is_not_accepted(self):
        profile = self.profile()
        profile["Entitlements"]["get-task-allow"] = True
        with self.assertRaises(ValueError):
            ios_release.validate_profile(profile)

    def test_exported_ipa_must_match_planned_app_and_version(self):
        plan = {"version_name": "1.0.4", "build_number": "5"}
        info = {"CFBundleIdentifier": ios_release.BUNDLE_ID, "CFBundleShortVersionString": "1.0.4",
                "CFBundleVersion": "5", "ITSAppUsesNonExemptEncryption": False}
        with tempfile.TemporaryDirectory() as directory:
            for override in ({}, {"CFBundleIdentifier": "another.app"}, {"CFBundleVersion": "4"}):
                with self.subTest(override=override):
                    path = Path(directory) / "release.ipa"
                    with zipfile.ZipFile(path, "w") as archive:
                        archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps(dict(info, **override)))
                        archive.writestr("Payload/Runner.app/Frameworks/App.framework/flutter_assets/.env",
                                         "BASE_URL=https://api.example.com\n")
                    if override:
                        with self.assertRaises(ValueError):
                            ios_release.verify_ipa(path, plan)
                    else:
                        self.assertEqual(ios_release.verify_ipa(path, plan), info)


if __name__ == "__main__":
    unittest.main()
