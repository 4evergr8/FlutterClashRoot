#!/system/bin/sh

CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="./clash"

START_CMD="cd $CLASH_DIR && setsid $CLASH_BIN -d . >$CLASH_DIR/clash.log 2>&1 &"
KILL_CMD="killall clash"
TEST_CMD="cd $CLASH_DIR && $CLASH_BIN -t -d ."
CHECK_CMD="ps -p \$(pidof clash) -o pid,ppid,%cpu,%mem,cmd; cat /proc/\$(pidof clash)/status"

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
else
    # 默认分支：先 kill 再 start
    eval "$KILL_CMD"
    eval "$START_CMD"

    # 无限循环，每小时检查一次当前小时
    while true; do
        sleep 3600
        HOUR=$(date +%H)
        if [ $((10#$HOUR % 8)) -eq 6 ]; then
            eval "$KILL_CMD"
            eval "$START_CMD"
        fi

    done
fi