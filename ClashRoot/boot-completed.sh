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
PATCH="$CLASH_DIR/override.yaml"
OUT_DIR="$CLASH_DIR/config"

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

elif [ "$CMD" = "loop" ]; then

    (
        set +e

        ua=$($YQ eval -r '.ua' "$BASE")

        id=$($YQ eval -r '.subscriptions[] | select(.select == true) | .id' "$BASE" | head -n 1)
        link=$($YQ eval -r '.subscriptions[] | select(.select == true) | .link' "$BASE" | head -n 1)

        echo "id=$id"
        echo "link=$link"

        mkdir -p "$OUT_DIR"

        if [ -n "$id" ] && [ -n "$link" ]; then
            echo "download test"

            $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

            file="$OUT_DIR/$id.yaml"

            echo "del test"
            for p in $($YQ eval -r '.del[]' "$PATCH"); do
                echo "del: $p"
                $YQ eval "del(.$p)" -i "$file"
            done

            echo "set test"
            $YQ eval '.set as $s | . * $s' "$file" "$PATCH" -i
        fi

        set -e
    ) || true

    echo "循环逻辑测试完成"

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

                mkdir -p "$OUT_DIR"

                if [ -n "$id" ] && [ -n "$link" ]; then

                    $WGET --user-agent="$ua" -O "$OUT_DIR/$id.yaml" "$link"

                    file="$OUT_DIR/$id.yaml"

                    for p in $($YQ eval -r '.del[]' "$PATCH"); do
                        $YQ eval "del(.$p)" -i "$file"
                    done

                    $YQ eval '.set as $s | . * $s' "$file" "$PATCH" -i
                fi

                set -e
            ) || true

            eval "$KILL_CMD"
            eval "$START_CMD"
        fi

    done
fi