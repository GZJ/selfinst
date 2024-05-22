#!/bin/bash

#------------------------- args -----------------------------------
path_src_iso=$(readlink -f "$1")
path_preseed=$(readlink -f "$2")
path_dst_iso=$(readlink -f "$3")

PATH_SCRIPT=$(dirname "$(realpath "$0")")
PATH_WORK="$PATH_SCRIPT/iso-debian"
PATH_SRC="$PATH_WORK/iso-decompressed"
PATH_DST="$PATH_WORK/iso-new"

#------------------------- iso -----------------------------------
iso=""
iso_name=debian-12.5.0-amd64-netinst.iso

mkdir -p $PATH_WORK $PATH_SRC $PATH_DST
cd $PATH_WORK

if [ "$path_src_iso" = "" ] ; then
    if [ ! -f "$PATH_WORK/$iso_name" ] ; then
        wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$iso_name
        wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS
    fi
    iso=$PATH_WORK/$iso_name
else
    cp $path_src_iso $PATH_WORK
    iso=$path_src_iso
fi

cat $iso | bsdtar -C "$PATH_SRC" -xf -

#------------------------- preseed -----------------------------------
preseed_hostname="selfinst"
preseed_nameservers="114.114.114.114"
preseed_mirror_url="mirrors.ustc.edu.cn"
preseed_password_root="selfinstroot"
preseed_user="g"
preseed_password_g="selfinstg"
preseed_package="openssh-server build-essential vim syncthing barrier"

if [ "$path_preseed" = "" ]; then
cat << EOF > ./preseed.cfg
### Localization
d-i debian-installer/locale string en_US
d-i console-keymaps-at/keymap select us
d-i keyboard-configuration/xkb-keymap select us

### Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string $preseed_hostname
d-i netcfg/get_domain string lan
d-i netcfg/get_nameservers string $preseed_nameservers

### Mirror settings
# mirror and apt setup
d-i mirror/protocol string http
d-i mirror/country string manual
d-i mirror/http/hostname string $preseed_mirror_url 
d-i mirror/http/directory string /debian
#d-i mirror/suite string stable
#d-i mirror/suite string testing
d-i mirror/suite string unstable
d-i mirror/http/proxy string 

### Apt setup
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true
#d-i apt-setup/use_mirror boolean false
#d-i apt-setup/enable-source-repositories boolean true
d-i apt-setup/disable-cdrom-entries boolean true
d-i apt-setup/services-select multiselect main, security
d-i apt-setup/security_host string $preseed_mirror_url

d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/cdrom/set-next boolean false   
d-i apt-setup/cdrom/set-failed boolean false

### Package selection
tasksel tasksel/first multiselect standard, web-server, kde-desktop
tasksel tasksel/desktop multiselect kde
d-i pkgsel/include string $preseed_package
d-i pkgsel/upgrade select none
d-i pkgsel/language-packs multiselect en, zh
d-i pkgsel/update-policy select none

### Account setup
d-i passwd/root-password password $preseed_password_root
d-i passwd/root-password-again password $preseed_password_root
d-i passwd/user-fullname string $preseed_user
d-i passwd/username string $preseed_user
d-i passwd/user-password password $preseed_password_g
d-i passwd/user-password-again password $preseed_password_g

### Clock and time zone setup
d-i clock-setup/utc boolean false
d-i time/zone string Asia/Shanghai

### Partitioning
d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

popularity-contest popularity-contest/participate boolean false

### Boot loader installation
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

### Finishing up the installation
d-i finish-install/keep-consoles boolean true
d-i finish-install/reboot_in_progress note

EOF
else
    cp $path_preseed $PATH_WORK
fi

#------------------------- set decompreeed iso -----------------------------------
chmod -R +w $PATH_SRC
gunzip $PATH_SRC/install.amd/initrd.gz
echo preseed.cfg | cpio -H newc -o -A -F $PATH_SRC/install.amd/initrd
gzip $PATH_SRC/install.amd/initrd
chmod -w -R $PATH_SRC/install.amd/

#regenerate md5sum
cd $PATH_SRC
chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt

#remove startup menu
sed -i '/default vesamenu.c32/d' isolinux/isolinux.cfg

#------------------------- new iso -----------------------------------
if [ "$path_dst_iso" = "" ]; then
    genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -o $PATH_DST/preseed-$iso_name $PATH_SRC
else
    genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -o $path_dst_iso $PATH_SRC
fi
