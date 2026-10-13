#!/usr/bin/env bash
# Checks the AASA file directly and through Apple's CDN (what iOS actually reads).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
echo "== direct: https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
curl -sS -o /tmp/aasa.direct -w "status=%{http_code} content-type=%{content_type} redirects=%{num_redirects}\n" \
  "https://$CLIP_DOMAIN/.well-known/apple-app-site-association"
python3 -I - <<'PY'
import json
raw = open("/tmp/aasa.direct").read()
try:
    d = json.loads(raw)
except ValueError:
    print("NOT JSON. Body starts:", raw[:200]); raise SystemExit(1)
apps = d.get("appclips", {}).get("apps")
if apps:
    print("appclips:", apps)
else:
    print("NO appclips KEY YET (Pages build may still be running; retry in a minute). Keys:", list(d))
    raise SystemExit(1)
PY
echo "== apple cdn: https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN"
curl -sS -w "\nstatus=%{http_code}\n" "https://app-site-association.cdn-apple.com/a/v1/$CLIP_DOMAIN" | head -c 800; echo
echo "== landing page meta"
curl -sS "https://$CLIP_DOMAIN/pay/?v=1" | grep -o '<meta name="apple-itunes-app"[^>]*>'
