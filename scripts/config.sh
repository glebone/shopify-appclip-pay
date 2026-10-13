#!/usr/bin/env bash
# Source this file: `source scripts/config.sh`
# Exports every KEY = value line of Config/Local.xcconfig as a shell variable.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "scripts/config.sh must be sourced from bash (zsh lacks BASH_SOURCE/BASH_REMATCH). Use: bash -c 'source scripts/config.sh && ...'" >&2
  return 1 2>/dev/null || exit 1
fi
_cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Config/Local.xcconfig"
if [[ ! -f "$_cfg" ]]; then
  echo "Missing $_cfg. Copy Config/Local.xcconfig.example and fill it in." >&2
  return 1 2>/dev/null || exit 1
fi
while IFS= read -r line; do
  line="${line%%//*}"                      # strip comments
  [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  val="${val%"${val##*[![:space:]]}"}"     # trim trailing spaces
  export "$key=$val"
done < "$_cfg"
unset _cfg line key val
