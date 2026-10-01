#!/usr/bin/env python3
"""OpenCone's App Store release steps for one version, through the App Store Connect API (the same
JWT recipe as OpenManual's and OpenResponses' scripts/asc). Run through `zsh -ic` so ~/.zshrc's
APP_STORE_CONNECT_* variables are set; nothing here prints key material. Every command that changes
App Store Connect only prints its plan unless `--go` is passed.

  status                        version, builds, attached build, listing text, screenshots, submissions
  listing FILE.json [--go]      subtitle, description, keywords, promotional text, What's New, URLs, copyright
  notes FILE.txt [--go]         App Review notes: keeps the lines above "- Steps -" (the reviewer's
                                credentials, which stay in App Store Connect and are never printed)
                                and replaces the rest with FILE
  shots DIR [--go]              make the 6.9-inch set hold DIR's PNGs, in file-name order
  attach BUILD [--go]           attach a VALID build of this version, by build number
  submit [--go]                 create or reuse a review submission, add the version, submit

Xcode Cloud's "Default" workflow archives every push to main and uploads build N for run N.
"""
import hashlib, json, os, sys, time, urllib.error, urllib.request
from pathlib import Path

import jwt

APP = "6744467668"
VERSION = "da441423-1583-4a7f-9f6b-a78e07daac06"        # 3.1, iOS
VERSION_STRING = "3.1"
VERSION_LOC = "86a435c9-489f-45b1-a877-31fabb501275"    # 3.1 en-US
APP_INFO_LOC = "a30a63b6-fb54-45d2-8fb4-0f11129467bb"   # the editable app info's en-US
REVIEW_DETAIL = "5e03d3a1-3bcf-4841-9371-bcfb04bc1ab8"
SHOT_TYPE = "APP_IPHONE_67"                             # holds the 1320 x 2868 (6.9-inch) screenshots
OPEN = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}
LIMITS = {"subtitle": 30, "promotionalText": 170, "description": 4000, "keywords": 100, "whatsNew": 4000}
BASE = "https://api.appstoreconnect.apple.com"


def token():
    now = int(time.time())
    key = Path(os.path.expanduser(os.environ["APP_STORE_CONNECT_API_KEY_PATH"])).read_text()
    return jwt.encode({"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 1200,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["APP_STORE_CONNECT_API_KEY_ID"]})


def call(method, path, body=None, raw=None, headers=None, absolute=False):
    url = path if absolute else BASE + path
    h = {} if absolute else {"Authorization": f"Bearer {token()}"}
    if body is not None:
        h["Content-Type"] = "application/json"
    if headers:
        h.update(headers)
    data = json.dumps(body).encode() if body is not None else raw
    # App Store Connect answers 5xx now and then (OpenManual, 2026-09-22); those are retried
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, method=method, headers=h, data=data)) as r:
                text = r.read()
                return json.loads(text) if text and r.headers.get("Content-Type", "").startswith("application/json") else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode()[:1200]
            if e.code >= 500 and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            sys.exit(f"HTTP {e.code} {method} {path[:90]}\n{detail}")
    sys.exit(f"no answer from {method} {path[:90]}")


def version_state():
    return call("GET", f"/v1/appStoreVersions/{VERSION}")["data"]["attributes"]


def attached_build():
    data = call("GET", f"/v1/appStoreVersions/{VERSION}/build").get("data")
    return data["attributes"]["version"] if data else None


def screenshot_sets():
    data = call("GET", f"/v1/appStoreVersionLocalizations/{VERSION_LOC}/appScreenshotSets?include=appScreenshots&limit=50")
    shots = {i["id"]: i for i in data.get("included", []) if i["type"] == "appScreenshots"}
    return [(s["id"], s["attributes"]["screenshotDisplayType"],
             [shots[r["id"]] for r in s["relationships"]["appScreenshots"]["data"] if r["id"] in shots])
            for s in data["data"]]


def status():
    v = version_state()
    print(f"version {v['versionString']} {v['appStoreState']} release={v['releaseType']} copyright={v.get('copyright')!r}")
    print("attached build:", attached_build())
    for b in call("GET", f"/v1/builds?filter[app]={APP}&filter[preReleaseVersion.version]={VERSION_STRING}&sort=-uploadedDate&limit=4")["data"]:
        a = b["attributes"]
        print(f"build {a['version']} {a['processingState']} uploaded {a['uploadedDate']} encryption={a.get('usesNonExemptEncryption')}")
    info = call("GET", f"/v1/appInfoLocalizations/{APP_INFO_LOC}")["data"]["attributes"]
    loc = call("GET", f"/v1/appStoreVersionLocalizations/{VERSION_LOC}")["data"]["attributes"]
    print("subtitle:", repr(info.get("subtitle")), "| privacy:", info.get("privacyPolicyUrl"))
    for key in ("keywords", "promotionalText", "supportUrl", "marketingUrl"):
        print(f"{key}:", repr(loc.get(key)))
    for key in ("description", "whatsNew"):
        print(f"{key}: {len(loc.get(key) or '')} characters")
    for set_id, kind, shots in screenshot_sets():
        print(f"screenshots {kind}: {[s['attributes'].get('fileName') for s in shots]}")
    for s in call("GET", f"/v1/apps/{APP}/reviewSubmissions?filter[platform]=IOS&limit=5")["data"]:
        print("submission", s["id"], s["attributes"].get("state"), s["attributes"].get("submittedDate"))


def listing(path, go):
    text = json.loads(Path(path).read_text())
    for key, limit in LIMITS.items():
        if key in text and len(text[key]) > limit:
            sys.exit(f"{key} is {len(text[key])} characters; the limit is {limit}")
    if "keywords" in text and any(len(k.strip()) == 0 for k in text["keywords"].split(",")):
        sys.exit("keywords has an empty entry")
    version_fields = {k: text[k] for k in ("description", "keywords", "promotionalText", "whatsNew", "supportUrl", "marketingUrl") if k in text}
    info_fields = {k: text[k] for k in ("subtitle",) if k in text}
    print("app info:", {k: v for k, v in info_fields.items()})
    print("version localization:", {k: (v if len(v) < 120 else f"{len(v)} characters") for k, v in version_fields.items()})
    if "copyright" in text:
        print("copyright:", text["copyright"])
    if not go:
        sys.exit("dry run; add --go")
    if info_fields:
        call("PATCH", f"/v1/appInfoLocalizations/{APP_INFO_LOC}", {"data": {
            "type": "appInfoLocalizations", "id": APP_INFO_LOC, "attributes": info_fields}})
    if version_fields:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{VERSION_LOC}", {"data": {
            "type": "appStoreVersionLocalizations", "id": VERSION_LOC, "attributes": version_fields}})
    if "copyright" in text:
        call("PATCH", f"/v1/appStoreVersions/{VERSION}", {"data": {
            "type": "appStoreVersions", "id": VERSION, "attributes": {"copyright": text["copyright"]}}})
    print("saved; read back:")
    status()


def notes(path, go):
    steps = Path(path).read_text().strip()
    current = call("GET", f"/v1/appStoreReviewDetails/{REVIEW_DETAIL}")["data"]["attributes"].get("notes") or ""
    marker = "- Steps -"
    if marker not in current:
        sys.exit("the current notes have no '- Steps -' line; edit them in App Store Connect instead")
    kept = current[:current.index(marker)].rstrip()
    print(f"keeping the {len(kept.splitlines())} credential lines above '{marker}' (not printed)")
    print(f"new steps ({len(steps)} characters):\n{steps}")
    new = f"{kept}\n{marker}\n{steps}"
    if len(new) > 4000:
        sys.exit(f"notes would be {len(new)} characters; the limit is 4000")
    if not go:
        sys.exit("dry run; add --go")
    call("PATCH", f"/v1/appStoreReviewDetails/{REVIEW_DETAIL}", {"data": {
        "type": "appStoreReviewDetails", "id": REVIEW_DETAIL, "attributes": {"notes": new}}})
    saved = call("GET", f"/v1/appStoreReviewDetails/{REVIEW_DETAIL}")["data"]["attributes"]["notes"]
    print("saved:", "kept credential lines intact" if saved.startswith(kept) else "CREDENTIAL LINES CHANGED", f"({len(saved)} characters)")


def upload(set_id, file):
    blob = file.read_bytes()
    made = call("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": file.name, "fileSize": len(blob)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    shot_id = made["data"]["id"]
    for op in made["data"]["attributes"]["uploadOperations"]:
        call(op["method"], op["url"], raw=blob[op["offset"]:op["offset"] + op["length"]], absolute=True,
             headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
    call("PATCH", f"/v1/appScreenshots/{shot_id}", {"data": {"type": "appScreenshots", "id": shot_id,
         "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    return shot_id


def shots(folder, go):
    files = sorted(Path(folder).glob("*.png"))
    if not 1 <= len(files) <= 10:
        sys.exit(f"{len(files)} PNGs in {folder}; a set takes 1 to 10")
    found = [(i, s) for i, k, s in screenshot_sets() if k == SHOT_TYPE]
    set_id, existing = found[0] if found else (None, [])
    print(f"{SHOT_TYPE}: set {set_id or '(to create)'} holds {len(existing)}; replacing with:")
    for f in files:
        print("  ", f.name, f.stat().st_size, "bytes")
    if not go:
        sys.exit("dry run; add --go")
    if not set_id:
        set_id = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": SHOT_TYPE}, "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": VERSION_LOC}}}}})["data"]["id"]
    # Resumable, as OpenManual's asc_shots.py: a processed screenshot with the same name and bytes stays
    checksums = {f.name: hashlib.md5(f.read_bytes()).hexdigest() for f in files}
    kept = {}
    for s in existing:
        a = s["attributes"]
        name = a.get("fileName")
        if (name in checksums and name not in kept and a.get("sourceFileChecksum") == checksums[name]
                and (a.get("assetDeliveryState") or {}).get("state") == "COMPLETE"):
            kept[name] = s["id"]
            print("   kept", name)
        else:
            call("DELETE", f"/v1/appScreenshots/{s['id']}")
            print("   removed", name)
    ids = dict(kept)
    for f in files:
        if f.name not in ids:
            ids[f.name] = upload(set_id, f)
            print("   uploaded", f.name)
    pending = {ids[f.name] for f in files if f.name not in kept}
    for _ in range(60):
        for sid in list(pending):
            a = call("GET", f"/v1/appScreenshots/{sid}")["data"]["attributes"]
            state = (a.get("assetDeliveryState") or {}).get("state")
            if state in ("COMPLETE", "FAILED"):
                pending.discard(sid)
                print(f"   {a.get('fileName')} {state}", (a.get("assetDeliveryState") or {}).get("errors") or "")
        if not pending:
            break
        time.sleep(5)
    call("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
         {"data": [{"type": "appScreenshots", "id": ids[f.name]} for f in files]})
    print("   ordered:", [s["attributes"].get("fileName") for _, k, ss in screenshot_sets() if k == SHOT_TYPE for s in ss])


def attach(number, go):
    builds = call("GET", f"/v1/builds?filter[app]={APP}&filter[preReleaseVersion.version]={VERSION_STRING}"
                         f"&filter[version]={number}&filter[processingState]=VALID&limit=1")["data"]
    if not builds:
        sys.exit(f"no VALID {VERSION_STRING} build {number} yet")
    a = builds[0]["attributes"]
    print(f"build {a['version']} VALID, uploaded {a['uploadedDate']}, encryption={a.get('usesNonExemptEncryption')}; attached now: {attached_build()}")
    if not go:
        sys.exit("dry run; add --go")
    call("PATCH", f"/v1/appStoreVersions/{VERSION}/relationships/build", {"data": {"type": "builds", "id": builds[0]["id"]}})
    print("attached:", attached_build())


def submit(go):
    v = version_state()
    build = attached_build()
    print(f"version {v['versionString']} {v['appStoreState']}; attached build {build}")
    if not build:
        sys.exit("no build attached")
    if v["appStoreState"] not in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"):
        sys.exit(f"version is {v['appStoreState']}; nothing to submit")
    subs = call("GET", f"/v1/apps/{APP}/reviewSubmissions?filter[platform]=IOS&limit=10")["data"]
    open_subs = [s for s in subs if s["attributes"].get("state") in OPEN]
    print("plan:", f"reuse {open_subs[0]['id']}" if open_subs else "create a submission", "add the version, submit")
    if not go:
        sys.exit("dry run; add --go")
    sub_id = open_subs[0]["id"] if open_subs else call("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]
    items = call("GET", f"/v1/reviewSubmissions/{sub_id}/items")["data"]
    if not any((i["relationships"].get("appStoreVersion", {}).get("data") or {}).get("id") == VERSION for i in items):
        call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION}}}}})
        print("added the version")
    call("PATCH", f"/v1/reviewSubmissions/{sub_id}", {"data": {"type": "reviewSubmissions", "id": sub_id,
         "attributes": {"submitted": True}}})
    time.sleep(4)
    s = call("GET", f"/v1/reviewSubmissions/{sub_id}")["data"]["attributes"]
    print(f"submission {sub_id} is {s.get('state')}; version {VERSION_STRING} is {version_state()['appStoreState']}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--go"]
    go = "--go" in sys.argv
    if not args:
        sys.exit(__doc__)
    command = args[0]
    if command == "status":
        status()
    elif command == "listing" and len(args) == 2:
        listing(args[1], go)
    elif command == "notes" and len(args) == 2:
        notes(args[1], go)
    elif command == "shots" and len(args) == 2:
        shots(args[1], go)
    elif command == "attach" and len(args) == 2:
        attach(args[1], go)
    elif command == "submit":
        submit(go)
    else:
        sys.exit(__doc__)
