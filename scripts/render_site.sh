#!/usr/bin/env bash
# Renders site-src/*.tmpl into site/ using values from Config/Local.xcconfig.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"

render() {
  sed -e "s|__TEAM_ID__|$DEVELOPMENT_TEAM|g" \
      -e "s|__APP_BUNDLE_ID__|$APP_BUNDLE_ID|g" \
      -e "s|__CLIP_DOMAIN__|$CLIP_DOMAIN|g" \
      -e "s|__APP_STORE_ID__|$APP_STORE_ID|g" "$1"
}

mkdir -p "$root/site/.well-known" "$root/site/pay"
render "$root/site-src/apple-app-site-association.tmpl" > "$root/site/.well-known/apple-app-site-association"
render "$root/site-src/pay.html.tmpl" > "$root/site/pay/index.html"
python3 -I "$root/scripts/make_preview.py" "$root/site/preview.png"
echo "Rendered site/ for $CLIP_DOMAIN (team $DEVELOPMENT_TEAM, bundle $APP_BUNDLE_ID, app id $APP_STORE_ID)"
