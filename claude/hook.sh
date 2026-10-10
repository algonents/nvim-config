#!/usr/bin/env bash
# Claude Code hook -> per-session state file for the Neovim integration
# (lua/claude/hooks.lua). Wire it for every event listed in CLAUDE.md
# ("Claude Code integration" / hooks). Reads the hook JSON on stdin, keeps
# $XDG_RUNTIME_DIR/claude-nvim/<session_id>.json up to date and exits 0.
set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$event" ] && [ -n "$sid" ] || exit 0

dir="${XDG_RUNTIME_DIR:-/tmp/claude-nvim-$(id -u)}/claude-nvim"
mkdir -p "$dir" 2>/dev/null || exit 0
file="$dir/$sid.json"
now=$(date +%s)
pid="${CLAUDE_PID:-$PPID}"

if [ "$event" = SessionEnd ]; then
    rm -f "$file" "$file.lock" "$file.tmp"
    exit 0
fi

exec 9>"$file.lock"
flock -w 2 9 || exit 0

source=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)
if { [ "$event" = SessionStart ] && [ "$source" != compact ]; } || [ ! -s "$file" ]; then
    # Sweep files of this pid (/clear, --resume give a new session id) and
    # of processes that are gone (crashed sessions never reach SessionEnd).
    for f in "$dir"/*.json; do
        [ -e "$f" ] && [ "$f" != "$file" ] || continue
        p=$(jq -r '.pid // 0' "$f" 2>/dev/null)
        if [ "$p" = "$pid" ] || ! kill -0 "$p" 2>/dev/null; then
            rm -f "$f" "$f.lock" "$f.tmp"
        fi
    done
    jq -n \
        --arg sid "$sid" --argjson pid "$pid" \
        --arg cwd "$(printf '%s' "$input" | jq -r '.cwd // ""')" \
        --arg nvim "${NVIM:-}" --arg slot "${NVIM_CLAUDE_SLOT:-}" \
        --argjson now "$now" '{
            session_id: $sid, pid: $pid, cwd: $cwd,
            nvim: (if $nvim == "" then null else $nvim end),
            slot: (if $slot == "" then null else ($slot | tonumber) end),
            started: $now, updated: $now, state: "idle",
            notification: null, tool: null, agents: {}, tasks: {}, todos: []
        }' > "$file.tmp" && mv "$file.tmp" "$file"
fi

case "$event" in
    SessionStart)     filter='.' ;;
    UserPromptSubmit) filter='.state = "working" | .notification = null' ;;
    PreToolUse)       filter='if $in.agent_id then . else .tool = { name: $in.tool_name, at: $now } end' ;;
    PostToolUse)      filter='if $in.agent_id then . else .tool = null end' ;;
    PermissionRequest)
        filter='.state = "blocked" | .notification = { type: "permission", msg: ($in.tool_name // ""), at: $now }' ;;
    SubagentStart)
        filter='.agents[$in.agent_id // "unknown"] = { type: ($in.agent_type // "agent"), started: $now, ended: null } | .state = "working"' ;;
    SubagentStop)
        filter='.agents[$in.agent_id // "unknown"] |= ((. // { type: ($in.agent_type // "agent"), started: $now }) + { ended: $now })' ;;
    Stop)
        filter='.state = "idle" | .tool = null | .notification = null
                | .tasks = (($in.background_tasks // []) | map({ key: (.id // .description // "task"), value: { type, status, description } }) | from_entries)' ;;
    Notification)
        filter='.notification = { type: $in.notification_type, msg: ($in.message // ""), at: $now }
                | if ($in.notification_type | IN("permission_prompt", "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog")) then .state = "blocked" else . end' ;;
    TaskCreated)
        filter='.todos = ((.todos // []) + [{ subject: ($in.task_subject // ""), status: "created", at: $now }])[-20:]' ;;
    TaskCompleted)
        filter='.todos = ((.todos // []) + [{ subject: ($in.task_subject // ""), status: "completed", at: $now }])[-20:]' ;;
    *) exit 0 ;;
esac

jq --argjson in "$input" --argjson now "$now" "$filter | .updated = \$now" "$file" > "$file.tmp" 2>/dev/null \
    && mv "$file.tmp" "$file"
exit 0
