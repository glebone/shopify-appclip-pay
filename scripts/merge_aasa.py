#!/usr/bin/env python3
"""Merge this project's apple-app-site-association entries into an existing AASA file.

Usage: merge_aasa.py EXISTING.json OURS.json > MERGED.json   (EXISTING may be missing or empty)

Rules: foreign entries are preserved verbatim; appclips.apps is a union; an existing
applinks.details element with the same components as ours (the /pay/* entry) is replaced,
and the App Clip ids of the parent apps it named ("<appID>.Clip") are dropped from appclips.
"""
import copy, json, sys


def merge(existing: dict, ours: dict) -> dict:
    out = copy.deepcopy(existing) if existing else {}
    details = out.setdefault("applinks", {}).setdefault("details", [])
    superseded_clips = set()
    for ours_detail in ours.get("applinks", {}).get("details", []):
        for i, existing_detail in enumerate(details):
            if existing_detail.get("components") == ours_detail.get("components"):
                superseded_clips.update(a + ".Clip" for a in existing_detail.get("appIDs", []))
                details[i] = copy.deepcopy(ours_detail)
                break
        else:
            details.append(copy.deepcopy(ours_detail))
    apps = [a for a in out.get("appclips", {}).get("apps", []) if a not in superseded_clips]
    apps = list(dict.fromkeys(apps + ours.get("appclips", {}).get("apps", [])))
    if apps:
        out["appclips"] = {"apps": apps}
    return out


def _load(path: str) -> dict:
    try:
        with open(path) as f:
            text = f.read().strip()
    except FileNotFoundError:
        return {}
    return json.loads(text) if text else {}


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(json.dumps(merge(_load(sys.argv[1]), _load(sys.argv[2])), indent=2))
