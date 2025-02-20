#!/bin/bash

# This script helps set up an Arch Linux installation by prompting the user for details.

# Function to ask for user input
prompt_user() {
    local prompt="$1"
    local variable="$2"
    echo -n "$prompt: "
    read -r $variable
}

# Function to list available disks and prompt user to select one
select_disk() {
    echo "Listing available disks..."
    # List all available disks (excluding partitions)
    available_disks=$(lsblk -d -o NAME,SIZE | grep -v 'NAME' | awk '{print "/dev/" $1 " " $2}')
    
    if [ -z "$available_disks" ]; then
        echo "No disks found!"
        exit 1
    fi
    
    # Show available disks
    echo "$available_disks"
    
    # Ask the user to choose a disk
    prompt_user "Enter the disk to install Arch Linux on (e.g., /dev/sda)" disk

    # Check if the selected disk is in the available disks list
    if [[ ! "$available_disks" =~ "$disk" ]]; then
        echo "Invalid disk selected. Exiting."
        exit 1
    fi

    echo "You have selected $disk."
}

# Function to list available locales and prompt user to select one
select_locale() {
    echo "Listing available locales..."
    
    # Extract available locales from the system
    available_locales=$(locales -a | sort)
    
    if [ -z "$available_locales" ]; then
        echo "No locales found!"
        exit 1
    fi
    
    # Show available locales
    echo "$available_locales"
    
    # Ask the user to choose a locale
    prompt_user "Enter the locale to use (e.g., 'en_US.UTF-8')" locale

    # Check if the selected locale is valid
    if [[ ! "$available_locales" =~ "$locale" ]]; then
        echo "Invalid locale selected. Exiting."
        exit 1
    fi

    echo "You have selected $locale."
}

# Step 1: Basic Information
echo "Welcome to the Arch Linux Setup Script!"
prompt_user "Enter your username" username
prompt_user "Enter your full name" fullname
prompt_user "Enter your password" password

# Step 2: Locale and timezone
echo "Setting up your locale and timezone..."
prompt_user "Enter your timezone (e.g., 'America/New_York')" timezone
echo "Setting the timezone..."
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Set locale using the select_locale function
select_locale

# Set locale (selected by the user)
echo "Setting locale..."
echo "$locale UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$locale" > /etc/locale.conf

# Step 3: Select Disk for Installation
select_disk

# Step 4: Disk Partitioning
echo "Setting up disk partitioning on $disk..."
# Warning before proceeding
echo "WARNING: All data on $disk will be erased."
echo "Do you wish to continue? (y/n)"
read -r confirm
if [[ "$confirm" != "y" ]]; then
    echo "Exiting script. No changes made."
    exit 1
fi

# Partition the disk using GPT (adjust this as necessary)
parted $disk mklabel gpt
parted $disk mkpart primary ext4 0% 100%

# Format the partition
mkfs.ext4 ${disk}1

# Mount the partition
mount ${disk}1 /mnt

# Step 5: Installing the base system
echo "Installing the base system..."
pacstrap /mnt base linux linux-firmware vim

# Step 6: Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Step 7: Chroot and set up the system
echo "Chrooting into the new system..."
arch-chroot /mnt <<EOF

# Set the hostname
prompt_user "Enter your system's hostname" hostname
echo "$hostname" > /etc/hostname

# Set up the root password
echo "Setting up the root password..."
echo "root:$password" | chpasswd

# Add user
echo "Adding user $username..."
useradd -m -G wheel -s /bin/bash "$username"
echo "$username:$password" | chpasswd

# Step 8: Install bootloader
echo "Installing bootloader (GRUB)..."
pacman -S grub os-prober --noconfirm
grub-install --target=i386-pc $disk
grub-mkconfig -o /boot/grub/grub.cfg

# Step 9: Set up the desktop environment
echo "Which desktop environment would you like to install?"
echo "1. GNOME"
echo "2. KDE Plasma"
echo "3. XFCE"
echo "4. LXQt"
prompt_user "Enter your choice (1/2/3/4)" de_choice

case "$de_choice" in
    1)
        echo "Installing GNOME..."
        pacman -S gnome gnome-extra --noconfirm
        systemctl enable gdm
        ;;
    2)
        echo "Installing KDE Plasma..."
        pacman -S plasma kde-applications --noconfirm
        systemctl enable sddm
        ;;
    3)
        echo "Installing XFCE..."
        pacman -S xfce4 xfce4-goodies --noconfirm
        systemctl enable lightdm
        ;;
    4)
        echo "Installing LXQt..."
        pacman -S lxqt --noconfirm
        systemctl enable sddm
        ;;
    *)
        echo "Invalid choice, exiting..."
        exit 1
        ;;
esac

# Step 10: Finalize and exit chroot
echo "Finalizing setup..."
exit

EOF

# Step 11: Reboot
echo "Installation complete. Rebooting your system..."
umount -R /mnt
reboot
