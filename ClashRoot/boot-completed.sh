#!/system/bin/sh

CLASH_DIR="/data/adb/modules/ClashRoot"
CLASH_BIN="./clash"

# 命令字符串变量
START_CMD="cd $CLASH_DIR && chmod +x $CLASH_BIN && nohup setsid $CLASH_BIN -d . >$CLASH_DIR/clash.log 2>&1 &"
KILL_CMD="killall clash >/dev/null 2>&1"
TEST_CMD="cd $CLASH_DIR && chmod +x $CLASH_BIN && $CLASH_BIN -t -d ."
CHECK_CMD="ps -p \$(pidof clash) -o pid,ppid,%cpu,%mem,cmd; cat /proc/\$(pidof clash)/status"

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

            (
            # ================= TRY START =================

            set -e

            CLASH_YQ=$CLASH_DIR/clash_yq

            # 1. 读取 settings.yaml
            UA=$($CLASH_YQ e '.ua' $CLASH_DIR/settings.yaml)
            SELECT=$($CLASH_YQ e '.select' $CLASH_DIR/settings.yaml)

            # 2. 找 subscription
            URL=$($CLASH_YQ e ".subscriptions[] | select(.id == \"$SELECT\") | .url" $CLASH_DIR/subscriptions.yaml)

            if [ -z "$URL" ]; then
                echo "URL为空，跳过"
                exit 1
            fi

            # 3. 下载
            busybox curl -A "$UA" -L "$URL" -o $CLASH_DIR/config/temp.yaml

            # 4. YAML 校验
            $CLASH_YQ e '.' $CLASH_DIR/config/temp.yaml >/dev/null

            # 5. 覆盖 id.yaml
            cp -f $CLASH_DIR/config/temp.yaml $CLASH_DIR/config/$SELECT.yaml

            # 6. shallow override（非递归 = 只覆盖第一层 key）
            MERGED=$($CLASH_YQ eval-all '
                select(fileIndex==1) * select(fileIndex==0)
            ' \
            $CLASH_DIR/override.yaml \
            $CLASH_DIR/config/$SELECT.yaml)

            echo "$MERGED" > $CLASH_DIR/config.yaml

            # 7. 写入 13位时间戳回 subscriptions.yaml
            TS=$(busybox date +%s%3N)

            $CLASH_YQ e -i \
                ".subscriptions[] |= (if .id == \"$SELECT\" then .last_update = \"$TS\" else . end)" \
                $CLASH_DIR/subscriptions.yaml

            # 8. 重启 clash
            eval "$KILL_CMD"
            sleep 2
            eval "$START_CMD"

            # ================= TRY END =================
            ) || {
                echo "05流程失败"
            }

        fi

        sleep 3600
    done
fi