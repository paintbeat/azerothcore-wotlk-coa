#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=apps/coa-world/docker-mysql-client.sh
source "$SCRIPT_DIR/docker-mysql-client.sh"

: "${COA_WORLD_DATABASE:=acore_world}"

if [[ ! "$COA_WORLD_DATABASE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "COA_WORLD_DATABASE is not a valid MySQL identifier." >&2
  exit 1
fi

coa_require_mysql_environment
trap coa_remove_mysql_defaults EXIT

coa_mysql --execute="CREATE DATABASE IF NOT EXISTS \`$COA_WORLD_DATABASE\` CHARACTER SET utf8mb4;"

table_count="$(
  coa_mysql \
    --database="$COA_WORLD_DATABASE" \
    --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE();"
)"

if [[ "$table_count" == "0" ]]; then
  python3 "$SCRIPT_DIR/world_data.py" verify
  python3 "$SCRIPT_DIR/world_data.py" bootstrap \
    --defaults-file "$COA_MYSQL_DEFAULTS_FILE" \
    --database "$COA_WORLD_DATABASE"
  echo "CoA world baseline installed successfully."
  exit 0
fi

required_tables="$(
  coa_mysql \
    --database="$COA_WORLD_DATABASE" \
    --execute="SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name IN ('creature_template', 'updates', 'version');"
)"

if [[ "$required_tables" != "3" ]]; then
  echo "The CoA world schema is non-empty but incomplete." >&2
  echo "Recreate only '$COA_WORLD_DATABASE' before retrying the initial deployment." >&2
  exit 1
fi

echo "Existing CoA world schema detected; bootstrap is not being reapplied."
