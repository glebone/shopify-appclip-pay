#!/usr/bin/env python3
"""Merge this project's apple-app-site-association entries into an existing AASA file.

Usage: merge_aasa.py EXISTING.json OURS.json > MERGED.json   (EXISTING may be missing or empty)

Rules: foreign entries are preserved verbatim; appclips.apps is a union; an existing
applinks.details element with the same components as ours (the /pay/* entry) is replaced.
"""
import copy, json, sys


def merge(existing: dict, ours: dict) -> dict:
    out = copy.deepcopy(existing) if existing else {}
    apps = out.get("appclips", {}).get("apps", []) + ours.get("appclips", {}).get("apps", [])
    apps = list(dict.fromkeys(apps))
    if apps:
        out["appclips"] = {"apps": apps}
    details = out.setdefault("applinks", {}).setdefault("details", [])
    for ours_detail in ours.get("applinks", {}).get("details", []):
        for i, existing_detail in enumerate(details):
            if existing_detail.get("components") == ours_detail.get("components"):
                details[i] = copy.deepcopy(ours_detail)
                break
        else:
            details.append(copy.deepcopy(ours_detail))
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
