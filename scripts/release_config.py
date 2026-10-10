"""Validate release dotenv without printing key values (standard library only)."""
import argparse
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit, parse_qs
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError, URLError
import zipfile

KEYS = ("BASE_URL",)


def parse_env(text):
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep:
            raise ValueError("Malformed dotenv variable")
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
    if "\n" in base or "\r" in base:
        raise ValueError("Release configuration must contain single-line values")
    if uri.path not in ("", "/api"):
        raise ValueError("BASE_URL must point to the API root")
    return {"BASE_URL": base}


def verify_kakao_server(values):
    """Check the deployed OAuth entry point without following it or logging keys."""
    import secrets

    class NoRedirect(HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    base = validate(values)["BASE_URL"]
    api = base if base.endswith("/api") else base + "/api"
    state = secrets.token_urlsafe(32)
    request = Request(api + "/auth/kakao/authorize?state=" + state)
    try:
        with build_opener(NoRedirect).open(request, timeout=15):
            raise ValueError("Kakao server must return a 302 redirect")
    except HTTPError as response:
        if response.code != 302:
            raise ValueError("Kakao server entry point is not deployed or healthy") from None
        location = response.headers.get("Location", "")
        cache = response.headers.get("Cache-Control", "")
        response.close()
    except URLError:
        raise ValueError("Kakao server is unreachable") from None
    uri = urlsplit(location)
    params = parse_qs(uri.query, keep_blank_values=True)
    if (uri.scheme != "https" or uri.hostname != "kauth.kakao.com"
            or uri.username or uri.password or uri.fragment or uri.port not in (None, 443)
            or uri.path != "/oauth/authorize"
            or set(params) != {"client_id", "redirect_uri", "response_type", "state"}
            or params.get("state") != [state]
            or params.get("response_type") != ["code"]
            or params.get("redirect_uri") != [api + "/auth/kakao/callback"]
            or len(params.get("client_id", [])) != 1
            or not re.fullmatch(r"[a-fA-F0-9]{32}", params["client_id"][0])
            or "no-store" not in cache):
        raise ValueError("Kakao server redirect is invalid or exposes unexpected data")


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
        target = Path(args.path or ".env")
        with os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as stream:
            stream.write("".join(f"{k}={v}\n" for k, v in values.items()))
        target.chmod(0o600)
    else:
        if not args.path:
            parser.error("audit requires an AAB or APK path")
        audit(Path(args.path))
    print("Key-free release configuration validated (values hidden)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, zipfile.BadZipFile):
        print("Release configuration invalid or unsafe (values hidden)", file=sys.stderr)
        sys.exit(1)
