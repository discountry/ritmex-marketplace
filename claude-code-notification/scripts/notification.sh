#!/bin/bash
# Desktop notification bridge for Claude Code and OpenAI Codex CLI.
#
# Delivery preference:
#   1. Warp (TERM_PROGRAM=WarpTerminal) → OSC 777 written to the Warp pane's PTY
#      so Warp's native notification UI renders the toast and clicking it focuses
#      Warp. Claude Code runs hooks WITHOUT a controlling terminal, so /dev/tty is
#      not openable; the device is resolved by walking the process tree up to the
#      `claude` ancestor and writing to its tty (e.g. /dev/ttys001) directly.
#   2. terminal-notifier (if installed) for other macOS terminals; attributed to
#      Warp via -sender so clicking activates Warp.
#   3. osascript fallback. Notification Center attributes these to Script Editor
#      (clicking opens Script Editor) — an unavoidable macOS limitation without
#      terminal-notifier; only reached outside Warp and without terminal-notifier.
#
# ── Claude Code ──
# Hooks receive JSON data via stdin:
# {
#   "session_id": "abc123",
#   "transcript_path": "/Users/.../.claude/projects/.../00893aaf.jsonl",
#   "cwd": "/Users/...",
#   "permission_mode": "default",
#   "hook_event_name": "Notification",
#   "message": "Claude needs your permission to use Bash",
#   "notification_type": "permission_prompt"
# }
#
# ── OpenAI Codex CLI ──
# Invoked via `notify` config with event name as $1:
#   notify = ["bash", "/path/to/notification.sh"]
# Recognised events: agent-turn-complete, complete, done, start, session-start,
#   error, fail*, permission*, approve*

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

is_codex_invocation() {
  # Codex passes the event name as $1; Claude Code sends JSON via stdin with no args.
  [ -n "${1:-}" ]
}

codex_event_to_json() {
  # Maps a Codex CLI event string to the internal hook JSON format.
  local codex_event="${1:-agent-turn-complete}"
  local event="" ntype=""

  case "$codex_event" in
    agent-turn-complete|complete|done)
      event="Stop" ;;
    start|session-start)
      event="SessionStart" ;;
    error|fail*)
      event="Stop" ;;
    permission*|approve*)
      event="Notification"; ntype="permission_prompt" ;;
    *)
      event="Stop" ;;
  esac

  local sid="codex-${CODEX_SESSION_ID:-$$}"

  printf '{"hook_event_name":"%s","notification_type":"%s","cwd":"%s","session_id":"%s","permission_mode":"","message":""}' \
    "$event" "$ntype" "$PWD" "$sid"
}

read_stdin_json() {
  # Reads stdin fully into $HOOK_JSON (global). Returns non-zero if empty.
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

sanitize_osc_payload() {
  # OSC 777 payload uses ';' as a field separator and BEL/'\007' as a terminator.
  # Strip newlines, carriage returns, semicolons, and BEL from $1.
  local s="$1"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\a'/ }"
  s="${s//;/,}"
  printf "%s" "$s"
}

is_warp_terminal() {
  [ "${TERM_PROGRAM:-}" = "WarpTerminal" ] || [ -n "${WARP_IS_LOCAL_SHELL_SESSION:-}" ]
}

resolve_terminal_device() {
  # Prints a writable terminal device for OSC notifications, or returns 1.
  #
  # Claude Code runs hooks without a controlling terminal, so /dev/tty cannot be
  # opened and the OSC sequence never reaches Warp. The Warp pane's PTY is still
  # reachable: it is the controlling tty of an ancestor process (the `claude`
  # binary), and its device node (e.g. /dev/ttys001) is owned by the user and
  # writable. Walk up the process tree to find it.

  # 1. Use the controlling terminal directly when this process actually has one
  #    (interactive runs, e.g. Codex invoking the script from a live shell).
  if { : >/dev/tty; } 2>/dev/null; then
    printf '/dev/tty'
    return 0
  fi

  # 2. Walk parent processes looking for a real, writable tty device.
  local pid="${PPID:-$$}" guard=0 tt ppid
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$guard" -lt 25 ]; do
    tt="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
    case "$tt" in
      ''|'?'|'??') : ;;
      *)
        if [ -c "/dev/$tt" ] && [ -w "/dev/$tt" ]; then
          printf '/dev/%s' "$tt"
          return 0
        fi
        ;;
    esac
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
    [ -z "$ppid" ] || [ "$ppid" = "$pid" ] && break
    pid="$ppid"
    guard=$((guard + 1))
  done
  return 1
}

notify_warp_osc777() {
  # Warp renders OSC 777 escape sequences as native desktop notifications, and a
  # click on Warp's own notification focuses Warp. Writing the sequence to the
  # resolved Warp PTY device lets the parser receive it even though the hook's
  # stdout/stderr are captured by the Claude Code hook runner.
  # Format: ESC ] 777 ; notify ; <title> ; <body> BEL
  local title body dev
  title="$(sanitize_osc_payload "$1")"
  body="$(sanitize_osc_payload "$2")"

  dev="$(resolve_terminal_device)" || return 1
  printf '\033]777;notify;%s;%s\007' "$title" "$body" >"$dev" 2>/dev/null || return 1
  return 0
}

notify_macos_terminal_notifier() {
  # Usage: notify_macos_terminal_notifier "title" "subtitle" "message" ["execute_cmd"] ["open_target"] ["icon_path"] ["sender_id"]
  local title="$1"
  local subtitle="$2"
  local body="$3"
  local execute_cmd="${4:-}"
  local open_target="${5:-}"
  local icon_path="${6:-}"
  local sender_id="${7:-}"

  local args=()
  args+=(-title "$title")
  if [ -n "$subtitle" ]; then
    args+=(-subtitle "$subtitle")
  fi
  args+=(-message "$body")

  # -sender attributes the notification to a real app (its icon, and a click
  # activates that app). When set, it is the whole click action — skip the
  # custom icon/execute/open so the click reliably focuses the terminal app.
  if [ -n "$sender_id" ]; then
    args+=(-sender "$sender_id")
    terminal-notifier "${args[@]}" >/dev/null 2>&1
    return
  fi

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

warp_bundle_id() {
  # Resolve Warp's bundle identifier (e.g. dev.warp.Warp-Stable) so a
  # terminal-notifier notification is attributed to Warp. Falls back to the
  # stable id when Spotlight metadata is unavailable.
  local id=""
  if [ -d "/Applications/Warp.app" ]; then
    id="$(mdls -name kMDItemCFBundleIdentifier -raw /Applications/Warp.app 2>/dev/null)"
  fi
  case "$id" in
    ''|'(null)') id="dev.warp.Warp-Stable" ;;
  esac
  printf '%s' "$id"
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
  if is_codex_invocation "$1"; then
    # Codex mode: synthesise JSON from the positional event argument.
    HOOK_JSON="$(codex_event_to_json "$1")"
  elif ! read_stdin_json; then
    exit 0
  fi

  parse_hook_json

  # Pick a sensible title depending on the caller.
  local title
  if is_codex_invocation "$1"; then
    title="${CODEX_NOTIFY_TITLE:-Codex}"
  else
    title="${CLAUDE_NOTIFY_TITLE:-Claude Code}"
  fi
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

  # Prefer Warp's native notifications when running inside Warp. The legacy paths
  # (terminal-notifier / osascript) are attributed to the helper binary rather than
  # Warp, and on recent Warp builds they are silently dropped because Warp's
  # revamped notifications UI (2026.04+) routes through OSC escapes.
  if is_warp_terminal; then
    local warp_title="$title"
    if [ -n "$subtitle" ]; then
      warp_title="$title — $subtitle"
    fi
    if notify_warp_osc777 "$warp_title" "$body"; then
      exit 0
    fi
  fi

  if have_cmd terminal-notifier; then
    local warp_sender=""
    if is_warp_terminal; then
      warp_sender="$(warp_bundle_id)"
    fi
    notify_macos_terminal_notifier "$title" "$subtitle" "$body" "$execute_cmd" "$open_target" "$icon_path" "$warp_sender" || true
    exit 0
  fi

  notify_macos_osascript "$title" "$subtitle" "$body" || true
}

main "$@"


