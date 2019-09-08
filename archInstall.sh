!#/bin/bash

lsblk
blockDev=''
rootPW=''
userName=''
userPwd=''
echo -n "Enter path to installation target block device: "
read blockDev
echo -n "Choose root password: "
read rootPW
echo -n "Enter username: "
read userName
echo -n "Enter password for "$userName": "
read userPwd

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
   if parted $blockDev mklabel gpt mkpart primary fat32 1MiB 512MiB set 1 esp on mkpart primary ext4 512MiB 100%
   then
      echo "Done"
   else
      echo "Oh No! Something whent wrong!"
   fi
   echo "Formating the partitions"
   mkfs.fat -F32 "$blockDev"1
   mkfs.ext4 "$blockDev"2   
   mount "$blockDev"2 /mnt
   mkdir /mnt/efi
   mount "$blockDev"1 /mnt/efi

   echo "Please enable multi-lib"
   read response
   vim /etc/pacman.d/pacman.conf
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
