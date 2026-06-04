#!/system/bin/sh
SKIPUNZIP=1

ui_print "==> 打印 KernelSU 内置变量"

# 布尔值/路径/版本信息
ui_print "KSU=$KSU"
ui_print "KSU_VER=$KSU_VER"
ui_print "KSU_VER_CODE=$KSU_VER_CODE"
ui_print "KSU_KERNEL_VER_CODE=$KSU_KERNEL_VER_CODE"
ui_print "BOOTMODE=$BOOTMODE"
ui_print "MODPATH=$MODPATH"
ui_print "TMPDIR=$TMPDIR"
ui_print "ZIPFILE=$ZIPFILE"
ui_print "ARCH=$ARCH"
ui_print "IS64BIT=$IS64BIT"
ui_print "API=$API"

# Magisk 兼容变量（KernelSU 内固定值）
ui_print "MAGISK_VER_CODE=$MAGISK_VER_CODE"
ui_print "MAGISK_VER=$MAGISK_VER"

ui_print "==> 打印完成"