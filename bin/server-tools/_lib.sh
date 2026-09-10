#!/usr/bin/env bash
# Shared helpers sourced by all server-tools subcommands.
# Do not execute directly.

JSON_MODE=false
_JSON_EVENTS=()

log() {
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    if $JSON_MODE; then
        _JSON_EVENTS+=("{\"timestamp\":$(json_str "$ts"),\"message\":$(json_str "$1")}")
    else
        echo "$ts - $1"
    fi
}

# Escape a value as a JSON string literal (double-quoted).
json_str() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
}

# Emit the buffered log events as a JSON array.
json_events_array() {
    local first=true
    printf '['
    for e in "${_JSON_EVENTS[@]+"${_JSON_EVENTS[@]}"}"; do
        $first || printf ','
        printf '%s' "$e"
        first=false
    done
    printf ']'
}
