#!/bin/sh
#------------------------------------------------------------------------------
# File name:		ais.sh
# Created:			2020-03-28 14:34
# Author:           jon@jonmed.xyz
# Last modified:	2020-04-05 10:43
#
# Description:
#------------------------------------------------------------------------------

init()
{
    LOG="ais.log"
    TMP="/tmp/ais.tmp"
    MOUNT_POINT="/mnt/ais"

    [ -f "$LOG" ] && rm "$LOG"
    [ -f "$TMP" ] && rm "$TMP"

    TITLE="AIS - Arch Install Script - jonmed.xyz/ais.sh"
    DIALOGOPTS="--cr-wrap --colors --backtitle \"${TITLE}\""
    export DIALOGOPTS

    DIALOG_OK=0
    DIALOG_CANCEL=1
    DIALOG_EXTRA=3
    DIALOG_ESC=255
}

msg()
{
    for line do
        printf "%s\n" "$line"
    done
}

abort()
{
    message=$(msg "${1}" \
                  "\n" \
                  "Installation \Z1failed\Zn to complete." \
                  "You can check the log file \Z4${LOG}\Zn for more detailed" \
                  "error messages." \
                  "\n" \
                  "Make sure:" \
                  "* You are running an \ZbArch Linux\ZB environment." \
                  "* You have \Zbroot\ZB privileges." \
                  "* You have an \Zbinternet connection\ZB.")
    dialog --title "Installation Failed" --msgbox "$message" 15 60
    echo "$1" >> "$LOG"
    echo "Aborting." >> "$LOG"
    finish 1
}

exit_install()
{
    message="Do you want to exit the installer?" 
    if dialog --title "Exit Installer" --yesno "$message" 0 0; then
        finish 0
    fi
}

greeting()
{
    while true; do
        message=$(msg "This script will facilitate the installation of" \
                      "\Z4Arch Linux.\Zn" \
                      "\n" \
                      "It will only work if:" \
                      "* You are running an \ZbArch Linux\ZB environment." \
                      "* You have \Zbroot\ZB privileges." \
                      "* You have an \Zbinternet connection\ZB.")
        if dialog --title "AIS" --yes-label "OK" --no-label "Exit" \
                --yesno "$message" 11 60; then
            break
        else
            exit_install
        fi 
    done
}

check_connection()
{
    while ! ping -w1 -c1 "www.archlinux.org" >/dev/null; do
        while true; do
            wired_dev=$(ip link | awk '/ens|eno|enp/ {print $2}' | sed 's/://;1!d')
            wireless_dev=$(ip link | awk '/wlp/ {print $2}' | sed 's/://;1!d')
            message=$(msg "\Z1Network connection not found.\Zn" \
                          "\n" \
                          "Choose which type of connection to setup:")
            exec 3>&1
            result=$(dialog --title "Error" --cancel-label "Exit" \
                --menu "$message" 0 0 0 \
                "Wired"     "" \
                "Wireless"  "" 2>&1 1>&3)
            code="$?"
            exec 3>&-
            if [ "$code" -ne "${DIALOG_OK}" ]; then
                exit_install
            else
                case "$result" in
                    Wired)    systemctl start dhcpcd@"${wired_dev}".service >/dev/null;;
                    Wireless) wifi-menu "${wireless_dev}";;
                esac
                dialog --infobox "Checking connection..." 0 0; sleep 1
                break
            fi
        done
    done
}

install_req_pack()
{
    dialog --title "Installing Required Package" --infobox "Installing $1 package..." 3 60
    pacman --noconfirm --needed -S "$1" >/dev/null || \
        abort "pacman failed to install the required package: ${1}."
}

requirements()
{
    check_connection
    req_packs=$(msg "arch-install-scripts" \
                    "parted" \
                    "gdisk" \
                    "ntfs-3g" \
                    "dialog" \
                    "pacman-contrib" \
                    "archlinux-keyring")
    echo "$req_packs" >"$TMP"
    while read -r pack; do
        install_req_pack "$pack"
    done < "$TMP"
}

sync_clock()
{
    dialog --title "Synchronizing Clock" --infobox "Activating NTP..." 0 0
    timedatectl set-ntp true
}

choose_device()
{
    while true; do
        devices=$(lsblk -dnp -o NAME,SIZE,MODEL | \
            awk '{printf("%s \"%6s %s\"\n", $1, $2, $3)}')
        echo "$devices" > "$TMP"
        exec 3>&1
        result=$(dialog --title "Devices" --cancel-label "Back" --menu \
            "Choose a device to partition:" 0 0 0 --file "$TMP" 2>&1 1>&3)
        code="$?"
        exec 3>&-
        [ "$code" -ne "${DIALOG_OK}" ] && return
        device="$result"
        clear
        [ "$prog" = "parted" ] && parted -a opt "$device" || "$prog" "$device"
        clear
    done
}

partition_menu()
{
    while true; do
        exec 3>&1
        result=$(dialog --title "Partitioning" --cancel-label "Exit" \
            --extra-button --extra-label "Skip" --menu \
            "If you want to partition a device choose a program:" 0 0 0 \
            "gdisk" "" \
            "parted" "" 2>&1 1>&3)
        code="$?"
        exec 3>&-
        prog="$result"
        case "$code" in
            "${DIALOG_ESC}"|"${DIALOG_CANCEL}") exit_install; continue ;;
            "${DIALOG_EXTRA}")  break ;;
        esac
        choose_device
    done
}

file_system_menu()
{
    exec 3>&1
    result=$(dialog --title "File System" --cancel-label "Back" --extra-button \
        --extra-label "Skip" --menu \
        "If you want to format ${partition}, choose a file system:" 0 0 0 \
        "ext4"  "" \
        "fat32" "" \
        "ntfs"  "" 2>&1 1>&3)
    code="$?"
    exec 3>&-
    case "$code" in
        "${DIALOG_ESC}"|"${DIALOG_CANCEL}") return "$code" ;;
        "${DIALOG_EXTRA}")                  return "${DIALOG_OK}";;
    esac
    format="$result"

    exec 3>&1
    result=$(dialog --title "Label" --no-cancel --inputbox \
        "Type a label for the new file system (leave empty for no label):" 0 0 2>&1 1>&3)
    exec 3>&-
    label="$result"

    message=$(msg "Are you sure you want to format partition \Zb${partition}\ZB" \
                  "with the ${format} file system?" \
                  "\n" \
                  "All data in the partition will be \Z1LOST\Zn." \
                  "This \Z1can not\Zn be undone.")
    exec 3>&1
    result=$(dialog --title "Attention!" --yesno "$message" 0 0 2>&1 1>&3)
    code="$?"
    exec 3>&-
    [ "$code" -ne "${DIALOG_OK}" ] && return "$code"

    message="Formating $partition with $format file system..."
    dialog --infobox "$message" 0 0
    mp=$(lsblk -lnp -o NAME,MOUNTPOINT | awk -v part="$partition" \
        '$0~part{print $2}')
    [ -n "$mp" ] && { umount -R "$mp" >dev/null || abort "Could not unmount ${mp}."; }
    case "$format" in
        ext4)   mkfs.ext4"${label:+ -L $label}" "$partition" >/dev/null || \
                    abort "Could not format ${partition}";;
        fat32)  mkfs.vfat"${label:+ -F32 -n $label}" "$partition" >/dev/null || \
                    abort "Could not format ${partition}";;
        ntfs)   mkfs.ntfs"${label:+ -L $label}" "$partition" >/dev/null || \
                    abort "Could not format ${partition}";;
    esac
    message="${message} Done!"
    dialog --infobox "$message" 0 0; sleep 1
}

umount_loop()
{
    dialog --infobox "Unmounting ${partition}..." 0 0
    while true; do
        mp=$(lsblk -lnp -o NAME,MOUNTPOINT | awk -v part="$partition" \
            '$0~part{print $2}')
        if [ -n "$mp" ]; then
            umount -R "$mp" >/dev/null || abort "Could not umount ${mp}." 
        else
            break
        fi
    done
}

mount_root_menu()
{
    while true; do
        partitions=$(lsblk -lnp -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,MOUNTPOINT | \
            awk '/part/ {printf("%s \"%6s %4s %8.8s %s\"\n",$1,$2,$4,$5,$6)}')
        echo "$partitions" > "$TMP"
        exec 3>&1
        result=$(dialog --title "Mount root" --cancel-label "Exit" --menu \
            "Choose a partition to mount the root directory:" 0 0 0 \
            --file "$TMP" 2>&1 1>&3)
        code="$?"
        exec 3>&-
        case "$code" in
            "${DIALOG_ESC}"|"${DIALOG_CANCEL}") exit_install; continue ;;
        esac
        partition="$result"

        if file_system_menu; then
            message="Mounting $partition at (\Zb/\ZB)..."
            dialog --infobox "$message" 0 0
            mkdir -p "${MOUNT_POINT}"
            umount_loop "${MOUNT_POINT}"
            mount "$partition" "${MOUNT_POINT}" >/dev/null || \
                abort "Failed to mount ${partition} at ${MOUNT_POINT}."
            message="${message} Done!"
            dialog --infobox "$message" 0 0; sleep 1
            break
        fi
    done
}

start_setup()
{
    partition_menu
    mount_root_menu
    finish 0
}

finish()
{
    dialog --infobox "Exiting..." 0 0
    [ -f "$TMP" ] && rm "$TMP"
    
    if [ -d "${MOUNT_POINT}" ]; then
        umount -R "${MOUNT_POINT}" >/dev/null
        rm -r "${MOUNT_POINT}" >/dev/null
    fi
    sleep 1; clear; exit "$1"
}

# Start of script -----------------------------------------

init
greeting
{
requirements
sync_clock
start_setup
} 2>>"$LOG"
