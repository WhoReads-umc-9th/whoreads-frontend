"""Validate release dotenv without printing key values (standard library only)."""
import argparse
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit
import zipfile

KEYS = ("BASE_URL", "KAKAO_REST_API_KEY", "KAKAO_REDIRECT_URI",
        "KAKAO_NATIVE_APP_KEY", "KAKAO_JAVASCRIPT_APP_KEY")


def parse_env(text):
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if sep:
            if key.strip() in result:
                raise ValueError("Duplicate dotenv variable")
            result[key.strip()] = value.strip().strip("\"'")
    return result


def validate(values):
    base = values.get("BASE_URL", "").strip().rstrip("/")
    uri = urlsplit(base)
    if (uri.scheme != "https" or not uri.hostname or uri.username
            or uri.password or uri.query or uri.fragment):
        raise ValueError("BASE_URL must be an HTTPS API address")
    if not re.fullmatch(r"[a-fA-F0-9]{32}", values.get("KAKAO_REST_API_KEY", "").strip()):
        raise ValueError("KAKAO_REST_API_KEY missing or invalid; release blocked")
    for key in ("KAKAO_NATIVE_APP_KEY", "KAKAO_JAVASCRIPT_APP_KEY"):
        value = values.get(key, "").strip()
        if value and not re.fullmatch(r"[a-fA-F0-9]{32}", value):
            raise ValueError("Optional Kakao platform key invalid")
    api = base if base.endswith("/api") else base + "/api"
    callback = api + "/auth/kakao/callback"
    redirect = values.get("KAKAO_REDIRECT_URI", "").strip() or callback
    if redirect != callback:
        raise ValueError("KAKAO_REDIRECT_URI does not match the backend callback")
    clean = {key: values.get(key, "").strip() for key in KEYS}
    clean.update(BASE_URL=base, KAKAO_REDIRECT_URI=redirect)
    if any("\n" in v or "\r" in v for v in clean.values()):
        raise ValueError("Release configuration must contain single-line values")
    return clean


def audit(path):
    asset = "base/assets/flutter_assets/.env" if path.suffix == ".aab" else "assets/flutter_assets/.env"
    with zipfile.ZipFile(path) as archive:
        values = parse_env(archive.read(asset).decode("utf-8"))
    if set(values) - set(KEYS):
        raise ValueError("Unexpected dotenv variables in app; server secrets must not be bundled")
    return validate(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("write-env", "audit"))
    parser.add_argument("path", nargs="?")
    args = parser.parse_args()
    if args.command == "write-env":
        values = validate(os.environ)
        # Check tracked source only; generated, ignored configuration is allowed.
        import subprocess
        tracked = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
        app_keys = [v.encode() for k, v in values.items() if k.endswith("_KEY") and v]
        for name in filter(None, tracked):
            data = Path(name).read_bytes()
            if any(key in data for key in app_keys):
                raise ValueError("App key literal found in tracked source; use build injection")
        target = Path(args.path or ".env")
        with os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as stream:
            stream.write("".join(f"{k}={v}\n" for k, v in values.items()))
        target.chmod(0o600)
        native = values["KAKAO_NATIVE_APP_KEY"]
        config = Path("ios/Flutter/Kakao.xcconfig")
        if config.parent.is_dir():
            # Xcode reads this ignored config before processing Info.plist.
            scheme = "kakao" + native if native else "whoreads-kakao-unconfigured"
            config.write_text(f"KAKAO_CALLBACK_SCHEME = {scheme}\n", encoding="utf-8")
            config.chmod(0o600)
    else:
        if not args.path:
            parser.error("audit requires an AAB or APK path")
        audit(Path(args.path))
    print("Release Kakao configuration validated (values hidden)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, zipfile.BadZipFile):
        print("Release configuration invalid or unsafe (values hidden)", file=sys.stderr)
        sys.exit(1)
