"""Release artifacts must contain only the mobile configuration allowlist."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location(
    "release_config", Path(__file__).resolve().parents[1] / "release_config.py")
release_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release_config)


class ReleaseConfigAuditTest(unittest.TestCase):
    def test_supported_archives(self):
        assets = {
            ".apk": "assets/flutter_assets/.env",
            ".aab": "base/assets/flutter_assets/.env",
            ".ipa": "Payload/Runner.app/Frameworks/App.framework/flutter_assets/.env",
        }
        with tempfile.TemporaryDirectory() as directory:
            for suffix, asset in assets.items():
                with self.subTest(suffix=suffix):
                    path = Path(directory) / ("release" + suffix)
                    with zipfile.ZipFile(path, "w") as archive:
                        archive.writestr(asset, "BASE_URL=https://api.example.com\n")
                    self.assertEqual(release_config.audit(path),
                                     {"BASE_URL": "https://api.example.com"})

    def test_ios_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / "Runner.app"
            asset = app / "Frameworks/App.framework/flutter_assets/.env"
            asset.parent.mkdir(parents=True)
            asset.write_text("BASE_URL=https://api.example.com\n")
            self.assertEqual(release_config.audit(app),
                             {"BASE_URL": "https://api.example.com"})

    def test_ios_rejects_server_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "release.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(
                    "Payload/Runner.app/Frameworks/App.framework/flutter_assets/.env",
                    "BASE_URL=https://api.example.com\nKAKAO_CLIENT_SECRET=fixture\n")
            with self.assertRaises(ValueError):
                release_config.audit(path)

    def test_ios_rejects_missing_or_ambiguous_configuration(self):
        with tempfile.TemporaryDirectory() as directory:
            for app_names in ([], ["Runner", "Other"]):
                with self.subTest(app_names=app_names):
                    path = Path(directory) / "release.ipa"
                    with zipfile.ZipFile(path, "w") as archive:
                        for name in app_names:
                            archive.writestr(
                                f"Payload/{name}.app/Frameworks/App.framework/flutter_assets/.env",
                                "BASE_URL=https://api.example.com\n")
                    with self.assertRaises(ValueError):
                        release_config.audit(path)


if __name__ == "__main__":
    unittest.main()
