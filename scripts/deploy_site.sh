#!/usr/bin/env bash
# Deploys site/ additively into the glebone.github.io Pages repo (legacy Pages: branch main, root).
# Writes only: .well-known/apple-app-site-association (MERGED with what is already there, see
# scripts/merge_aasa.py), pay/index.html, preview.png. Everything else in that repo is left untouched.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/config.sh"
PAGES_REPO="${PAGES_REPO:-glebone/glebone.github.io}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
gh repo clone "$PAGES_REPO" "$work/pages" -- --quiet --depth 1
mkdir -p "$work/pages/.well-known" "$work/pages/pay"
python3 -I "$root/scripts/merge_aasa.py" \
  "$work/pages/.well-known/apple-app-site-association" \
  "$root/site/.well-known/apple-app-site-association" > "$work/merged.json"
cp "$work/merged.json" "$work/pages/.well-known/apple-app-site-association"
cp "$root/site/pay/index.html" "$work/pages/pay/index.html"
cp "$root/site/preview.png" "$work/pages/preview.png"
touch "$work/pages/.nojekyll"
cd "$work/pages"
git add -A
if git diff --cached --quiet; then echo "Pages repo already up to date."; exit 0; fi
echo "== changes about to be pushed to $PAGES_REPO:"
git --no-pager diff --cached --stat
git --no-pager diff --cached -- .well-known/apple-app-site-association
git commit -q -m "App Clip pay demo: AASA appclips entry, /pay/ landing page, preview image ($CLIP_DOMAIN)"
git push -q origin HEAD
echo "Deployed to $PAGES_REPO. Legacy Pages build takes about a minute; then run scripts/check_aasa.sh"
