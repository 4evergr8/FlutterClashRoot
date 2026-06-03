#!/system/bin/sh
SKIPUNZIP=1

ui_print "==> 开始自定义安装: mihomoR"

# -----------------------------
# 1. 缓存目录处理
# -----------------------------
CACHE="$TMPDIR/mihomoR"
ui_print "准备缓存目录: $CACHE"
if [ -d "$CACHE" ]; then
    rm -rf "$CACHE"
fi
mkdir -p "$CACHE"

# -----------------------------
# 2. 解压全部内容到缓存
# -----------------------------
ui_print "解压模块到缓存..."
unzip -o "$ZIPFILE" -d "$CACHE" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    ui_print "警告: 解压 ZIP 失败"
fi

# -----------------------------
# 3. APK 安装
# -----------------------------
APK_PATH="$CACHE/app-arm64-v8a-release.apk"
if [ -f "$APK_PATH" ]; then
    ui_print "尝试安装 APK..."
    pm install -r "$APK_PATH" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        ui_print "APK 安装成功"
    else
        ui_print "警告: APK 安装失败"
    fi
fi

# -----------------------------
# 4. 模块文件夹处理
# -----------------------------
if [ ! -d "$MODPATH" ]; then
    ui_print "模块文件夹不存在，直接复制缓存到模块目录"
    cp -a "$CACHE" "$MODPATH"
else
    ui_print "模块文件夹已存在，处理增量替换"

    # 删除 metacubexd 文件夹
    if [ -d "$MODPATH/metacubexd" ]; then
        rm -rf "$MODPATH/metacubexd"
    fi



fi

# -----------------------------
# 5. 清理缓存
# -----------------------------
rm -rf "$CACHE"
ui_print "自定义安装完成"