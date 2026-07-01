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
    exec >"$DAEMON_LOG" 2>&1
    log "trigger update"

    ua=$($YQ eval -r '.ua' "$BASE")
    id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
    link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

    log "download $id"

    TEMP_YAML="$OUT_DIR/temp.yaml"

    $WGET --user-agent="$ua" -O "$TEMP_YAML" "$link"

    # 读取 proxies / proxy-providers 数组长度
    proxies_len=$($YQ eval '.proxies | length' "$TEMP_YAML")
    providers_len=$($YQ eval '.["proxy-providers"] | length' "$TEMP_YAML")

    # 统一处理 null（yq 可能返回 null）
    if [ "$proxies_len" = "null" ]; then
        proxies_len=0
    fi

    if [ "$providers_len" = "null" ]; then
        providers_len=0
    fi

    log "proxies=$proxies_len providers=$providers_len"

    # 两个都不存在或都为空 → 不更新
    if [ "$proxies_len" -le 0 ] && [ "$providers_len" -le 0 ]; then
        log "empty config, skip update"
        rm -f "$TEMP_YAML"
        exit 0
    fi

    # 至少一个有内容 → 覆盖 id.yaml
    mv "$TEMP_YAML" "$OUT_DIR/$id.yaml"

    apply_config "$OUT_DIR/$id.yaml"

    ts=$(date +%s%3N)

    $YQ e "
      (.subscriptions[] | select(.select == true) | .update) = $ts
    " -i "$BASE"

    log "update done"

    kill_clash
    start_clash
    log "restart clash done"

else
    exec >"$DAEMON_LOG" 2>&1
    log "boot start"
    kill_clash
    start_clash
fi