#!/system/bin/sh
ui_print "==> 开始自定义安装: ClashRoot"

# -----------------------------
# 1. APK 安装
# -----------------------------
APK_PATH="$MODPATH/system/app/ClashRoot/ClashRoot.apk"
if [ -f "$APK_PATH" ]; then
    ui_print "尝试安装 APK..."
    pm install -r "$APK_PATH"
    if [ $? -eq 0 ]; then
        ui_print "APK 安装成功"
    else
        ui_print "警告: APK 安装失败,请开启核心破解或手动安装"
    fi
fi

# -----------------------------
# 2. 恢复配置文件
# -----------------------------
OLD_PATH="/data/adb/modules/ClashRoot"

if [ -d "$OLD_PATH/config" ]; then
    ui_print "恢复 config 文件夹"
    cp -rf "$OLD_PATH/config" "$MODPATH/"
fi

for FILE in override.yaml data.yaml config.yaml; do
    if [ -f "$OLD_PATH/$FILE" ]; then
        ui_print "恢复 $FILE"
        cp -f "$OLD_PATH/$FILE" "$MODPATH/"
    fi
done



ui_print "安装完成"