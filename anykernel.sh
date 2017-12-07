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

# LG Bump Boot img support (credits to Drgravy @xda-developers)
BUMP=false
if [ "$(grep_prop ro.product.brand)" = "lge" ] || [ "$(grep_prop ro.product.brand)" = "LGE" ]; then 
  case $(grep_prop ro.product.device) in
    d800|d801|d802|d803|ls980|vs980|101f|d850|d852|d855|ls990|vs985|f400) BUMP=true; ui_print "! Bump device detected !"; ui_print "! Using bump exploit !"; ui_print " ";;
	*) ;;
  esac
fi
# Pixel/Nexus boot img signing support
if device_check "bullhead" || device_check "angler"; then             
  mv -f $bin/avb-signing/avb $bin/avb-signing/BootSignature_Android.jar $bin
elif [ ! -z $slot ]; then            
  mv -f $bin/avb-signing/avb $bin/avb-signing/BootSignature_Android.jar $bin              
  test -d $ramdisk/boot/dev -o -d $ramdisk/overlay && patch_cmdline "skip_override" "skip_override" || patch_cmdline "skip_override" ""
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
  backup_file init.rc
  ui_print "Disabling codec power gating..."
  for i in ${cpgd}; do
    insert_line init.rc "$cpgd" after "on post-fs-data" "    write $i 0"
  done
  
  # Add backup script
  sed -i -e "s|<block>|$block|" $patch/cpgd.sh
  if [ -d /system/addon.d ]; then ui_print "Installing addon.d script..."; cp -f $patch/cpgd.sh /system/addon.d/99cpgd.sh; chmod 0755 /system/addon.d/99cpgd.sh; else ui_print "No addon.d support detected!"; ui_print "Patched boot img won't survive dirty flash!"; fi
else
  ui_print "Reenabling codec power gating..."
  rm -f /system/addon.d/99cpgd.sh cpgdindicator
  restore_file init.rc
fi

# end ramdisk changes
ui_print " "
ui_print "Repacking boot image..."
write_boot

# end install
