"""Download and audit the newest main Actions release; never uploads to Play."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from release_config import audit

REPO = "WhoReads-umc-9th/whoreads-frontend"
WORKFLOW = "build_release.yaml"


def gh_json(*args):
    return json.loads(subprocess.check_output(["gh", *args], text=True))


def select_run(runs):
    if not runs:
        raise ValueError("No main release build found")
    run = runs[0]
    if run["status"] != "completed" or run["conclusion"] != "success":
        raise ValueError("Newest main release build has not succeeded; do not use an older AAB")
    return run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--minimum-version-code", type=int, required=True,
                        help="Highest versionCode already uploaded to Play, including drafts")
    parser.add_argument("--aapt2", default=shutil.which("aapt2"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not args.aapt2:
        parser.error("--aapt2 is required (Android SDK build-tools)")
    runs = gh_json("run", "list", "--repo", REPO, "--workflow", WORKFLOW,
                   "--branch", "main", "--limit", "1", "--json",
                   "databaseId,headSha,status,conclusion,url,createdAt")
    run = select_run(runs)
    latest_sha = gh_json("api", f"repos/{REPO}/commits/main")["sha"]
    if run["headSha"] != latest_sha:
        raise ValueError("Latest main commit has no successful release artifact yet")
    artifacts = gh_json("api", f"repos/{REPO}/actions/runs/{run['databaseId']}/artifacts")["artifacts"]
    matches = [a for a in artifacts if a["name"] == "app-release" and not a["expired"]]
    if len(matches) != 1:
        raise ValueError("Exactly one unexpired app-release artifact is required")
    destination = args.output or Path(tempfile.mkdtemp(prefix=f"whoreads-play-{run['databaseId']}-"))
    if args.output:
        destination.mkdir(parents=True, exist_ok=True)
        if any(destination.iterdir()):
            raise ValueError("Output directory must be empty to avoid mixing releases")
    subprocess.run(["gh", "run", "download", str(run["databaseId"]), "--repo", REPO,
                    "--name", "app-release", "--dir", str(destination)], check=True)
    bundles, apks = list(destination.rglob("*.aab")), list(destination.rglob("*.apk"))
    if len(bundles) != 1 or len(apks) != 1:
        raise ValueError("Artifact must contain one AAB and one paired APK")
    bundle, apk = bundles[0], apks[0]
    if audit(bundle) != audit(apk):
        raise ValueError("Paired APK and AAB configuration differs")
    badging = subprocess.check_output([args.aapt2, "dump", "badging", str(apk)], text=True)
    metadata = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    if not metadata or metadata[1] != "com.whoreads.mobile":
        raise ValueError("APK package differs from the WhoReads Play app")
    code = int(metadata[2])
    if code <= args.minimum_version_code:
        raise ValueError("versionCode must exceed every version already uploaded to Play")
    report = {"repository": REPO, "run": run, "artifactId": matches[0]["id"],
              "aab": str(bundle.resolve()), "apk": str(apk.resolve()),
              "package": metadata[1], "versionCodeFromPairedApk": code,
              "versionNameFromPairedApk": metadata[3],
              "sha256": hashlib.file_digest(bundle.open("rb"), "sha256").hexdigest(),
              "status": "prepared; Play upload and publication not performed"}
    (destination / "release-provenance.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Release blocked: {error}", file=sys.stderr)
        sys.exit(1)
