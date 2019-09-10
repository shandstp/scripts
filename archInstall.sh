#!/bin/bash
echo -n "Hostname: "
read hostname
: "${hostname:?"Missing hostname"}"
lsblk
echo -n "Enter path to installation target block device: "
read blockDev
parted $blockDev print
echo -n "Enter starting megabyte of Linux partition: "
read firstByte
echo -n "Enter the new partition number: "
read partNum
echo -n "Choose root password: "
read -s rootPW
echo
echo -n "Repeat Password: "
read -s rootPW2
echo
[[ "$rootPW" == "$rootPW2" ]] || (echo "Passwords did not match"; exit 1; )
echo -n "Enter username: "
read userName
echo -n "Enter password for "$userName": "
read -s userPwd
echo
echo -n "Repeat Password: "
read -s userPwd2
echo
[[ "$userPwd" == "$userPwd2" ]] || ( echo "Passwords did not match"; exit 1; )

echo "Verifying boot mode and internet connection"
if ls /sys/firmware/efi/efivars && ping -c 4 archlinux.org
then
   echo "Looks fine"
   echo "Setting ntp to true"
   if timedatectl set-ntp true
   then 
      echo "Done"
   else 
      echo "Oops, something went wrong"
   fi
   echo "Creating partitions"
   if parted $blockDev mkpart primary ext4 $firstByte 100%
   then
      echo "Done"
   else
      echo "Oh No! Something whent wrong!"
   fi
   echo "Formating the partitions"
  # mkfs.fat -F32 "$blockDev"1
   mkfs.ext4 "$blockDev"$partNum   
   mount "$blockDev"$partNum /mnt
   mkdir /mnt/efi
   mount "$blockDev"p2 /mnt/efi

   echo "Please enable multi-lib"
   read response
   vim /etc/pacman.conf
   pacstrap /mnt base base-devel os-prober grub efibootmgr intel-ucode nvidia lib32-nvidia-utils xorg xorg-apps gnome gnome-extra
   
   echo "Generating /etc/fstab"
   genfstab -U /mnt >> /mnt/etc/fstab
   
   echo "Attempting to export variables"
   export blockDev
   export rootPW
   export userName
   export userPwd
   echo "Entering chroot"
    
   arch-chroot /mnt
   ln -sf /usr/share/zoneinfo/America/Los_Angelos /etc/localtime
   hwclock --systohc
   echo "Please uncomment en_US.UTF-8 UTF-8 and the Japanese one"
   read response
   vim /etc/locale.gen
   #touch /etc/locale.conf
   echo "LANG=en_US.UTF-8" >> /etc/locale.conf
   echo "dArch" >> /etc/hostname
   echo "Please update /etc/hosts as needed"
   read response
   vim /etc/hosts
   
   passwd;$rootPW;$rootPW
   grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-if=archLinux
   grub-mkconfig -o /boot/grub/grub.cfg
   useradd -m -g users -G wheel -s /bin/bash $userName
   passwd $userName;$userPwd;$userPwd
   
   systemctl enable NetworkManager
   systemctl enable gdm
   
   exit
   umount -R /mnt
   reboot
fi
