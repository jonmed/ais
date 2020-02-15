#!/bin/sh

set_defaults()
{
    # Terminal font 
    Bold=$(tput bold)
    Reset=$(tput sgr0)
    Cyan=$(tput setaf 6)

    root_label="arch"
    esp_label="ESP"
    home_label="home"

    mount_point="/mnt"
    esp_mp="${mount_point}/boot"
    home_mp="${mount_point}/home"
    win_mp="${mount_point}/mnt/win"

    esp_part="/dev/sda2"
    win_part="/dev/sda4"

    host_name="archlinux"
    hosts="127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t${host_name}.localdomain ${host_name}"
    time_zone="America/Recife"
    country_code="BR"

    title="AIS - Archlinux Installation Script - jonmed.xyz/ais.sh"
    ext4_args="-F -m 0 -T big"
    mirrorlist="/etc/pacman.d/mirrorlist"
    mirror_url="https://www.archlinux.org/mirrorlist/?country=${country_code}&use_mirror_status=on"
    base_packages="base base-devel linux linux-firmware amd-ucode ntfs-3g dhcpcd"
    swap_size="512M"
    trim_rule="ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"deadline\""
    loader_conf="default\tarch\ntimeout\t3\neditor\t0\n"
    arch_conf="title\tArch Linux\nlinux\t/vmlinuz-linux\ninitrd\t/amd-ucode.img\ninitrd\t/initramfs-linux.img\noptions\troot=PARTLABEL=${root_label} rw\n"
}

print_line()
{
    printf "%$(tput cols)s\n" | tr ' ' '-'
}

print_bold()
{
    printf "${Bold}:: $1${Reset}\n\n"
}

print_title()
{
    clear
    print_line
    printf "  ${Bold}$1${Reset}\n"
    print_line
    printf "\n"
}

print_command()
{
    printf "${Bold}\$${Reset} ${Cyan}${1}${Reset}\n\n"
}

read_key()
{
    stty_old=$(stty -g)
    stty raw -echo min 1 time 0
    printf '%s' $(dd bs=1 count=1 2>/dev/null)
    stty $stty_old
}

wait_key()
{
    sleep 1
    printf "\n"
    print_line
    if [ "$1" = "" ]; then
        printf "Press any key to continue (q to quit)..."
    else
        printf "$1"
    fi
    continue_key=$(read_key)
    if [ "$continue_key" = "q" ]; then
        printf "\nExiting AIS...\n"
        umount -R ${mount_point}
        exit 1
    fi
    print_title "$title"
}

arch_chroot()
{
    arch-chroot ${mount_point} sh -c "${1}"
}

sync_time()
{
    print_bold "Syncing time"
    print_command "timedatectl set-ntp true"
    timedatectl set-ntp true
    wait_key
}

format_partitions()
{
    print_bold "Formating partitions"
    print_command "mkfs.ext4 ${ext4_args} -L ${root_label} /dev/disk/by-partlabel/${root_label}"
    mkfs.ext4 ${ext4_args} -L ${root_label} /dev/disk/by-partlabel/${root_label}
    printf "\n"

    #print_command "mkfs.ext4 ${ext4_args} -L ${home_label} /dev/disk/by-partlabel/${home_label}"
    #mkfs.ext4 ${ext4_args} -L ${home_label} /dev/disk/by-partlabel/${home_label}
    wait_key
}

mount_partitions()
{
    print_bold "Mounting partitions"
    print_command "umount -R ${mount_point}"
    umount -R ${mount_point}
    printf "\n"

    print_command "mount -v PARTLABEL=${root_label} ${mount_point}"
    mount -v PARTLABEL=${root_label} ${mount_point}
    printf "\n"

    print_command "mkdir -vp ${esp_mp}"
    mkdir -vp ${esp_mp}
    printf "\n"

    print_command "mount -v ${esp_part} ${esp_mp}"
    mount -v ${esp_part} ${esp_mp}
    printf "\n"

    #print_command "mkdir -vp ${home_mp}"
    #mkdir -vp ${home_mp}
    #printf "\n"

    #print_command "mount -v PARTLABEL=${home_label} ${home_mp}"
    #mount -v PARTLABEL=${home_label} ${home_mp}
    #printf "\n"

    print_command "mkdir -vp ${win_mp}"
    mkdir -vp ${win_mp}
    printf "\n"

    print_command "mount -v ${win_part} ${win_mp}"
    mount -v ${win_part} ${win_mp}
    wait_key
}

config_mirrorlist()
{
    print_bold "Config mirrorlist"
    print_command "pacman -Syy"
    pacman -Syy
    printf "\n"

    print_command "pacman --noconfirm --needed -S pacman-contrib"
    pacman --noconfirm --needed -S pacman-contrib
    printf "\n"

    print_command "cp -v ${mirrorlist} ${mirrorlist}.backup"
    cp -v ${mirrorlist} ${mirrorlist}.backup
    printf "\n"

    print_command "curl \"${mirror_url}\" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > ${mirrorlist}"
    curl ${mirror_url} | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > ${mirrorlist}
    printf "\n"

    print_command "cat ${mirrorlist}"
    cat ${mirrorlist}
    wait_key
}

clean_esp()
{
    print_bold "Cleaning ESP"
    print_command "rm -v ${esp_mp}/vmlinuz-linux"
    rm -v ${esp_mp}/vmlinuz-linux
    printf "\n"

    print_command "rm -v ${esp_mp}/*.img"
    rm -v ${esp_mp}/*.img
    wait_key
}

install_base()
{
    print_bold "Installing base system"
    print_command "sed -i -e 's/^#Color/Color/;s/^#TotalDownload/TotalDownload/' /etc/pacman.conf"
    sed -i -e 's/^#Color/Color/;s/^#TotalDownload/TotalDownload/' /etc/pacman.conf

    print_command "pacstrap ${mount_point} ${base_packages}"
    pacstrap ${mount_point} ${base_packages}
    wait_key
}

create_swap()
{
    print_bold "Creating swap file"
    print_command "(chroot) fallocate -l ${swap_size} /swapfile"
    arch_chroot "fallocate -l ${swap_size} /swapfile"
    printf "\n"

    print_command "(chroot) chmod 600 /swapfile"
    arch_chroot "chmod 600 /swapfile"
    printf "\n"

    print_command "(chroot) mkswap /swapfile"
    arch_chroot "mkswap /swapfile"
    printf "\n"

    print_command "(chroot) swapon /swapfile"
    arch_chroot "swapon /swapfile"
    wait_key
}

generate_fstab()
{
    print_bold "Generate fstab"
    print_command "genfstab -t PARTUUID -p ${mount_point} > ${mount_point}/etc/fstab"
    genfstab -t PARTUUID -p ${mount_point} > ${mount_point}/etc/fstab
    printf "\n"

    # /mnt/swapfile -> /swapfile
    print_command "sed -i \"s/\\${mount_point}//\" ${mount_point}/etc/fstab"
    sed -i "s/\\${mount_point}//" ${mount_point}/etc/fstab

    print_command "cat ${mount_point}/etc/fstab"
    cat ${mount_point}/etc/fstab
    wait_key
}

set_hostname()
{
    print_bold "Setting hostname"
    print_command "echo $host_name > ${mount_point}/etc/hostname"
    echo $host_name > ${mount_point}/etc/hostname

    print_command "cat ${mount_point}/etc/hostname"
    cat ${mount_point}/etc/hostname
    printf "\n"
    
    print_command "printf \${hosts} > /etc/hosts"
    printf "${hosts}" > ${mount_point}/etc/hosts
    cat ${mount_point}/etc/hosts
    wait_key
}

set_timezone()
{
    print_bold "Setting time zone"
    print_command "(chroot) ln -svf /usr/share/zoneinfo/${time_zone} /etc/localtime"
    arch_chroot "ln -svf /usr/share/zoneinfo/${time_zone} /etc/localtime"
    wait_key
}

set_clock()
{
    print_bold "Setting system clock"
    print_command "(chroot) hwclock -wu"
    arch_chroot "hwclock -wu"
    wait_key
}

set_locale()
{
    print_bold "Setting locale"
    print_command "sed -i 's/^#en_US/en_US/' ${mount_point}/etc/locale.gen"
    sed -i 's/^#en_US/en_US/' ${mount_point}/etc/locale.gen

    print_command "echo \"LANG=en_US.UTF-8\" > ${mount_point}/etc/locale.conf"
    echo "LANG=en_US.UTF-8" > ${mount_point}/etc/locale.conf

    print_command "cat ${mount_point}/etc/locale.conf"
    cat ${mount_point}/etc/locale.conf
    printf "\n"

    print_command "(chroot) locale-gen"
    arch_chroot "locale-gen"
    wait_key
}

set_trimming()
{
    print_bold "Setting trimming"
    print_command "(chroot) systemctl enable fstrim.timer"
    arch_chroot "systemctl enable fstrim.timer"
    printf "\n"

    print_command "printf \"${trim_rule}\" > ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    printf "${trim_rule}" > ${mount_point}/etc/udev/rules.d/60-schedulers.rules

    print_command "cat ${mount_point}/etc/udev/rules.d/60-schedulers.rules"
    cat ${mount_point}/etc/udev/rules.d/60-schedulers.rules
    wait_key
}

networking()
{
    print_bold "Enabling networking"
    print_command "(chroot) systemctl enable dhcpcd.service"
    arch_chroot "systemctl enable dhcpcd.service"
    wait_key
}

copy_pacmanconf()
{
    print_bold "Copying pacman.conf"
    print_command "cp -v /etc/pacman.conf ${mount_point}/etc/pacman.conf"
    cp -v /etc/pacman.conf ${mount_point}/etc/pacman.conf
    wait_key
}

set_root_pass()
{
    print_bold "Setting root password"
    while true # will exit after passwd return 0 (success)
    do
        print_command "(chroot) passwd"
        arch_chroot "passwd"
        if [ $? -eq 0 ]; then
            break
        fi
        wait_key "Press any key to retry (q to quit)..."
    done
    wait_key
}

config_bootloader()
{
    print_bold "Configuring bootloader"
    print_command "(chroot) bootctl install"
    arch_chroot "bootctl install"
    printf "\n"

    print_command "printf \"${loader_conf}\" > ${esp_mp}/loader/loader.conf"
    printf "${loader_conf}" > ${esp_mp}/loader/loader.conf 

    print_command "cat ${esp_mp}/loader/loader.conf"
    cat ${esp_mp}/loader/loader.conf
    printf "\n"

    print_command "printf \"${arch_conf}\" > ${esp_mp}/loader/entries/arch.conf"
    printf "${arch_conf}" > ${esp_mp}/loader/entries/arch.conf

    print_command "cat ${esp_mp}/loader/entries/arch.conf"
    cat ${esp_mp}/loader/entries/arch.conf
    wait_key
}

finish()
{
    umount -R ${mount_point}
    printf "\n"
    print_bold ":: Installation finished"
}

setup()
{
    print_title "$title"

    sync_time
    format_partitions
    mount_partitions
    config_mirrorlist
    clean_esp
    install_base
    create_swap
    generate_fstab
    set_hostname
    set_timezone
    set_clock
    set_locale
    set_trimming
    networking
    copy_pacmanconf
    config_bootloader
    set_root_pass
    finish
}

set_defaults
setup

# vim: fdm=syntax
#let g:sh_fold_enabled=1
