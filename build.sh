#!/bin/bash

DEV_BOARD="m7"
DEV_DESC="HTC One M7 GPE"
DEV_ARCH="armhf"
DEV_BLOCK="/dev/block/platform/msm_sdcc.1/by-name/boot"
KERN_CONFIG="m7gpekali_defconfig"
KERN_BUILDVER="1.2"
KERN_STRING="Kali M7 GPE"
KERN_AUTHOR="Lavanoid"
KERN_ANDROIDVER="lollipop"
KERN_ANDROIDVNO="5.1.1 Lollipop"
INST_AROMA="True"
KALI_DEVNAME="onem7gpe"
BUILD_CORES="2"

if NPROC=$(nproc); then
    echo "[INFORMATION] Total cores: $NPROC"
    echo "[CONFIGURE] Using the maximum No. of processing cores available...."
    BUILD_CORES="$NPROC"
fi

#This will appear in the kernel string, such as "root@kali".
HOST="kali"

echo "[CONFIGURE] Changing system host name to '"$HOST"'..."
# Backup the original hostname, then change it to the value of "HOST".
ORIGINALHOSTNAME=$(hostname)
export HOSTNAME=$HOST
sudo hostname "$HOST"

echo "[CONFIGURE] Installing dependencies..."
sudo apt-get update
sudo apt-get install build-essential git wget curl -y

echo "[CONFIGURE] Downloading arm toolchain..."
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7 toolchain

echo "[CONFIGURE] Setting path variables..."
export ARCH=arm
export SUBARCH=arm
export CROSS_COMPILE=`pwd`/toolchain/bin/arm-eabi-
export PATH=$PATH:`pwd`/toolchain/bin

echo "[CONFIGURE] Downloading Kali Nethunter"
git clone https://github.com/offensive-security/kali-nethunter
cd kali-nethunter
git pull origin master
cd ..

if [[ -f "$KERN_CONFIG" ]]; then
	echo "[CONFIGURE] Copying Kali default configuration..."
	cp -f "$KERN_CONFIG" "kernel/arch/arm/configs/$KERN_CONFIG"
fi

cd kernel
if [[ ! -f "mac80211.compat08082009.wl_frag+ack_v1.patch" ]]; then
	echo "[PATCH] Patching 802.11..."
	wget http://patches.aircrack-ng.org/mac80211.compat08082009.wl_frag+ack_v1.patch
	patch -p1 < mac80211.compat08082009.wl_frag+ack_v1.patch
fi

echo "[BUILD] Building kernel for $DEV_DESC $KERN_ANDROIDVNO"
make clean
make $KERN_CONFIG
make -j$BUILD_CORES

cd ..
if [[ $(cat kali-nethunter/nethunter-installer/devices.cfg | grep "$KALI_DEVNAME") == "" ]]; then
	echo "[CONFIGURE] Adding $KALI_DEVNAME to devices.cfg..."
	echo "">> kali-nethunter/nethunter-installer/devices.cfg
	echo "#"$DEV_DESC>> kali-nethunter/nethunter-installer/devices.cfg
	echo "["$KALI_DEVNAME"]">> kali-nethunter/nethunter-installer/devices.cfg
	echo "author = \"$KERN_AUTHOR\"">> kali-nethunter/nethunter-installer/devices.cfg
	echo "version = \"$KERN_BUILDVER\"">> kali-nethunter/nethunter-installer/devices.cfg
	echo "kernelstring = \"$KERN_STRING\"">> kali-nethunter/nethunter-installer/devices.cfg
	echo "arch = $DEV_ARCH">> kali-nethunter/nethunter-installer/devices.cfg
	echo "devicenames = $DEV_BOARD">> kali-nethunter/nethunter-installer/devices.cfg
	echo "block = $DEV_BLOCK">> kali-nethunter/nethunter-installer/devices.cfg
	echo "aroma = $INST_AROMA">> kali-nethunter/nethunter-installer/devices.cfg

fi

if [[ -f "kernel/arch/arm/boot/zImage" ]]; then
	echo "[CONFIGURE] Copying created kernel to Kali Installer kernels directory..."
	mkdir "kali-nethunter/nethunter-installer/kernels/$KERN_ANDROIDVER/$KALI_DEVNAME"
	cp -f "kernel/arch/arm/boot/zImage" "kali-nethunter/nethunter-installer/kernels/$KERN_ANDROIDVER/$KALI_DEVNAME/zImage"
fi

echo "[BUILD] Building Kali Nethunter package..."
cd "kali-nethunter/nethunter-installer/"
python build.py -d $KALI_DEVNAME --$KERN_ANDROIDVER

echo "[CONFIGURE] Restoring system host name to '"$ORIGINALHOSTNAME"'..."
export HOSTNAME=$ORIGINALHOSTNAME
sudo hostname "$ORIGINALHOSTNAME"
echo "OK"
echo "[DONE] Compilation complete."

