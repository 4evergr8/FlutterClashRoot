#!/system/bin/sh
ui_print "==> 开始自定义安装: ClashRoot"


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


chmod +x "$MODPATH/clash"

ui_print "安装完成"