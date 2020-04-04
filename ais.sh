#!/bin/sh
#------------------------------------------------------------------------------
# File name:		ais.sh
# Created:			2020-03-28 14:34
# Author:           jon@jonmed.xyz
# Last modified:	2020-04-04 14:04
#
# Description:
#------------------------------------------------------------------------------

init()
{
    LOG="ais.log"
    TMP="/tmp/ais.tmp"

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
                  "error messages.")
    dialog --title "Installation Failed" --msgbox "$message" 9 60
    dialog --infobox "Exiting..." 0 0
    echo "$1" >> "$LOG"
    echo "Aborting." >> "$LOG"
    finish; sleep 1; clear; exit 1
}

exit_install()
{
    message="Do you want to exit the installer?" 
    if dialog --title "Exit Installer" --yesno "$message" 0 0; then
        dialog --infobox "Exiting..." 0 0
        finish; sleep 1; clear; exit 0
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
                      "* You have \Zbroot\ZB privileges."
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
        abort "pacman failed to install the $1 required package."
}

requirements()
{
    check_connection
    req_packs=$(msg "dialog" \
                    "parted" \
                    "ntfs-3g" \
                    "arch-install-scripts" \
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
        result=$(dialog --title "Partitions" --menu \
            "Choose a device to partition:" 0 0 0 --file "$TMP" 2>&1 1>&3)
        code="$?"
        exec 3>&-
        [ "$code" -ne "${DIALOG_OK}" ] && return "$code"
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
        result=$(dialog --title "Partitions" --cancel-label "Exit" \
            --extra-label "Skip" --menu \
            "If you want to partition a device choose a program:" 0 0 0 \
            "cgdisk" "" \
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
        [ "$?" -eq "${DIALOG_EXTRA}" ] && break
    done
}

start_setup()
{
    partition_menu
    finish
}

finish()
{
    [ -f "$TMP" ] && rm "$TMP"
}

# Start of script -----------------------------------------

init
greeting
{
requirements
sync_clock
start_setup
} 2>>"$LOG"
