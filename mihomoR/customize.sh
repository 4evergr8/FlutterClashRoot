#!/system/bin/sh
ui_print "==> 开始自定义安装: mihomoR"

# -----------------------------
# 1. APK 安装
# -----------------------------
APK_PATH="$MODPATH/app-arm64-v8a-release.apk"
if [ -f "$APK_PATH" ]; then
    ui_print "尝试安装 APK..."
    pm install -r "$APK_PATH"
    if [ $? -eq 0 ]; then
        ui_print "APK 安装成功"
        rm -f "$APK_PATH"
    else
        ui_print "警告: APK 安装失败"
    fi
fi

# -----------------------------
# 2. 恢复配置文件
# -----------------------------
OLD_PATH="/data/adb/modules/mihomoR"

if [ -d "$OLD_PATH/config" ]; then
    ui_print "恢复 config 文件夹"
    cp -rf "$OLD_PATH/config" "$MODPATH/"
fi

for FILE in override.yaml settings.yaml subscriptions.yaml config.yaml; do
    if [ -f "$OLD_PATH/$FILE" ]; then
        ui_print "恢复 $FILE"
        cp -f "$OLD_PATH/$FILE" "$MODPATH/"
    fi
done

ui_print "安装完成"