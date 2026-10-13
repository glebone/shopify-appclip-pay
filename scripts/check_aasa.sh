#!/usr/bin/env bash
# Checks the AASA file directly and through Apple's CDN (what iOS actually reads), and the
# landing page meta tag, against the ids in Config/Local.xcconfig. Exits 1 until all three
# carry the configured clip id (Pages build takes about a minute; Apple's CDN can lag longer).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
clip_id="$DEVELOPMENT_TEAM.$APP_BUNDLE_ID.Clip"
work="$(mktemp -d)"
ok=1

echo "== direct: https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
curl -sS -o "$work/direct" -w "status=%{http_code} content-type=%{content_type} redirects=%{num_redirects}\n" \
  "https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
if python3 -I - "$work/direct" "$clip_id" <<'PY'
import json, sys
raw = open(sys.argv[1]).read()
try:
    d = json.loads(raw)
except ValueError:
    print("NOT JSON. Body starts:", raw[:200]); raise SystemExit(1)
apps = d.get("appclips", {}).get("apps") or []
print("appclips:", apps)
if sys.argv[2] not in apps:
    print("MISSING", sys.argv[2], "(Pages build may still be running; retry in a minute)"); raise SystemExit(1)
PY
then :; else ok=0; fi

echo "== apple cdn: https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN"
curl -sS -o "$work/cdn" -w "status=%{http_code}\n" "https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN"
head -c 800 "$work/cdn"; echo
if grep -q "$clip_id" "$work/cdn"; then echo "cdn has $clip_id"; else echo "CDN MISSING $clip_id (Apple re-fetches on its own schedule)"; ok=0; fi

echo "== landing page meta"
meta="$(curl -sS "https://$CLIP_DOMAIN/pay/?v=1" | grep -o '<meta name="apple-itunes-app"[^>]*>' || true)"
echo "$meta"
case "$meta" in
  *"app-id=$APP_STORE_ID, app-clip-bundle-id=$APP_BUNDLE_ID.Clip"*) ;;
  *) echo "META MISMATCH (expected app-id=$APP_STORE_ID, app-clip-bundle-id=$APP_BUNDLE_ID.Clip)"; ok=0 ;;
esac

rm -rf "$work"
[ "$ok" = 1 ] && echo "AASA_OK" || exit 1
