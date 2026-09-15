#!/usr/bin/env bash

set -euo pipefail

version="${AC_CLIENT_DATA_VERSION:-v20.0}"
data_path="${DATAPATH:-/azerothcore/env/dist/data}"
zip_path="${DATAPATH_ZIP:-$data_path/data.zip}"
version_file="$data_path/data-version"

mkdir -p "$data_path"

installed_version=""
if [[ -f "$version_file" ]]; then
    installed_version=$(sed -n 's/^INSTALLED_VERSION=//p' "$version_file" | head -n 1)
fi

if [[ "$installed_version" == "$version" ]]; then
    echo "Client data $version is already installed."
    exit 0
fi

echo "#######################"
echo "Client data downloader"
echo "#######################"
echo "Downloading client data $version to $zip_path ..."

trap 'rm -f "$zip_path"' EXIT

curl --fail --location \
    --retry 5 \
    --retry-delay 3 \
    --retry-connrefused \
    "https://github.com/wowgaming/client-data/releases/download/$version/data.zip" \
    --output "$zip_path"

echo "Extracting client data into $data_path ..."
unzip -q -o "$zip_path" -d "$data_path/"

printf 'INSTALLED_VERSION=%s\n' "$version" > "$version_file"
rm -f "$zip_path"
trap - EXIT

echo "Client data $version installed successfully."
