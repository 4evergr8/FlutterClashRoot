#!/system/bin/sh

CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="./clash"

START_CMD="cd $CLASH_DIR && setsid $CLASH_BIN -d . >$CLASH_DIR/clash.log 2>&1 &"
KILL_CMD="killall clash"
TEST_CMD="cd $CLASH_DIR && $CLASH_BIN -t -d ."
CHECK_CMD="ps -p \$(pidof clash) -o pid,ppid,%cpu,%mem,cmd; cat /proc/\$(pidof clash)/status"

YQ="$CLASH_DIR/yq"
WGET="busybox wget"

BASE="$CLASH_DIR/data.yaml"
OVERRIDE="$CLASH_DIR/override.yaml"
OUT_DIR="$CLASH_DIR/config"
CONFIG="$CLASH_DIR/config.yaml"

CMD="$1"

if [ "$CMD" = "start" ]; then
    eval "$KILL_CMD"
    eval "$START_CMD"
    echo "启动完毕"

elif [ "$CMD" = "kill" ]; then
    eval "$KILL_CMD"
    echo "停止完毕"

elif [ "$CMD" = "test" ]; then
    eval "$TEST_CMD"

elif [ "$CMD" = "check" ]; then
    eval "$CHECK_CMD"

elif [ "$CMD" = "yaml" ]; then

    BASE_YAML="$2"

    $YQ eval-all '
        select(fileIndex == 0) as $a
        | select(fileIndex == 1) as $b
        | $b * $a
    ' "$OVERRIDE" "$BASE_YAML" > "$CONFIG"

else
    eval "$KILL_CMD"
    eval "$START_CMD"

    while true; do
        sleep 3600

        HOUR=$(date +%H)

        if [ $((10#$HOUR % 8)) -eq 6 ]; then

            (
                set +e

                ua=$($YQ eval -r '.ua' "$BASE")
                id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
                link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)



                $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

                $YQ eval-all '
                    select(fileIndex == 1) as $a
                    | select(fileIndex == 0) as $b
                    | $a + $b
                ' "$OVERRIDE" "$OUT_DIR/$id.yaml" > "$CONFIG"

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


                set -e
            ) || true

            eval "$KILL_CMD"
            eval "$START_CMD"
        fi

    done
fi