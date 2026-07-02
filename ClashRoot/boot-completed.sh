#!/system/bin/sh





set -x
DAEMON_LOG="/data/adb/modules/ClashRoot/daemon.log"
CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="$CLASH_DIR/clash"
CLASH_LOG="$CLASH_DIR/clash.log"
CMD="$1"
log() {
    echo "[$(date '+%F %T')] $*"
}
start_clash() {
    log "start_clash"
    setsid "$CLASH_BIN" -d "$CLASH_DIR" >"$CLASH_LOG" 2>&1 &
}

kill_clash() {
    log "kill_clash"
    killall clash
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
    exec >"$DAEMON_LOG" 2>&1
    log "boot start"
    kill_clash
    start_clash

    while true; do
        sleep 3600
        : > "$CLASH_LOG"
        log "clash.log 已清空"
    done
fi