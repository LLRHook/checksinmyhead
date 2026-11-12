#!/usr/bin/env python3
"""Inspect a locally built viewer. Never requests a non-loopback application.

Fixtures are task-owned JSON: {"records": [{"kind": "bill" | "tab", "id": ...,
"label": ..., "name": ..., "token": ...}]}. This is HTTP/RSC evidence; a headed
browser and the real isolated backend remain separate required checks.
"""

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import struct
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ORIGIN = "https://billingtonapp.vercel.app"
STORE = "https://apps.apple.com/app/id6746379502"
MAIL = "mailto:checkmateapp@duck.com"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Synthetic capabilities must never follow a redirect outside the fixture.
        return None


class Page(HTMLParser):
    def __init__(self, raw):
        super().__init__()
        self.tags, self.text, self.json_ld = [], [], []
        self.title, self.titles, self.ids = False, [], set()
        self.skip = 0
        self.json_script = False
        self.feed(raw)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if tag == "title":
            self.title = True
        if tag in ("script", "style"):
            self.skip += 1
        if tag == "script" and attrs.get("type") == "application/ld+json":
            self.json_script = True

    def handle_endtag(self, tag):
        if tag in ("p", "h1", "h2", "h3", "div", "section", "li", "dt", "dd") and not self.skip:
            self.text.append(" ")
        if tag == "title":
            self.title = False
        if tag in ("script", "style"):
            self.skip -= 1
            self.json_script = False

    def handle_data(self, value):
        if self.title:
            self.titles.append(value)
        elif self.json_script:
            self.json_ld.append(value)
        elif not self.skip:
            self.text.append(value)

    def values(self, tag, key, value, result):
        return [attrs.get(result) for kind, attrs in self.tags
                if kind == tag and attrs.get(key) == value]


def public_checks(raw, headers, path):
    page = Page(raw)
    canonical = ORIGIN + (path if path != "/" else "")
    text = " ".join("".join(page.text).split())
    mail = [a.get("href") for t, a in page.tags
            if t == "a" and a.get("href", "").startswith("mailto:")]
    ctas = [a["href"] for t, a in page.tags
            if t == "a" and "apps.apple.com" in a.get("href", "")]
    robots = page.values("meta", "name", "robots", "content")
    checks = {
        "singleTitle": len(page.titles) == 1,
        "canonical": page.values("link", "rel", "canonical", "href") == [canonical],
        "publicIndexing": robots == ["index, follow"] and headers.get("x-robots-tag") == "index, follow",
        "socialURL": page.values("meta", "property", "og:url", "content") == [canonical],
        "socialImage": page.values("meta", "property", "og:image", "content") == [ORIGIN + "/social-image.png"],
        "socialImageAlt": bool(page.values("meta", "property", "og:image:alt", "content")),
        "twitterCard": page.values("meta", "name", "twitter:card", "content") == ["summary_large_image"],
        "twitterImage": page.values("meta", "name", "twitter:image", "content") == [ORIGIN + "/social-image.png"],
        "directStoreCTAs": bool(ctas) and all(link == STORE for link in ctas),
        "bareContact": bool(mail) and set(mail) == {MAIL},
        "fullPolicyLink": "/privacy-policy" in [a.get("href") for t, a in page.tags if t == "a"],
        "noDraftOrInventedDate": not any(word in text.lower() for word in ("candidate only", "draft policy", "effective november", "effective october", "publication instructions")),
        "manualPayments": "Payments happen outside Billington." in text,
    }
    if path == "/":
        checks["homeAnchors"] = {"features", "how-it-works", "privacy", "download"} <= page.ids
        checks["completeExample"] = all(value in text for value in (
            "Example split", "$100.00", "$10.00", "$18.00", "$128.00", "Ari", "$51.20", "Sam", "$44.80", "Jo", "$32.00"))
        data = json.loads(page.json_ld[0]) if len(page.json_ld) == 1 else {}
        checks["boundedSoftwareData"] = (
            data.get("@type") == "SoftwareApplication" and data.get("name") == "Billington"
            and data.get("operatingSystem") == "iOS" and data.get("applicationCategory") == "FinanceApplication"
            and data.get("url") == ORIGIN and data.get("downloadUrl") == STORE
            and data.get("description", "MISSING") in text
            and not {"offers", "aggregateRating", "review", "softwareVersion"} & data.keys())
    else:
        checks["noAcquisitionSchemaOnPolicy"] = not page.json_ld
        checks["completePolicy"] = all(value in text for value in (
            "Billington Privacy Policy",
            "This policy describes Billington version 1.4.0, the version available on the App Store, and the Billington service as it currently runs.",
            "In version 1.4.0, saving a finished bill sends it to Billington's service automatically, whether or not you share its link.",
            "Version 1.4.0 does not convert currencies.",
            "that statement can contain bill content or access credentials",
            "Shared access links do not automatically expire.",
            "within 30 days, with exceptions", "We do not sell bill or tab content.",
            "A change to the app or service does not by itself erase existing logs.",
            "There is no in-app control for deleting an entire shared online bill or tab.",
            "We do not promise that uninstalling erases every credential or backup copy."))
    return checks


def rsc_metadata(raw):
    tags, titles = [], []

    def walk(value):
        if isinstance(value, list):
            if len(value) == 4 and value[0] == "$" and isinstance(value[3], dict):
                if value[1] == "title":
                    titles.append(value[3].get("children"))
                elif value[1] in ("meta", "link"):
                    tags.append((value[1], value[3]))
            for child in value:
                walk(child)
        elif isinstance(value, dict):
            for child in value.values():
                walk(child)

    for line in raw.splitlines():
        try:
            walk(json.loads(line.split(":", 1)[1]))
        except (ValueError, IndexError):
            pass
    return tags, titles


def private_checks(raw, headers, sensitive, rsc=False):
    page = Page(raw) if not rsc else None
    tags, titles = rsc_metadata(raw) if rsc else (page.tags, page.titles)
    metadata = [(t, a) for t, a in tags if t in ("meta", "link")
                and (t == "meta" or a.get("rel") == "canonical")]
    serialized = json.dumps([metadata, titles])
    robots = [a.get("content", "") for t, a in tags if t == "meta" and a.get("name") == "robots"]
    return {
        "genericTitle": "Billington" in titles,
        "noPrivateAcquisitionData": all(value not in serialized for value in sensitive),
        "noPublicCanonicalOrSocial": not any(
            a.get("rel") == "canonical" or a.get("property", "").startswith("og:")
            or a.get("name", "").startswith("twitter:") for _, a in tags),
        "noJSONLD": "application/ld+json" not in raw,
        "metadataNoindex": "noindex, nofollow" in robots,
        "httpNoindex": {"noindex", "nofollow", "nosnippet", "noimageindex"} <= set(headers.get("x-robots-tag", "").replace(" ", "").split(",")),
        "noReferrer": headers.get("referrer-policy") == "no-referrer" and any(a.get("name") == "referrer" and a.get("content") == "no-referrer" for _, a in tags),
        "privateNoStore": all(v in headers.get("cache-control", "") for v in ("private", "no-store")),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path)
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--api-log", type=Path, help="owned fixture JSONL request log")
    args = parser.parse_args()
    origin = urllib.parse.urlsplit(args.base_url)
    if origin.scheme != "http" or origin.hostname not in ("127.0.0.1", "localhost", "::1") or origin.query or origin.username or origin.password:
        parser.error("a plain loopback HTTP origin is required")
    args.output.mkdir(parents=True, exist_ok=False)
    rows = []
    records = json.loads(args.fixtures.read_text())["records"] if args.fixtures else []
    sensitive = [value for record in records for value in (record["name"], record["token"])]
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(label, path, headers=None):
        req = urllib.request.Request(args.base_url.rstrip("/") + path, headers=headers or {})
        try:
            response = opener.open(req, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        body = response.read(8 * 1024 * 1024 + 1)
        if len(body) > 8 * 1024 * 1024:
            raise ValueError("owned fixture response exceeds verifier's 8 MiB limit")
        hdrs = {k.lower(): v for k, v in response.headers.items()}
        (args.output / (label + ".body")).write_bytes(body)
        return response.status, hdrs, body

    for path, label in (("/", "home"), ("/privacy-policy", "policy")):
        status, headers, body = request(label, path)
        checks = public_checks(body.decode(), headers, path)
        checks.update(status=status == 200, noPrivateData=all(v.encode() not in body for v in sensitive))
        rows.append({"id": label, "status": status, "headers": headers, "checks": checks})
    status, headers, body = request("robots", "/robots.txt")
    rows.append({"id": "robots", "checks": {"status": status == 200, "readPrivateNoindex": "Allow: /" in body.decode() and "Disallow:" not in body.decode(), "sitemap": "Sitemap: " + ORIGIN + "/sitemap.xml" in body.decode()}})
    status, headers, body = request("sitemap", "/sitemap.xml")
    if len(body) > 65536 or any(value in body.upper() for value in (b"<!DOCTYPE", b"<!ENTITY")):
        raise ValueError("sitemap must be bounded XML without DTD or entities")
    xml = ET.fromstring(body)
    rows.append({"id": "sitemap", "checks": {"status": status == 200, "onlyPublicDocuments": [e.text for e in xml.iter() if e.tag.endswith("}loc")] == [ORIGIN, ORIGIN + "/privacy-policy"], "noInventedDates": not any(e.tag.endswith("}lastmod") for e in xml.iter())}})
    status, headers, body = request("social", "/social-image.png")
    rows.append({"id": "social", "checks": {"status": status == 200, "PNG": body.startswith(b"\x89PNG\r\n\x1a\n"), "dimensions": struct.unpack(">II", body[16:24]) == (1200, 630), "noPrivateData": all(v.encode() not in body for v in sensitive)}})
    status, _, _ = request("removed-privacy", "/privacy")
    rows.append({"id": "removed-privacy", "checks": {"notRevived": status == 404}})
    for bot in (False, True):
        for rsc in (False, True):
            for index, record in enumerate(records):
                other = records[(index + 1) % len(records)]["token"]
                for state, token in (("valid", record["token"]), ("wrong-record", other), ("invalid", "synthetic-invalid"), ("empty", ""), ("missing", None), ("valid-again", record["token"])):
                    label = f"{record['label']}-{'bot' if bot else 'ordinary'}-{'rsc' if rsc else 'html'}-{state}"
                    path = f"/{'b' if record['kind'] == 'bill' else 't'}/{record['id']}"
                    if token is not None:
                        path += "?" + urllib.parse.urlencode({"t": token})
                    headers = {"User-Agent": "Twitterbot/1.0" if bot else "WebRouteQualification/1.0"}
                    if rsc:
                        headers.update({"RSC": "1", "Accept": "text/x-component"})
                    before = len(args.api_log.read_text().splitlines()) if args.api_log else 0
                    status, headers, body = request(label, path, headers)
                    text = body.decode()
                    checks = private_checks(text, headers, sensitive, rsc)
                    checks["status"] = status == 200
                    if record["kind"] == "tab" and state.startswith("valid"):
                        checks["authorizedNameVisible"] = record.get("visibleName", record["name"]) in text
                    elif not state.startswith("valid"):
                        checks["noAuthorizedBody"] = record["name"] not in text
                    if args.api_log:
                        calls = [json.loads(line) for line in args.api_log.read_text().splitlines()[before:]]
                        if state in ("missing", "empty") or record["kind"] == "bill":
                            checks["noMetadataResourceLookup"] = not calls
                        else:
                            checks["independentBearerReads"] = bool(calls) and all(call["headers"].get("Authorization") == ["Bearer " + token] and not call["query"] for call in calls)
                            if not state.startswith("valid"):
                                checks["unauthorizedNoCollections"] = [c["path"] for c in calls] == [f"/api/tabs/{record['id']}"]
                    rows.append({"id": label, "status": status, "headers": headers, "sha256": hashlib.sha256(body).hexdigest(), "checks": checks})
    if args.build_dir:
        files = [p for p in args.build_dir.rglob("*") if p.is_file()]
        leaks = [str(p.relative_to(args.build_dir)) for p in files if any(value.encode() in p.read_bytes() for value in sensitive)]
        rows.append({"id": "static-artifacts", "files": len(files), "checks": {"noPrivateBuildData": not leaks}, "leaks": leaks})
    failed = [{"id": row["id"], "check": key} for row in rows for key, value in row["checks"].items() if not value]
    result = {"base": args.base_url, "rows": rows, "failed": failed, "browser": "separate required proof", "realBackend": "caller must bind fixture/source/schema evidence"}
    (args.output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"cases": len(rows), "failed": failed}))
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
