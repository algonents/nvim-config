#!/usr/bin/env bash
# Exercises claude/hook.sh with synthetic events. Run: bash tests/claude_hook.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
hook="$here/claude/hook.sh"
export XDG_RUNTIME_DIR=$(mktemp -d)
export NVIM_CLAUDE_SLOT=1 NVIM=/run/user/1000/nvim.test.0 CLAUDE_PID=$$
dir="$XDG_RUNTIME_DIR/claude-nvim"
sid=11111111-2222-3333-4444-555555555555
file="$dir/$sid.json"
ev() { jq -nc --arg e "$1" --arg s "$sid" "{hook_event_name:\$e, session_id:\$s, cwd:\"/tmp/proj\"} + $2" | "$hook"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

ev SessionStart '{source:"startup"}'
jq -e '.slot == 1 and .nvim == "'"$NVIM"'" and .state == "idle" and .pid == '"$$" "$file" >/dev/null || fail "SessionStart base"
ev UserPromptSubmit '{prompt:"hi"}'
jq -e '.state == "working"' "$file" >/dev/null || fail "UserPromptSubmit"
ev PreToolUse '{tool_name:"Bash", tool_input:{command:"ls"}}'
jq -e '.tool.name == "Bash"' "$file" >/dev/null || fail "PreToolUse"
ev PreToolUse '{tool_name:"Read", agent_id:"sub1"}'
jq -e '.tool.name == "Bash"' "$file" >/dev/null || fail "subagent tool ignored"
ev SubagentStart '{agent_id:"a1", agent_type:"Explore"}'
ev SubagentStart '{agent_id:"a2", agent_type:"Plan"}'
jq -e '(.agents | length) == 2 and .agents.a1.type == "Explore" and .agents.a1.ended == null' "$file" >/dev/null || fail "SubagentStart"
ev SubagentStop '{agent_id:"a2", agent_type:"Plan"}'
jq -e '.agents.a2.ended != null and .agents.a1.ended == null' "$file" >/dev/null || fail "SubagentStop"
ev PermissionRequest '{tool_name:"Bash"}'
jq -e '.state == "blocked" and .notification.type == "permission"' "$file" >/dev/null || fail "PermissionRequest"
ev Notification '{notification_type:"permission_prompt", message:"Claude needs your permission"}'
jq -e '.state == "blocked" and .notification.type == "permission_prompt"' "$file" >/dev/null || fail "Notification"
ev TaskCreated '{task_id:"t1", task_subject:"write tests"}'
ev TaskCompleted '{task_id:"t1", task_subject:"write tests"}'
jq -e '(.todos | length) == 2 and .todos[1].status == "completed"' "$file" >/dev/null || fail "Task events"
ev Stop '{last_assistant_message:"done", background_tasks:[{id:"bg1", type:"shell", status:"running", description:"tail logs"}]}'
jq -e '.state == "idle" and .tool == null and .tasks.bg1.description == "tail logs"' "$file" >/dev/null || fail "Stop"
# concurrent events must not corrupt the file
for i in $(seq 1 8); do ev TaskCreated "{task_subject:\"c$i\"}" & done; wait
jq -e '(.todos | length) == 10' "$file" >/dev/null || fail "concurrent writes (flock)"
# /clear: new session id, same pid -> old file swept
sid2=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
old=$file; sid=$sid2; file="$dir/$sid.json"
ev SessionStart '{source:"clear"}'
[ ! -e "$old" ] || fail "same-pid sweep"
[ -s "$file" ] || fail "new session file"
# dead pid sweep
jq -n '{session_id:"dead", pid:999999, updated:0}' > "$dir/dead.json"
sid=$sid2; ev SessionStart '{source:"resume"}'
[ ! -e "$dir/dead.json" ] || fail "dead-pid sweep"
# compact keeps the file contents
ev SubagentStart '{agent_id:"a9", agent_type:"Explore"}'
ev SessionStart '{source:"compact"}'
jq -e '.agents.a9' "$file" >/dev/null || fail "compact preserved agents"
ev SessionEnd '{reason:"other"}'
[ ! -e "$file" ] || fail "SessionEnd removed file"
printf 'not json' | "$hook" || fail "garbage input must exit 0"
echo "claude_hook: all assertions passed"
rm -rf "$XDG_RUNTIME_DIR"
