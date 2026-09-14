#!/usr/bin/env bash
set -euo pipefail

: "${COA_SERVER_DATA_DIR:=/azerothcore/env/dist/data}"

ascension_dir="$COA_SERVER_DATA_DIR/dbc/Ascension"
missing=0

for name in Appearances.dbc ItemAppearances.dbc VanityCollection.dbc; do
  path="$ascension_dir/$name"
  if [[ ! -s "$path" ]]; then
    echo "Missing required Ascension client table: $path" >&2
    missing=1
  fi
done

if (( missing )); then
  echo "Copy the three matching DBC files from the authorized CoA client-data package." >&2
  exit 1
fi

echo "Required Ascension client tables are present."
