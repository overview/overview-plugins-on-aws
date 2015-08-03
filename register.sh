#!/bin/sh
#
# See README.md for usage.

NAME=$1
PORT=$2
MEMORY_LIMIT=$3

DATABASE="$(dirname "$0")"/plugins.txt

if [ -z "$NAME" ] \
  || [ -z "$PORT" ] \
  || [ -z "$MEMORY_LIMIT" ] \
  || [ "$PORT" -lt 3000 ] \
  || [ "$PORT" -gt 3999 ] \
  || [ "$MEMORY_LIMIT" -lt 100 ] \
  || [ "$MEMORY_LIMIT" -gt 5000 ]; then

  echo >&2 "Usage: $0 [name] [port] [memory_limit]"
  echo >&2
  echo >&2 "Where:"
  echo >&2 "  [name] is a single word with no spaces"
  echo >&2 "  [port] is an integer between 3000 and 3999"
  echo >&2 "  [memory_limit] is an integer between 100 and 5000 (megabytes)"
  exit 1
fi

if `grep -v '^#' "$DATABASE" | grep -c " $NAME " >/dev/null`; then
  echo >&2 "The plugin $NAME is already registered in plugins.txt:"
  echo >&2
  grep -v '^#' "$DATABASE" | grep " $NAME " >&2
  exit 1
fi

if `grep -c "^$PORT" "$DATABASE" >/dev/null`; then
  echo >&2 "The port $PORT is already registered in plugins.txt:"
  echo >&2
  grep "^$PORT" "$DATABASE" >&2
  exit 1
fi

echo "$PORT $NAME $MEMORY_LIMIT" >> "$DATABASE"
