#!/usr/bin/env bash

# Shared, source-only helper for CoA's one-shot Docker database jobs.

coa_require_mysql_environment() {
  : "${COA_DB_HOST:=ac-database}"
  : "${COA_DB_PORT:=3306}"
  : "${COA_DB_USER:=root}"
  : "${COA_DB_ROOT_PASSWORD:?COA_DB_ROOT_PASSWORD must be set}"

  case "$COA_DB_ROOT_PASSWORD" in
    *$'\n'*|*$'\r'*)
      echo "COA_DB_ROOT_PASSWORD cannot contain a newline." >&2
      return 1
      ;;
  esac

  COA_MYSQL_DEFAULTS_FILE="$(mktemp)"
  chmod 600 "$COA_MYSQL_DEFAULTS_FILE"

  local escaped_password="${COA_DB_ROOT_PASSWORD//\\/\\\\}"
  escaped_password="${escaped_password//\"/\\\"}"

  {
    printf '[client]\n'
    printf 'host=%s\n' "$COA_DB_HOST"
    printf 'port=%s\n' "$COA_DB_PORT"
    printf 'protocol=tcp\n'
    printf 'user=%s\n' "$COA_DB_USER"
    printf 'password="%s"\n' "$escaped_password"
  } > "$COA_MYSQL_DEFAULTS_FILE"
}

coa_mysql() {
  mysql \
    --defaults-extra-file="$COA_MYSQL_DEFAULTS_FILE" \
    --batch \
    --raw \
    --skip-column-names \
    "$@"
}

coa_remove_mysql_defaults() {
  if [[ -n "${COA_MYSQL_DEFAULTS_FILE:-}" ]]; then
    rm -f "$COA_MYSQL_DEFAULTS_FILE"
  fi
}
