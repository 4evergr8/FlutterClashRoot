#!/system/bin/sh

DAEMON_LOG="/data/adb/modules/ClashRoot/daemon.log"


log() {
    echo "[$(date '+%F %T')] $*"
}
set -x

CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="$CLASH_DIR/clash"
CLASH_LOG="$CLASH_DIR/clash.log"
CMD="$1"

start_clash() {
    log "start_clash"
    setsid "$CLASH_BIN" -d "$CLASH_DIR" >"$CLASH_LOG" 2>&1 &
}

kill_clash() {
    log "kill_clash"
    killall clash
}

apply_config() {
    log "apply_config $1"
    $YQ eval-all '
        select(fileIndex == 1) as $a
        | select(fileIndex == 0) as $b
        | $b * $a
    ' "$OVERRIDE" "$1" > "$CONFIG"
}

if [ "$CMD" = "start" ]; then
    log "CMD=start"
    kill_clash
    start_clash
    echo "启动完毕"

elif [ "$CMD" = "kill" ]; then
    log "CMD=kill"
    kill_clash
    echo "停止完毕"

elif [ "$CMD" = "test" ]; then
    log "CMD=test"
    "$CLASH_BIN" -t -d "$CLASH_DIR"

elif [ "$CMD" = "check" ]; then
    log "CMD=check"
    eval "ps -p \$(pidof clash) -o pid,ppid,%cpu,%mem,cmd; cat /proc/\$(pidof clash)/status"



else
    log "boot start"
    kill_clash
    start_clash
fi