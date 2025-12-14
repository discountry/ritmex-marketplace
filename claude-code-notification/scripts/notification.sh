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

DEBUG_LOG="${CLAUDE_NOTIFY_DEBUG_LOG:-}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log_err() {
  # shellcheck disable=SC2059
  printf "%s\n" "$*" >&2
}

log_debug() {
  # Enable by setting: CLAUDE_NOTIFY_DEBUG_LOG=/path/to/logfile
  # Keep this best-effort; never break hook execution.
  if [ -z "$DEBUG_LOG" ]; then
    return 0
  fi
  {
    printf "%s %s\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
  } >>"$DEBUG_LOG" 2>/dev/null || true
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
  log_debug "notification.sh invoked (pid=$$)"

  # In practice, Claude Code writes a small JSON payload to stdin.
  # Some environments appear to keep the pipe open briefly; plain `cat` waits for EOF,
  # which can add several seconds of delay. Prefer a non-blocking read.
  if have_cmd python3; then
    # Read until stdin is idle for a short time (or max time reached), without requiring EOF.
    # Keeps this fast while still allowing multi-chunk writes.
    HOOK_JSON="$(python3 - <<'PY'
import sys, time, select

MAX_BYTES = 256 * 1024
MAX_TOTAL_SECONDS = 1.5
IDLE_AFTER_FIRST_BYTE_SECONDS = 0.075

buf = bytearray()
start = time.monotonic()
last_read = None

stdin = sys.stdin.buffer
fd = stdin.fileno()

while True:
  now = time.monotonic()
  if now - start > MAX_TOTAL_SECONDS:
    break

  # If we've started receiving data and it's been idle long enough, stop.
  if last_read is not None and (now - last_read) > IDLE_AFTER_FIRST_BYTE_SECONDS:
    break

  timeout = 0.05
  r, _, _ = select.select([fd], [], [], timeout)
  if not r:
    continue

  chunk = stdin.read1(8192) if hasattr(stdin, "read1") else stdin.read(8192)
  if not chunk:
    # EOF
    break
  buf.extend(chunk)
  last_read = time.monotonic()

  if len(buf) >= MAX_BYTES:
    break

sys.stdout.write(buf.decode("utf-8", errors="replace"))
PY
)"
  else
    HOOK_JSON="$(cat)"
  fi

  if [ -z "${HOOK_JSON//$'\n'/}" ]; then
    log_debug "stdin empty; exiting"
    return 1
  fi
  log_debug "stdin received (${#HOOK_JSON} bytes)"
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
  log_debug "parsed hook_event_name=${hook_event_name:-} notification_type=${notification_type:-} transcript_path=${transcript_path:-}"

  local title="${CLAUDE_NOTIFY_TITLE:-Claude Code}"
  local subtitle=""
  if [ -n "$notification_type" ]; then
    subtitle="$notification_type"
  elif [ -n "$hook_event_name" ]; then
    subtitle="$hook_event_name"
  fi

  local body
  body="$(truncate_message "${message:-Claude notification received}")"

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
    log_debug "using terminal-notifier"
    notify_macos_terminal_notifier "$title" "$subtitle" "$body" "$execute_cmd" "$open_target" "$icon_path" || true
    exit 0
  fi

  log_debug "using osascript fallback"
  notify_macos_osascript "$title" "$subtitle" "$body" || true
}

main "$@"


