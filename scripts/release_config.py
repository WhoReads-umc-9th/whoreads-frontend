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
    return validate(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("write-env", "audit"))
    parser.add_argument("path", nargs="?")
    args = parser.parse_args()
    if args.command == "write-env":
        values = validate(os.environ)
        Path(args.path or ".env").write_text("".join(f"{k}={v}\n" for k, v in values.items()), encoding="utf-8")
    else:
        if not args.path:
            parser.error("audit requires an AAB or APK path")
        audit(Path(args.path))
    print("Release Kakao configuration validated (values hidden)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"Release blocked: {error}", file=sys.stderr)
        sys.exit(1)
