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
if [ "$(find /dev/block -name boot | head -n 1)" ]; then
  block=$(find /dev/block -name boot | head -n 1)
elif [ -e /dev/block/platform/sdhci-tegra.3/by-name/LNX ]; then
  block=/dev/block/platform/sdhci-tegra.3/by-name/LNX
else
  abort "! Boot img not found! Aborting!"
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

# determine install or uninstall
[ "$(grep '#cpgdisabler' $overlay/init.rc)" ] && ACTION=Uninstall

# begin ramdisk changes
if [ -z $ACTION ]; then 
  # find kernel driver parameter
  cpgd="${cpgd} $(find /sys/module -name '*collapse_enable')"

  # Add codec power gate disable line to init.rc
  backup_file $overlay/init.rc
  ui_print "Disabling codec power gating..."
  for i in ${cpgd}; do
    insert_line $overlay/init.rc "$cpgd" after "on post-fs-data" "    write $i 0 #cpgdisabler"
  done
else
  ui_print "Reenabling codec power gating..."
  sed -i "/#cpgdisabler/d" $overlay/init.rc
fi

# end ramdisk changes
ui_print " "
ui_print "Repacking boot image..."
write_boot

#end install
