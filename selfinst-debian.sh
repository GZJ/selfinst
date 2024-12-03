#!/bin/bash

#------------------------- global variables -----------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISO_NAME=""

# Directory Structure:
#
# selfinst_[iso name without extension]
# └── [timestamp_randomstring]
#     └── extracted
#
# Paths explanation:
# - ROOT: Project base directory (named after ISO)
# - WORK: Unique directory with timestamp and random string
# - SRC: Extracted contents directory
# - DST: Destination path (can be any ISO path)
PATH_ROOT=""
PATH_WORK=""
PATH_SRC=""
PATH_DST=""

path_src_iso=""
path_dst_iso=""
path_preseed=""
path_data=""

#------------------------- arguments -----------------------------------
parse_arguments() {
    usage() {
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  -s, --source-iso PATH    Path to source ISO (optional)"
        echo "  -p, --preseed PATH       Path to preseed configuration file (optional)"
        echo "  -d, --destination PATH   Path for destination ISO (optional)"
        echo "  --data PATH              Path to additional data (optional)"
        exit 1
    }

    local ARGS=$(getopt -o s:p:d: --long source-iso:,preseed:,destination:,data: -n "$0" -- "$@")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to parse arguments${NC}"
        usage
    fi

    eval set -- "$ARGS"

    while true; do
        case "$1" in
            -s|--source-iso)
                path_src_iso=$(readlink -f "$2")
                shift 2
                ;;
            -p|--preseed)
                path_preseed=$(readlink -f "$2")
                shift 2
                ;;
            -d|--destination)
                path_dst_iso=$(readlink -f "$2")
                shift 2
                ;;
            --data)
                path_data=$(readlink -f "$2")
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                echo -e "${RED}Error: Internal error!${NC}"
                exit 1
                ;;
        esac
    done

    echo -e "========================"
    echo -e "path_src_iso: $path_src_iso"
    echo -e "path_preseed: $path_preseed"
    echo -e "path_dst_iso: $path_dst_iso"
    echo -e "path_data: $path_data"
    echo -e "========================"
}

setup_directories() {
    local path_src_iso="$1"
    local path_dst_iso="$2"
    local path_preseed="$3"
    local path_data="$4"

    if [ -n "$path_src_iso" ]; then
        ISO_NAME=$(basename $path_src_iso)
    else
        get_current_iso_name
    fi

    if [[ -n "$path_preseed" && -n "$path_data" ]]; then
        echo -e "${YELLOW}Warn: Both preseed and data are provided. You need to copy data from /cdrom to /target in the preseed script. Eg: (cp -r /cdrom/[data name] /target/home/[home dir]/)${NC}"
    fi

    timestamp=$(date "+%Y%m%d%H%M%S")
    random_string=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
    PATH_ROOT="$PWD/selfinst_${ISO_NAME%.*}"
    PATH_WORK="$PATH_ROOT/${timestamp}_${random_string}"
    PATH_SRC="$PATH_WORK/extracted"
    PATH_DST="$PATH_WORK"

    echo -e "========================"
    echo -e "ISO_NAME: $ISO_NAME"
    echo -e "PATH_ROOT: $PATH_ROOT"
    echo -e "PATH_WORK: $PATH_WORK"
    echo -e "PATH_SRC: $PATH_SRC"
    echo -e "PATH_DST: $PATH_DST"
    echo -e "========================"

    mkdir -p "$PATH_ROOT" "$PATH_WORK" "$PATH_SRC" "$PATH_DST"  || { echo -e "${RED}Error: Failed to create directories${NC}"; exit 1; }
}

get_current_iso_name() {
    ISO_NAME=$(wget -q -O - https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/ \
        | grep -oP 'debian-\d+\.\d+\.\d+-amd64-netinst\.iso' \
        | sort -r \
        | head -n 1)

    if [ -z "$ISO_NAME" ]; then
        echo -e "${RED}Error: Failed to find the latest ISO name${NC}"
        exit 1
    fi
}

#------------------------- fetch iso -----------------------------------
fetch_iso() {
    local path_src_iso="$1"
    local iso

    cd "$PATH_ROOT"
    if [ -z "$path_src_iso" ]; then
        if [ ! -f "$ISO_NAME" ]; then
            wget "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/$ISO_NAME"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to download $ISO_NAME ${NC}"
                exit 1
            fi

            wget "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to download SHA512SUMS${NC}"
                exit 1
            fi

            local computed_checksum=$(sha512sum "$ISO_NAME" | awk '{ print $1 }')
            local expected_checksum=$(grep "$ISO_NAME" SHA512SUMS | awk '{ print $1 }')
            if [ "$computed_checksum" != "$expected_checksum" ]; then
                echo -e "${RED}Error: ISO sha512 checksum does not match!${NC}"
                exit 1
            fi

            echo "ISO checksum verified successfully!"
            iso="$PATH_ROOT/$ISO_NAME"
        else
            iso="$PATH_ROOT/$ISO_NAME"
        fi
    else
        if [ ! -e "$path_src_iso" ]; then
            echo -e "${RED}Error: Source ISO file $path_src_iso does not exist!${NC}"
            exit 1
        fi
        iso="$path_src_iso"
    fi

    cat $iso | bsdtar -C "$PATH_SRC" -xf -
}

#------------------------- preseed -----------------------------------
create_preseed_config() {
    local path_preseed="$1"
    local path_data_name=$(basename $2)

    local preseed_hostname="selfinst"
    local preseed_nameservers="114.114.114.114"
    local preseed_mirror_url="mirrors.ustc.edu.cn"
    local preseed_password_root="selfinstroot"
    local preseed_user="g"
    local preseed_password_g="selfinstg"
    local preseed_timedate="Asia/Shanghai"
    local preseed_package="openssh-server build-essential vim syncthing barrier"

    if [ -z "$path_preseed" ]; then
        cat << EOF > "$PATH_WORK/preseed.cfg"
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
d-i time/zone string $preseed_timedate

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

d-i preseed/late_command string \\
    cp -r /cdrom/$path_data_name /target/home/$preseed_user/
EOF
    else
        cp "$path_preseed" "$PATH_WORK"
    fi
}

#------------------------- prepare iso -----------------------------------
prepare_iso() {
    local path_data="$1"

    cd "$PATH_WORK"
    chmod -R +w "$PATH_SRC"
    gunzip "$PATH_SRC/install.amd/initrd.gz"
    echo preseed.cfg | cpio -H newc -o -A -F "$PATH_SRC/install.amd/initrd"
    gzip "$PATH_SRC/install.amd/initrd"
    chmod -w -R "$PATH_SRC/install.amd/"

    if [ -n "$path_data" ] ; then
        cp -rf "$path_data" "$PATH_SRC"
    fi

    cd "$PATH_SRC"
    chmod +w md5sum.txt
    find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
    chmod -w md5sum.txt

    sed -i '/default vesamenu.c32/d' isolinux/isolinux.cfg
}

#------------------------- new iso -----------------------------------
create_new_iso() {
    local path_dst_iso="$1"
    local src="$PATH_SRC"
    local dst

    cd "$PATH_SRC"
    if [ -z "$path_dst_iso" ]; then
        dst="$PATH_DST/preseed-$ISO_NAME"
    else
        dst="$path_dst_iso"
    fi
    genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -o "$dst" "$src"
}

#------------------------- main -----------------------------------
main() {
    echo -e "${GREEN}---------------- args -------------------- ${NC}"
    parse_arguments "$@"

    echo -e "${GREEN}---------------- directories -------------------- ${NC}"
    setup_directories "$path_src_iso" "$path_dst_iso" "$path_preseed" "$path_data"

    echo -e "${GREEN}---------------- fetch iso -------------------- ${NC}"
    fetch_iso "$path_src_iso"

    echo -e "${GREEN}---------------- preseed -------------------- ${NC}"
    create_preseed_config "$path_preseed" "$path_data"

    echo -e "${GREEN}---------------- prepare iso -------------------- ${NC}"
    prepare_iso "$path_data"

    echo -e "${GREEN}---------------- new iso -------------------- ${NC}"
    create_new_iso "$path_dst_iso"

    echo -e "${GREEN}ISO creation completed successfully!${NC}"
}

main "$@"
