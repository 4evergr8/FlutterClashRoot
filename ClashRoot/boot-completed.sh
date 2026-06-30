#!/system/bin/sh

DAEMON_LOG="/data/adb/modules/ClashRoot/daemon.log"


log() {
    echo "[$(date '+%F %T')] $*"
}
set -x

CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="$CLASH_DIR/clash"
CLASH_LOG="$CLASH_DIR/clash.log"
YQ="$CLASH_DIR/yq"
WGET="busybox wget"
BASE="$CLASH_DIR/data.yaml"
OVERRIDE="$CLASH_DIR/override.yaml"
OUT_DIR="$CLASH_DIR/config"
CONFIG="$CLASH_DIR/config.yaml"
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

elif [ "$CMD" = "yaml" ]; then
    log "CMD=yaml"
    BASE_YAML="$2"
    apply_config "$BASE_YAML"

elif [ "$CMD" = "loop" ]; then
    log "CMD=loop"

    ua=$($YQ eval -r '.ua' "$BASE")
    id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
    link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

    log "download $id"

    $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

    apply_config "$OUT_DIR/$id.yaml"

    ts=$(date +%s%3N)

    $YQ e "
      (.subscriptions[] | select(.select == true) | .update) = $ts
    " -i "$BASE"

    kill_clash
    start_clash

else
    exec >"$DAEMON_LOG" 2>&1
    log "CMD=loop-service start"
    kill_clash
    start_clash

    while true; do
        sleep 3600

        HOUR=$(date +%H)
        log "loop tick hour=$HOUR"

        if [ $((10#$HOUR % 8)) -eq 6 ]; then

            log "trigger update"

            (
                ua=$($YQ eval -r '.ua' "$BASE")
                id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
                link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

                log "download $id"

                $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

                apply_config "$OUT_DIR/$id.yaml"

                ts=$(date +%s%3N)

                $YQ e "
                  (.subscriptions[] | select(.select == true) | .update) = $ts
                " -i "$BASE"

                log "update done"

            ) || true

            kill_clash
            start_clash

            log "restart clash done"
        fi

    done
fi