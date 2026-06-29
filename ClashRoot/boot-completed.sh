#!/system/bin/sh

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
start() {
    setsid "$CLASH_BIN" -d "$CLASH_DIR" >"$CLASH_LOG" 2>&1 &
}
kill() {
    killall clash
}
apply_config() {
    $YQ eval-all '
        select(fileIndex == 1) as $a
        | select(fileIndex == 0) as $b
        | $b * $a
    ' "$OVERRIDE" "$1" > "$CONFIG"
}

if [ "$CMD" = "start" ]; then
    kill
    start
    echo "启动完毕"

elif [ "$CMD" = "kill" ]; then
    kill
    echo "停止完毕"

elif [ "$CMD" = "test" ]; then
    "$CLASH_BIN" -t -d "$CLASH_DIR"

elif [ "$CMD" = "check" ]; then
    ps -p "$(pidof clash)" -o pid,ppid,%cpu,%mem,cmd
    cat /proc/"$(pidof clash)"/status

elif [ "$CMD" = "yaml" ]; then

    BASE_YAML="$2"
    apply_config "$BASE_YAML"

elif [ "$CMD" = "loop" ]; then

    ua=$($YQ eval -r '.ua' "$BASE")
    id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
    link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

    $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

    apply_config "$OUT_DIR/$id.yaml"

    ts=$(date +%s)

    $YQ eval --arg ts "$ts" '
        .subscriptions |= map(
            if .select == true then
                .update = ($ts | tonumber)
            else
                .
            end
        )
    ' "$BASE" -i

    kill
    start

else
    kill
    start

    while true; do
        sleep 3600

        HOUR=$(date +%H)

        if [ $((10#$HOUR % 8)) -eq 6 ]; then

            (

                ua=$($YQ eval -r '.ua' "$BASE")
                id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
                link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

                $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

                apply_config "$OUT_DIR/$id.yaml"

                ts=$(date +%s)

                $YQ eval --arg ts "$ts" '
                    .subscriptions |= map(
                        if .select == true then
                            .update = ($ts | tonumber)
                        else
                            .
                        end
                    )
                ' "$BASE" -i

            ) || true

            kill
            start
        fi

    done
fi