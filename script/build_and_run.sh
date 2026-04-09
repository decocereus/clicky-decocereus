#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/leanring-buddy.xcodeproj"
WORKSPACE_NAME="leanring-buddy.xcodeproj"
SCHEME_NAME="leanring-buddy"
RUN_DESTINATION_NAME="My Mac"
APP_NAME="Clicky"
BUNDLE_ID="com.yourcompany.leanring-buddy"

usage() {
  cat <<'EOF'
usage: ./script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify]
EOF
}

stop_existing_app() {
  /usr/bin/osascript <<APPLESCRIPT >/dev/null
tell application "Xcode"
  if exists workspace document "${WORKSPACE_NAME}" then
    try
      stop workspace document "${WORKSPACE_NAME}"
    end try
  end if
end tell
APPLESCRIPT

  /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

run_xcode_action() {
  local action="$1"

  /usr/bin/osascript <<APPLESCRIPT
on joinList(itemList, delimiter)
  set oldTIDs to AppleScript's text item delimiters
  set AppleScript's text item delimiters to delimiter
  set joinedText to itemList as text
  set AppleScript's text item delimiters to oldTIDs
  return joinedText
end joinList

on tailLines(sourceText, lineCount)
  set sourceLines to paragraphs of sourceText
  set totalLines to count of sourceLines
  if totalLines is 0 then return ""
  if totalLines is less than or equal to lineCount then return my joinList(sourceLines, linefeed)

  set tailStart to (totalLines - lineCount) + 1
  set tailItems to items tailStart thru totalLines of sourceLines
  return my joinList(tailItems, linefeed)
end tailLines

on summarizeActionResult(actionResult)
  tell application "Xcode"
    set currentStatus to (status of actionResult) as text
  end tell

  set issueSummary to "Check Xcode's Report navigator for detailed diagnostics."

  return "status=" & currentStatus & linefeed & issueSummary
end summarizeActionResult

on selectScheme(docRef)
  repeat 120 times
    try
      tell application "Xcode"
        set active scheme of docRef to scheme "${SCHEME_NAME}" of docRef
      end tell
      return
    end try
    delay 0.5
  end repeat

  error "Xcode did not expose scheme ${SCHEME_NAME} within 60 seconds."
end selectScheme

on waitForSchemeActionCompletion(actionResult)
  repeat 1200 times
    tell application "Xcode"
      if completed of actionResult is true then exit repeat
    end tell
    delay 0.5
  end repeat

  tell application "Xcode"
    if completed of actionResult is false then
      return "ERROR|Timed out waiting for the Xcode action to finish."
    end if

    set currentStatus to (status of actionResult) as text
  end tell

  if currentStatus is "succeeded" then return "OK|succeeded"

  return "ERROR|" & my summarizeActionResult(actionResult)
end waitForSchemeActionCompletion

on waitForSchemeActionStartOrFail(actionResult)
  repeat 240 times
    tell application "Xcode"
      set currentStatus to (status of actionResult) as text
      if currentStatus is "running" then return "OK|running"

      if completed of actionResult is true then
        if currentStatus is "succeeded" then return "OK|succeeded"
        return "ERROR|" & my summarizeActionResult(actionResult)
      end if
    end tell

    delay 0.5
  end repeat

  return "ERROR|Timed out waiting for Xcode to launch ${APP_NAME}."
end waitForSchemeActionStartOrFail

tell application "Xcode"
  activate
  open POSIX file "${PROJECT_PATH}"

  set docRef to missing value
  repeat 120 times
    try
      set docRef to first workspace document whose name is "${WORKSPACE_NAME}"
      exit repeat
    end try
    delay 0.5
  end repeat

  if docRef is missing value then
    error "Xcode did not open ${WORKSPACE_NAME} within 60 seconds."
  end if

  delay 1
  my selectScheme(docRef)

  try
    set preferredDestinations to run destinations of docRef whose name is "${RUN_DESTINATION_NAME}"
    if (count of preferredDestinations) > 0 then
      set active run destination of docRef to item 1 of preferredDestinations
    else
      set macDestinations to run destinations of docRef whose platform is "macosx"
      if (count of macDestinations) > 0 then
        set active run destination of docRef to item 1 of macDestinations
      end if
    end if
  end try

  if "${action}" is "build" then
    set actionResult to build docRef
    return my waitForSchemeActionCompletion(actionResult)
  else if "${action}" is "run" then
    set actionResult to run docRef
    return my waitForSchemeActionStartOrFail(actionResult)
  else if "${action}" is "debug" then
    set actionResult to debug docRef
    return my waitForSchemeActionStartOrFail(actionResult)
  else
    error "Unknown Xcode action: ${action}"
  end if
end tell
APPLESCRIPT
}

require_xcode_success() {
  local action="$1"
  local result

  if ! result="$(run_xcode_action "$action")"; then
    return 1
  fi

  case "$result" in
    OK\|*)
      printf '%s\n' "${result#OK|}"
      ;;
    ERROR\|*)
      printf 'Xcode %s failed.\n%s\n' "$action" "${result#ERROR|}" >&2
      return 1
      ;;
    *)
      printf '%s\n' "$result"
      ;;
  esac
}

wait_for_process() {
  local attempts=15

  for ((i = 1; i <= attempts; i += 1)); do
    if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    /bin/sleep 1
  done

  return 1
}

case "$MODE" in
  run|"")
    stop_existing_app
    require_xcode_success run >/dev/null
    printf 'Launched %s via Xcode scheme %s.\n' "$APP_NAME" "$SCHEME_NAME"
    ;;
  --debug|debug)
    stop_existing_app
    require_xcode_success debug >/dev/null
    printf 'Started %s in Xcode debug mode.\n' "$APP_NAME"
    ;;
  --logs|logs)
    stop_existing_app
    require_xcode_success run >/dev/null
    wait_for_process
    exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_existing_app
    require_xcode_success run >/dev/null
    wait_for_process
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_existing_app
    require_xcode_success run >/dev/null

    if ! wait_for_process; then
      printf 'Timed out waiting for %s to launch.\n' "$APP_NAME" >&2
      exit 1
    fi

    printf 'Verified %s is running (pid %s).\n' "$APP_NAME" "$(/usr/bin/pgrep -x "$APP_NAME" | /usr/bin/paste -sd ',' -)"
    ;;
  --help|help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
