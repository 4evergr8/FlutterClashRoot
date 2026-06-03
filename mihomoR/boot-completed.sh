#!/system/bin/sh

MIHOMO_DIR="/data/adb/modules/mihomoR"
MIHOMO_BIN="./mihomo"

for FILE in override.yaml settings.yaml subscriptions.yaml; do
    if [ ! -f "$MIHOMO_DIR/$FILE" ] && [ -f "$MIHOMO_DIR/config/$FILE" ]; then
        cp "$MIHOMO_DIR/config/$FILE" "$MIHOMO_DIR/$FILE"
    fi
done
# 命令字符串变量
START_CMD="cd $MIHOMO_DIR && chmod +x $MIHOMO_BIN && nohup setsid $MIHOMO_BIN -d . >$MIHOMO_DIR/mihomo.log 2>&1 &"
KILL_CMD="killall mihomo >/dev/null 2>&1"
TEST_CMD="cd $MIHOMO_DIR && chmod +x $MIHOMO_BIN && $MIHOMO_BIN -d ."
CHECK_CMD="ps -p \$(pidof mihomo) -o pid,ppid,%cpu,%mem,cmd; cat /proc/\$(pidof mihomo)/status"

CMD="$1"

if [ "$CMD" = "start" ]; then
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
        HOUR=$(date +%H)

        if [ "$HOUR" = "05" ]; then
            eval "$KILL_CMD"
            sleep 2
            eval "$START_CMD"
        fi

        sleep 3600
    done
fi