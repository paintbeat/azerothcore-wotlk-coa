#!/usr/bin/env bash
set -euo pipefail

: "${COA_SERVER_DATA_DIR:=/azerothcore/env/dist/data}"

ascension_dir="$COA_SERVER_DATA_DIR/dbc/Ascension"
invalid=0

declare -A expected_sha256=(
  [Appearances.dbc]="7c7b27fa9e535d7ec7549eb61ef1490ec69b990fa243a2ed36fb6dbf7df118f9"
  [ItemAppearances.dbc]="c2533eaa0c84ccb35e1087b6244e8881f89642385e646a9f7fc6dddf1e6ea434"
  [VanityCollection.dbc]="aae91e8c4966790be090c1a69d124745aca4bfa4a09f43b52f0789667c98d46c"
)

for name in Appearances.dbc ItemAppearances.dbc VanityCollection.dbc; do
  path="$ascension_dir/$name"
  if [[ ! -s "$path" ]]; then
    echo "Missing required Ascension client table: $path" >&2
    invalid=1
    continue
  fi

  actual_sha256="$(sha256sum "$path" | awk '{print $1}')"
  if [[ "$actual_sha256" != "${expected_sha256[$name]}" ]]; then
    echo "Ascension client table does not match the validated patch-M.MPQ snapshot: $path" >&2
    echo "Expected SHA256: ${expected_sha256[$name]}" >&2
    echo "Actual SHA256:   $actual_sha256" >&2
    invalid=1
  fi
done

if (( invalid )); then
  echo "Extract the matching files from DBFilesClient in the authorized CoA patch-M.MPQ." >&2
  exit 1
fi

echo "Required Ascension client tables match the validated patch-M.MPQ snapshot."
