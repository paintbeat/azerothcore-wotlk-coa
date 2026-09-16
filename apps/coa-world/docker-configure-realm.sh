#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=apps/coa-world/docker-mysql-client.sh
source "$SCRIPT_DIR/docker-mysql-client.sh"

: "${COA_AUTH_DATABASE:=acore_auth}"
: "${COA_REALM_NAME:=Conquest of Azeroth}"
: "${COA_REALM_ADDRESS:?COA_REALM_ADDRESS must be set}"
: "${COA_REALM_LOCAL_ADDRESS:=$COA_REALM_ADDRESS}"
: "${COA_REALM_LOCAL_SUBNET_MASK:=255.255.255.0}"
: "${COA_WORLD_PORT:=8085}"

if [[ ! "$COA_AUTH_DATABASE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "COA_AUTH_DATABASE is not a valid MySQL identifier." >&2
  exit 1
fi

if [[ "$COA_REALM_NAME" == *$'\n'* || "$COA_REALM_NAME" == *$'\r'* ||
  ! "$COA_REALM_NAME" =~ ^[A-Za-z0-9._[:space:]-]+$ ]]; then
  echo "COA_REALM_NAME contains unsupported characters." >&2
  exit 1
fi

for value in "$COA_REALM_ADDRESS" "$COA_REALM_LOCAL_ADDRESS" "$COA_REALM_LOCAL_SUBNET_MASK"; do
  if [[ ! "$value" =~ ^[A-Za-z0-9.:-]+$ ]]; then
    echo "A realm address or subnet value contains unsupported characters." >&2
    exit 1
  fi
done

if [[ ! "$COA_WORLD_PORT" =~ ^[0-9]+$ || ${#COA_WORLD_PORT} -gt 5 ]]; then
  echo "COA_WORLD_PORT must be between 1 and 65535." >&2
  exit 1
fi

world_port_number=$((10#$COA_WORLD_PORT))
if (( world_port_number < 1 || world_port_number > 65535 )); then
  echo "COA_WORLD_PORT must be between 1 and 65535." >&2
  exit 1
fi

coa_require_mysql_environment
trap coa_remove_mysql_defaults EXIT

realm_count="$(
  coa_mysql \
    --database="$COA_AUTH_DATABASE" \
    --execute="SELECT COUNT(*) FROM realmlist WHERE id = 1;"
)"

if [[ "$realm_count" != "1" ]]; then
  echo "Realm id 1 is missing from $COA_AUTH_DATABASE.realmlist." >&2
  exit 1
fi

coa_mysql \
  --database="$COA_AUTH_DATABASE" \
  --execute="UPDATE realmlist
    SET name = '$COA_REALM_NAME',
        address = '$COA_REALM_ADDRESS',
        localAddress = '$COA_REALM_LOCAL_ADDRESS',
        localSubnetMask = '$COA_REALM_LOCAL_SUBNET_MASK',
        port = $world_port_number
    WHERE id = 1;"

echo "Realm id 1 configured as '$COA_REALM_NAME' at $COA_REALM_ADDRESS:$COA_WORLD_PORT."
