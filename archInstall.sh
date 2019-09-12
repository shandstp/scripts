#!/bin/bash

hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
: ${hostname:?"hostname cannot be empty"}
rootPass=$(dialog --stdout --passwordbox "Enter root password" 0 0) || exit 1
: ${rootPass:?"password cannot be empty"}
rootPass2=$(dialog --stdout --passwordbox "Re-enter root password" 0 0) || exit 1
: ${rootPass:?"password cannot be empty"}

[[ "$rootPass" == "$rootPass2" ]] || $(dialog --stdout --msgbox "Password did not match" 0 0)

while   [[ "$rootPass" != "$rootPass2" ]]; do
	rootPass=$(dialog --stdout --passwordbox "Enter root password" 0 0) || exit 1
	: ${rootPass:?"password cannot be empty"}
	rootPass2=$(dialog --stdout --passwordbox "Re-enter root password" 0 0) || exit 1
	: ${rootPass:?"password cannot be empty"}

	[[ "$rootPass" == "$rootPass2" ]] || $(dialog --stdout --msgbox "Password did not match" 0 0)
done

username=$(dialog --stdout --inputbox "Enter username" 0 0) || exit 1
: ${username:?"username cannot be empty"}
userPass=$(dialog --stdout --passwordbox "Enter user password" 0 0) || exit 1
: ${userPass:?"password cannot be empty"}
userPass2=$(dialog --stdout --passwordbox "Re-enter user password" 0 0) || exit 1
: ${userPass:?"password cannot be empty"}

[[ "$userPass" == "$userPass2" ]] || $(dialog --stdout --msgbox "Password did not match" 0 0)

while   [[ "$userPass" != "$userPass2" ]]; do
	userPass=$(dialog --stdout --passwordbox "Enter user password" 0 0) || exit 1
	: ${userPass:?"password cannot be empty"}
	userPass2=$(dialog --stdout --passwordbox "Re-enter user password" 0 0) || exit 1
	: ${userPass:?"password cannot be empty"}

	[[ "$userPass" == "$userPass2" ]] || $(dialog --stdout --msgbox "Password did not match" 0 0)
done

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1

parted "${device}"
#parted ${device} print

partlist=$(fdisk -l | grep -Ev Disk | grep -E "(/dev/[a-zA-Z0-9]*)" | gawk '{ print $1, "\t", $5, "\n" }')
echo $partlist
#exit
part_boot=$(dialog --stdout --menu "Select boot partition" 0 0 0 ${partlist}) || exit 1
part_root=$(dialog --stdout --menu "Select root partition" 0 0 0 ${partlist}) || exit 1

dualBoot=$(dialog --stdout --yesno "Are you dual-booting on the same disk as Windows" 0 0)
response=$?
case $response in
	0) echo "Nothing to do here then";;
	1) mkfs.vfat -F32 "${part_boot}";;
	255) echo "You decided you'd rather not say";;
esac

if mkfs.ext4 "${part_root}"; then
	echo "Successfully formated root partition"
elif lsblk -f | grep ext4; then
	echo "Already formated"
else
	echo "Formatting root partition failed"
	exit
fi

if mount "${part_root}" /mnt; then
	echo "Root partition mounted"
else
	echo "Oops, root partition failed to mount"
	exit
fi

mkdir /mnt/boot
if mount "${part_boot}" /mnt/boot; then
	echo "Boot partition mounted successfully"
else
	echo "Failed while mounting boot partition"
	exit
fi

if pacstrap /mnt base base-devel os-prober grub efibootmgr intel-ucode nvidia xorg gnome gnome-extra fcitx-mozc fcitx-im fcitx-ui-light fcitx-table-extra fcitx-table-other fcitx-configtool pacman-contrib vim adobe-source-han-sans-cn-fonts adobe-source-han-sans-hk-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts adobe-source-han-sans-tw-fonts adobe-source-han-serif-cn-fonts adobe-source-han-serif-jp-fonts adobe-source-han-serif-kr-fonts adobe-source-han-serif-tw-fonts noto-fonts ttf-droid ttf-hanazono ttf-sazanami; then
	echo "Finished install base OS"
else
	echo "Something fucked up"
	exit
fi

arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=archLinux
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
arch-chroot /mnt useradd -m -s /bin/bash -g users -G wheel,uucp,video,audio,storage,games,input "$username"
#arch-chroot /mnt chsh -s /usr/bin/zsh

echo "$username:$userPass" | chpasswd --root /mnt
echo "root:$rootPass" | chpasswd --root /mnt

arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt systemctl enable gdm

arch-chroot /mnt timedatectl set-ntp true
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
arch-chroot /mnt sed -i s/"#en_US.UTF-8 UTF-8"/"en_US.UTF-8 UTF-8"/ /etc/locale.gen
arch-chroot /mnt sed -i s/"#ja_JP.UTF-8 UTF-8"/"ja_JP.UTF-8 UTF-8"/ /etc/locale.gen
arch-chroot /mnt sed -i s/"# %wheel ALL=(ALL) ALL"/"%wheel ALL=(ALL) ALL"/ /etc/sudoers
arch-chroot /mnt locale-gen

echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
echo "127.0.0.1	localhost" >> /mnt/etc/hosts
echo "::1	localhost" >> /mnt/etc/hosts
echo "127.0.1.1	${hostname}.localdomain	${hostname}" >> /mnt/etc/hosts


echo "GTK_IM_MODULE=fcitx" >> /mnt/home/${username}/.pam_environment
echo "QT_IM_MODULE=fcitx" >> /mnt/home/${username}/.pam_environment
echo "XMODIFIERS=@im=fcitx" >> /mnt/home/${username}/.pam_environment
arch-chroot /mnt chown ${username} /home/${username}/.pam_environment

arch-chroot /mnt sed -i s/"#\[multilib\]"/"\[multilib\]"/ /etc/pacman.conf
arch-chroot /mnt sed -i s/"#Include = /etc/pacman.d/mirrorlist"/"Include = /etc/pacman.d/mirrorlist"/ /etc/pacman.conf

arch-chroot /mnt pacman -Syu steam steam-native-runtime firefox lib32-nvidia-utils nvidia-settings

echo "That should about do it. Rebooting..."
#reboot
echo "Or not... Standing by"
