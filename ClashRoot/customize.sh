#!/system/bin/sh
ui_print "==> 开始自定义安装: ClashRoot"


OLD_PATH="/data/adb/modules/ClashRoot"
mkdir -p "$MODPATH/config"
mkdir -p "$MODPATH/log"

ui_print "恢复 config 文件夹"
cp -rf "$OLD_PATH/config" "$MODPATH/"
ui_print "恢复 log 文件夹"
cp -rf "$OLD_PATH/log" "$MODPATH/"

for FILE in data.yaml config.yaml root; do
    if [ -f "$OLD_PATH/$FILE" ]; then
        ui_print "恢复 $FILE"
        cp -f "$OLD_PATH/$FILE" "$MODPATH/"
    fi
done


chmod +x "$MODPATH/clash"
rm -f "$MODPATH/customize.sh"

ui_print "安装完成"