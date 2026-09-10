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

# Parse --key=value args and store as _OPT_KEY variables.
# Call once near the top of each subcommand: parse_opts "$@"
parse_opts() {
    local _a _key _val
    for _a in "$@"; do
        if [[ "$_a" == --*=* ]]; then
            _key="${_a%%=*}"
            _key="${_key#--}"
            _key="${_key//-/_}"
            _key="${_key^^}"
            _val="${_a#*=}"
            printf -v "_OPT_${_key}" '%s' "$_val"
        elif [[ "$_a" == --yes ]]; then
            printf -v "_OPT_YES" '%s' "y"
        fi
    done
}

# Return the value supplied via --key=value, or empty string.
get_opt() {
    local _varname
    _varname="_OPT_$(printf '%s' "${1//-/_}" | tr '[:lower:]' '[:upper:]')"
    printf '%s' "${!_varname:-}"
}
