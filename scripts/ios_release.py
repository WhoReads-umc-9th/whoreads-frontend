"""Install CI-only signing inputs and verify WhoReads TestFlight artifacts."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import sys
import zipfile

import release_config

APP_ID = "6820093454"
BUNDLE_ID = "com.example.whoreads"
TEAM_ID = "H78DY23Q9M"
STATE = Path(".release/ios-signing-state.json")


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise ValueError(f"Signing tool {Path(args[0]).name} failed; output hidden")
    return result.stdout


def validate_profile(profile, now=None):
    now = now or datetime.now(timezone.utc)
    expiry = profile["ExpirationDate"].replace(tzinfo=timezone.utc)
    if expiry <= now:
        raise ValueError("Provisioning profile expired")
    if (profile.get("TeamIdentifier") != [TEAM_ID]
            or profile.get("Entitlements", {}).get("application-identifier") != f"{TEAM_ID}.{BUNDLE_ID}"
            or profile.get("Entitlements", {}).get("get-task-allow") is not False
            or "ProvisionedDevices" in profile
            or profile.get("ProvisionsAllDevices")
            or not profile.get("DeveloperCertificates")
            or not re.fullmatch(r"[A-Fa-f0-9-]{36}", profile.get("UUID", ""))):
        raise ValueError("Expected the WhoReads App Store distribution profile")


def plan():
    data = json.loads(Path(".release/ios-plan.json").read_text())
    if (data.get("app_id") != APP_ID or data.get("bundle_id") != BUNDLE_ID
            or data.get("team_id") != TEAM_ID or data.get("commit") != os.environ["GITHUB_SHA"]
            or data.get("run_id") != os.environ["GITHUB_RUN_ID"]
            or os.environ["GITHUB_REF"] != "refs/heads/main"):
        raise ValueError("Artifact plan does not match the current main workflow")
    return data


def install():
    plan()
    directory = Path(os.environ["RUNNER_TEMP"]) / "whoreads-ios-signing"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    certificate = directory / "distribution.p12"
    provision = directory / "distribution.mobileprovision"
    for path, key in ((certificate, "IOS_DISTRIBUTION_CERTIFICATE_BASE64"),
                      (provision, "IOS_PROVISIONING_PROFILE_BASE64")):
        path.write_bytes(base64.b64decode(os.environ[key], validate=True))
        path.chmod(0o600)
    profile = plistlib.loads(run("security", "cms", "-D", "-i", str(provision)))
    validate_profile(profile)
    keychain = directory / "signing.keychain-db"
    password = secrets.token_urlsafe(32)
    profile_paths = [Path.home() / "Library/MobileDevice/Provisioning Profiles" / f"{profile['UUID']}.mobileprovision",
                     Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles" / f"{profile['UUID']}.mobileprovision"]
    STATE.parent.mkdir(exist_ok=True)
    STATE.write_text(json.dumps({"directory": str(directory), "keychain": str(keychain),
                                 "profiles": [str(p) for p in profile_paths]}))
    run("security", "create-keychain", "-p", password, str(keychain))
    run("security", "set-keychain-settings", "-lut", "21600", str(keychain))
    run("security", "unlock-keychain", "-p", password, str(keychain))
    run("security", "import", str(certificate), "-P", os.environ["IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"],
        "-A", "-t", "cert", "-f", "pkcs12", "-k", str(keychain))
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-k", password, str(keychain))
    search_list = run("security", "list-keychains", "-d", "user").decode()
    previous = re.findall(r'"([^"\n]+)"', search_list)
    run("security", "list-keychains", "-d", "user", "-s", str(keychain), *previous)
    identities = run("security", "find-identity", "-v", "-p", "codesigning", str(keychain)).decode()
    if "Apple Distribution:" not in identities:
        raise ValueError("No valid Apple Distribution identity in the temporary keychain")
    for path in profile_paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(provision, path)
    export = {"method": "app-store-connect", "destination": "export", "teamID": TEAM_ID,
              "signingStyle": "manual", "signingCertificate": "Apple Distribution",
              "provisioningProfiles": {BUNDLE_ID: profile["Name"]},
              "manageAppVersionAndBuildNumber": False, "stripSwiftSymbols": True,
              "uploadSymbols": True, "testFlightInternalTestingOnly": True}
    Path(".release/ios-export.plist").write_bytes(plistlib.dumps(export))
    # This Korean internal beta uses exempt standard encryption. Reassess before
    # expanding distribution to France or adding non-exempt encryption.
    plist = Path("ios/Runner/Info.plist")
    info = plistlib.loads(plist.read_bytes())
    info["ITSAppUsesNonExemptEncryption"] = False
    plist.write_bytes(plistlib.dumps(info))
    certificate.unlink()
    provision.unlink()
    print("WhoReads signing inputs validated and installed in an ephemeral keychain")


def verify_ipa(path, data):
    release_config.audit(path)
    with zipfile.ZipFile(path) as archive:
        candidates = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(candidates) != 1:
            raise ValueError("Expected exactly one main iOS application")
        info = plistlib.loads(archive.read(candidates[0]))
        if (info.get("CFBundleIdentifier") != BUNDLE_ID
                or info.get("CFBundleShortVersionString") != data["version_name"]
                or str(info.get("CFBundleVersion")) != data["build_number"]
                or info.get("ITSAppUsesNonExemptEncryption") is not False):
            raise ValueError("IPA app identity, version, or encryption declaration mismatch")
    return info


def manifest():
    data = plan()
    paths = list(Path("build/ios/ipa").glob("*.ipa"))
    if len(paths) != 1:
        raise ValueError("Expected exactly one signed IPA")
    verify_ipa(paths[0], data)
    export = plistlib.loads(Path(".release/ios-export.plist").read_bytes())
    if export.get("testFlightInternalTestingOnly") is not True or export.get("destination") != "export":
        raise ValueError("Only internal TestFlight export is authorized")
    destination = Path(".release/ios-artifacts")
    destination.mkdir(parents=True, exist_ok=True)
    ipa = destination / "whoreads.ipa"
    shutil.copyfile(paths[0], ipa)
    receipt = dict(data, sha256=hashlib.sha256(ipa.read_bytes()).hexdigest(), internal_only=True)
    (destination / "manifest.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Audited WhoReads {data['version_name']} ({data['build_number']}) for internal TestFlight only")


def cleanup():
    if STATE.exists():
        state = json.loads(STATE.read_text())
        subprocess.run(["security", "delete-keychain", state["keychain"]], capture_output=True)
        for path in state["profiles"]:
            Path(path).unlink(missing_ok=True)
        shutil.rmtree(state["directory"], ignore_errors=True)
        STATE.unlink()
    if os.environ.get("RUNNER_TEMP"):
        shutil.rmtree(Path(os.environ["RUNNER_TEMP"]) / "whoreads-ios-signing", ignore_errors=True)
    Path(".env").unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("install", "manifest", "cleanup"))
    command = parser.parse_args().command
    try:
        {"install": install, "manifest": manifest, "cleanup": cleanup}[command]()
    except Exception as error:
        print(f"iOS release validation failed ({type(error).__name__}); values hidden", file=sys.stderr)
        sys.exit(1)
