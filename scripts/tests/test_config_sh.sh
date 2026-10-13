#!/usr/bin/env bash
# Review fix 3: sourcing from zsh must fail with a message naming bash, not a misleading "Missing" error.
set -u
cd "$(dirname "$0")/../.."
out="$(zsh -c 'source scripts/config.sh' 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *bash* ]]; then echo "CONFIG_SH_GUARD_OK"; else echo "FAIL rc=$rc out=$out"; exit 1; fi
out="$(bash -c 'source scripts/config.sh && echo "$CLIP_DOMAIN"')"
[[ "$out" == "glebone.github.io" ]] && echo "CONFIG_SH_BASH_OK" || { echo "FAIL bash out=$out"; exit 1; }
