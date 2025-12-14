#!/bin/bash
# Hooks receive JSON data via stdin containing session information and event-specific data:
# {
#   "session_id": "abc123",
#   "transcript_path": "/Users/.../.claude/projects/.../00893aaf-19fa-41d2-8238-13269b9b3ca0.jsonl",
#   "cwd": "/Users/...",
#   "permission_mode": "default",
#   "hook_event_name": "Notification",
#   "message": "Claude needs your permission to use Bash",
#   "notification_type": "permission_prompt"
# }

set -o pipefail

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log_err() {
  # shellcheck disable=SC2059
  printf "%s\n" "$*" >&2
}

truncate_message() {
  # terminal-notifier / Notification Center will truncate anyway; keep it tidy.
  # Usage: truncate_message "str" [maxLen]
  local s="$1"
  local max_len="${2:-220}"
  if [ "${#s}" -le "$max_len" ]; then
    printf "%s" "$s"
    return 0
  fi
  printf "%s…" "${s:0:$((max_len - 1))}"
}

read_stdin_json() {
  # Reads stdin fully into $HOOK_JSON (global). Returns non-zero if empty.
  # Most reliable: read the full JSON payload until stdin closes.
  # This matches the official docs + common community examples.
  HOOK_JSON="$(cat)"

  if [ -z "${HOOK_JSON//$'\n'/}" ]; then
    return 1
  fi
  return 0
}

parse_hook_json() {
  # Populates globals:
  #   session_id transcript_path cwd permission_mode hook_event_name message notification_type
  # Uses jq if available, otherwise python3, otherwise best-effort.
  session_id=""
  transcript_path=""
  cwd=""
  permission_mode=""
  hook_event_name=""
  message=""
  notification_type=""

  if have_cmd jq; then
    session_id="$(printf "%s" "$HOOK_JSON" | jq -r '.session_id // ""')"
    transcript_path="$(printf "%s" "$HOOK_JSON" | jq -r '.transcript_path // ""')"
    cwd="$(printf "%s" "$HOOK_JSON" | jq -r '.cwd // ""')"
    permission_mode="$(printf "%s" "$HOOK_JSON" | jq -r '.permission_mode // ""')"
    hook_event_name="$(printf "%s" "$HOOK_JSON" | jq -r '.hook_event_name // ""')"
    message="$(printf "%s" "$HOOK_JSON" | jq -r '.message // ""')"
    notification_type="$(printf "%s" "$HOOK_JSON" | jq -r '.notification_type // ""')"
    return 0
  fi

  if have_cmd python3; then
    # Print values line-by-line; avoid eval for safety.
    # shellcheck disable=SC2016
    local parsed
    parsed="$(python3 - <<'PY'
import json, sys

try:
  data = json.load(sys.stdin)
except Exception:
  data = {}

def get(key: str) -> str:
  v = data.get(key, "")
  if v is None:
    return ""
  return str(v)

keys = [
  "session_id",
  "transcript_path",
  "cwd",
  "permission_mode",
  "hook_event_name",
  "message",
  "notification_type",
]
for k in keys:
  sys.stdout.write(get(k) + "\n")
PY
)"
    # Read 7 lines into vars (preserves spaces).
    IFS=$'\n' read -r session_id transcript_path cwd permission_mode hook_event_name message notification_type <<<"$parsed"
    return 0
  fi

  # Last resort: best-effort extraction (not a general JSON parser).
  message="$(printf "%s" "$HOOK_JSON" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n 1)"
  notification_type="$(printf "%s" "$HOOK_JSON" | sed -n 's/.*"notification_type"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n 1)"
  hook_event_name="$(printf "%s" "$HOOK_JSON" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -n 1)"
  return 0
}

notify_macos_terminal_notifier() {
  # Usage: notify_macos_terminal_notifier "title" "subtitle" "message" ["execute_cmd"] ["open_target"] ["icon_path"]
  local title="$1"
  local subtitle="$2"
  local body="$3"
  local execute_cmd="${4:-}"
  local open_target="${5:-}"
  local icon_path="${6:-}"

  local args=()
  args+=(-title "$title")
  if [ -n "$subtitle" ]; then
    args+=(-subtitle "$subtitle")
  fi
  args+=(-message "$body")

  if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
    args+=(-appIcon "$icon_path")
  fi

  # When clicked: prefer execute_cmd (e.g. focus Warp), otherwise open_target (e.g. open transcript).
  if [ -n "$execute_cmd" ]; then
    args+=(-execute "$execute_cmd")
  elif [ -n "$open_target" ]; then
    args+=(-open "$open_target")
  fi

  terminal-notifier "${args[@]}" >/dev/null 2>&1
}

notify_macos_osascript() {
  # Fallback if terminal-notifier isn't installed.
  # Usage: notify_macos_osascript "title" "subtitle" "message"
  local title="$1"
  local subtitle="$2"
  local body="$3"

  # Escape for AppleScript string literal.
  local esc_title esc_subtitle esc_body
  esc_title="${title//\\/\\\\}"; esc_title="${esc_title//\"/\\\"}"
  esc_subtitle="${subtitle//\\/\\\\}"; esc_subtitle="${esc_subtitle//\"/\\\"}"
  esc_body="${body//\\/\\\\}"; esc_body="${esc_body//\"/\\\"}"

  if have_cmd osascript; then
    # subtitle isn't universally supported; include it in the title for consistency.
    if [ -n "$esc_subtitle" ]; then
      osascript -e "display notification \"${esc_body}\" with title \"${esc_title} — ${esc_subtitle}\"" >/dev/null 2>&1
    else
      osascript -e "display notification \"${esc_body}\" with title \"${esc_title}\"" >/dev/null 2>&1
    fi
  else
    log_err "[claude-code-notification] ${title}${subtitle:+ — $subtitle}: $body"
  fi
}

focus_warp_if_possible() {
  if [ -d "/Applications/Warp.app" ]; then
    printf "%s" "osascript -e 'tell application \"Warp\" to activate'"
    return 0
  fi
  if [ -d "/System/Applications/Utilities/Terminal.app" ]; then
    printf "%s" "osascript -e 'tell application \"Terminal\" to activate'"
    return 0
  fi
  printf "%s" ""
  return 0
}

main() {
  if ! read_stdin_json; then
    exit 0
  fi

  parse_hook_json

  local title="${CLAUDE_NOTIFY_TITLE:-Claude Code}"
  local subtitle=""
  if [ -n "$notification_type" ]; then
    subtitle="$notification_type"
  elif [ -n "$hook_event_name" ]; then
    subtitle="$hook_event_name"
  fi

  local body
  if [ -n "$message" ]; then
    body="$(truncate_message "$message")"
  else
    # For events like Stop that don't include a "message" field, provide a useful default.
    case "${hook_event_name:-}" in
      Stop)
        body="$(truncate_message "Claude finished responding. Click to open the transcript.")"
        ;;
      *)
        body="$(truncate_message "Claude notification received")"
        ;;
    esac
  fi

  local icon_path=""
  if [ -d "/Applications/Warp.app" ]; then
    icon_path="/Applications/Warp.app/Contents/Resources/Warp.icns"
  fi

  local execute_cmd=""
  local open_target=""

  # Permission prompts are the most time-sensitive; focus the terminal app when clicked.
  if [ "$notification_type" = "permission_prompt" ]; then
    execute_cmd="$(focus_warp_if_possible)"
  fi

  # If we have a transcript path, make the notification open it when clicked (unless we already set execute_cmd).
  if [ -z "$execute_cmd" ] && [ -n "$transcript_path" ]; then
    open_target="$transcript_path"
  fi

  if have_cmd terminal-notifier; then
    notify_macos_terminal_notifier "$title" "$subtitle" "$body" "$execute_cmd" "$open_target" "$icon_path" || true
    exit 0
  fi

  notify_macos_osascript "$title" "$subtitle" "$body" || true
}

main "$@"


