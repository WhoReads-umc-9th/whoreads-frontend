"""Restore Android build credentials from environment without shell expansion."""
import base64
import binascii
import json
import os
from pathlib import Path
import sys


def private_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "wb") as stream:
        stream.write(data)
    path.chmod(0o600)


def property_value(value):
    if not value or "\n" in value or "\r" in value:
        raise ValueError("Signing properties must be nonempty single-line values")
    return value.replace("\\", "\\\\").replace(" ", "\\ ").replace("=", "\\=").replace(":", "\\:")


def restore(values, root=Path(".")):
    config = json.loads(values["GOOGLE_SERVICES_JSON"])
    if (config.get("type") == "service_account" or "private_key" in config
            or "client_email" in config or not config.get("project_info") or not config.get("client")):
        raise ValueError("Expected Firebase mobile app config; service account keys are forbidden")
    encoded = "".join(values["KEYSTORE_BASE64"].split())
    key = base64.b64decode(encoded, validate=True)
    if not key:
        raise ValueError("Upload keystore missing")
    props = {"storePassword": values["STORE_PASSWORD"], "keyPassword": values["KEY_PASSWORD"],
             "keyAlias": values["KEY_ALIAS"], "storeFile": "../app/key.jks"}
    properties = "".join(f"{k}={property_value(v)}\n" for k, v in props.items())
    private_write(root / "android/app/google-services.json", json.dumps(config).encode())
    private_write(root / "android/app/key.jks", key)
    private_write(root / "android/key.properties", properties.encode())


if __name__ == "__main__":
    try:
        restore(os.environ)
        print("Android release inputs prepared (values hidden)")
    except (ValueError, KeyError, binascii.Error):
        print("Android release inputs invalid or missing (values hidden)", file=sys.stderr)
        sys.exit(1)
