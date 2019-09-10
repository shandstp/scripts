#!/bin/bash

hostname=$(dialog --stdout --inputbox "Enter hostname" 0 0) || exit 1
: ${hostname:?"hostname cannot be empty"}

rootPass=$(dialog --stdout --passwordbox "Enter root password" 0 0) || exit 1
: ${rootPass:?"root password cannot be empty"}

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1

echo "Your hostname is $hostname"
echo "You entered $rootPass as your root password"
echo "Available devices are as follows: $devicelist"
echo "The one you chose was $device"
