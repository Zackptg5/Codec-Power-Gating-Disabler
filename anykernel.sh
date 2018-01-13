# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Codec Power Gating Disabler
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=			 
} # end properties

# shell variables
ramdisk_compression=auto
# determine the location of the boot partition
if [ -e /dev/block/platform/*/by-name/boot ]; then
  block=/dev/block/platform/*/by-name/boot
elif [ -e /dev/block/platform/*/*/by-name/boot ]; then
  block=/dev/block/platform/*/*/by-name/boot
elif [ -e /dev/block/platform/sdhci-tegra.3/by-name/LNX ]; then
  block=/dev/block/platform/sdhci-tegra.3/by-name/LNX
fi

# force expansion of the path so we can use it
block=`echo -n $block`;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

## AnyKernel install
ui_print "Unpacking boot image..."
ui_print " "
dump_boot

# File list
list="init.rc"

# LG Bump Boot img support (credits to Drgravy @xda-developers)
bump=false
if [ "$(grep_prop ro.product.brand)" = "lge" ] || [ "$(grep_prop ro.product.brand)" = "LGE" ]; then 
  case $(grep_prop ro.product.device) in
    d800|d801|d802|d803|ls980|vs980|101f|d850|d852|d855|ls990|vs985|f400) bump=true; ui_print "! Bump device detected !"; ui_print "! Using bump exploit !"; ui_print " ";;
	*) ;;
  esac
fi

# Slot device support
if [ ! -z $slot ]; then       
  mv -f $bin/avb-signing/avb $bin/avb-signing/BootSignature_Android.jar $bin     
  if [ -d $ramdisk/.subackup -o -d $ramdisk/.backup ]; then
    patch_cmdline "skip_override" "skip_override"
  else
    patch_cmdline "skip_override" ""
  fi
  # Overlay stuff
  if [ -d $ramdisk/.backup ]; then
    overlay=$ramdisk/overlay
  elif [ -d $ramdisk/.subackup ]; then
    overlay=$ramdisk/boot
  fi
  for rdfile in $list; do
    rddir=$(dirname $rdfile)
    mkdir -p $overlay/$rddir
    test ! -f $overlay/$rdfile && cp -rp /system/$rdfile $overlay/$rddir/
  done                       
else
  overlay=$ramdisk
fi

# Detect if boot.img is signed - credits to chainfire @xda-developers
unset LD_LIBRARY_PATH
BOOTSIGNATURE="/system/bin/dalvikvm -Xbootclasspath:/system/framework/core-oj.jar:/system/framework/core-libart.jar:/system/framework/conscrypt.jar:/system/framework/bouncycastle.jar -Xnodex2oat -Xnoimage-dex2oat -cp $bin/avb-signing/BootSignature_Android.jar com.android.verity.BootSignature"
if [ ! -f "/system/bin/dalvikvm" ]; then
  # if we don't have dalvikvm, we want the same behavior as boot.art/oat not found
  RET="initialize runtime"
else
  RET=$($BOOTSIGNATURE -verify /tmp/anykernel/boot.img 2>&1)
fi
test ! -z $slot && RET=$($BOOTSIGNATURE -verify /tmp/anykernel/boot.img 2>&1)
if (`echo $RET | grep "VALID" >/dev/null 2>&1`); then
  ui_print "Signed boot img detected!"
  mv -f $bin/avb-signing/avb $bin/avb-signing/BootSignature_Android.jar $bin
fi

# determine install or uninstall
test -f cpgdindicator && ACTION=Uninstall

# begin ramdisk changes
if [ -z $ACTION ]; then
  # Add indicator
  touch cpgdindicator
  
  # find kernel driver parameter
  cpgd="${cpgd} $(find /sys/module -name '*collapse_enable')"

  # Add codec power gate disable line to init.rc
  backup_file $overlay/init.rc
  ui_print "Disabling codec power gating..."
  for i in ${cpgd}; do
    insert_line $overlay/init.rc "$cpgd" after "on post-fs-data" "    write $i 0"
  done
else
  ui_print "Reenabling codec power gating..."
  rm -f cpgdindicator
  restore_file $overlay/init.rc
fi

# end ramdisk changes
ui_print " "
ui_print "Repacking boot image..."
write_boot

#end install
