#!/usr/bin/env bash

set -euo pipefail

database="${MYSQL_DATABASE:-acore_world}"
host="${MYSQL_HOST:-ac-database}"
port="${MYSQL_PORT:-3306}"

case "$database" in
  ""|*[!A-Za-z0-9_]*)
    echo "MYSQL_DATABASE contains unsupported characters" >&2
    exit 1
    ;;
esac

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  echo "MYSQL_ROOT_PASSWORD is required" >&2
  exit 1
fi

defaults_file="$(mktemp)"
trap 'rm -f "$defaults_file"' EXIT
chmod 0600 "$defaults_file"

{
  printf '[client]\n'
  printf 'host=%s\n' "$host"
  printf 'port=%s\n' "$port"
  printf 'user=root\n'
  printf 'password=%s\n' "$MYSQL_ROOT_PASSWORD"
} > "$defaults_file"

mysql --defaults-extra-file="$defaults_file" \
  --batch \
  --skip-column-names \
  --execute="CREATE DATABASE IF NOT EXISTS \`$database\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

table_count="$(mysql --defaults-extra-file="$defaults_file" \
  --batch \
  --skip-column-names \
  --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$database';")"

if [[ "$table_count" != "0" ]]; then
  echo "$database already contains $table_count tables; CoA baseline bootstrap skipped."
  exit 0
fi

python3 apps/coa-world/world_data.py verify
python3 apps/coa-world/world_data.py bootstrap \
  --defaults-file "$defaults_file" \
  --database "$database"

echo "CoA world baseline imported successfully."
