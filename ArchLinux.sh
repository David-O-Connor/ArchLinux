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

# Function to set locale for Ireland
set_locale() {
    locale="en_IE.UTF-8"
    echo "Setting locale to $locale."
    echo "$locale UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=$locale" > /etc/locale.conf
}

# Function to set the timezone
set_timezone() {
    prompt_user "Enter your timezone (e.g., 'Europe/Dublin')" timezone
    echo "Setting the timezone..."
    ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
    hwclock --systohc
}

# Function to set basic information
set_basic_info() {
    echo "Welcome to the Arch Linux Setup Script!"
    prompt_user "Enter your username" username
    prompt_user "Enter your full name" fullname
    prompt_user "Enter your password" password
}

# Function to partition the disk
partition_disk() {
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
}

# Function to install the base system
install_base_system() {
    echo "Installing the base system..."
    pacstrap /mnt base linux linux-firmware vim
}

# Function to generate fstab
generate_fstab() {
    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Function to set up the system in chroot
chroot_setup() {
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

    # Install bootloader
    echo "Installing bootloader (GRUB)..."
    pacman -S grub os-prober --noconfirm
    grub-install --target=i386-pc $disk
    grub-mkconfig -o /boot/grub/grub.cfg

    # Install the desktop environment
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

    # Finalize and exit chroot
    echo "Finalizing setup..."
    exit

EOF
}

# Function to reboot system
reboot_system() {
    echo "Installation complete. Rebooting your system..."
    umount -R /mnt
    reboot
}

# Main menu
while true; do
    clear
    echo "-----------------------------------------"
    echo "Arch Linux Setup Script"
    echo "-----------------------------------------"
    echo "1. Set basic information"
    echo "2. Set timezone and locale"
    echo "3. Select disk for installation"
    echo "4. Partition disk"
    echo "5. Install base system"
    echo "6. Generate fstab"
    echo "7. Set up the system in chroot"
    echo "8. Reboot"
    echo "9. Exit"
    echo "-----------------------------------------"
    prompt_user "Select an option" option
    
    case $option in
        1)
            set_basic_info
            ;;
        2)
            set_timezone
            set_locale
            ;;
        3)
            select_disk
            ;;
        4)
            partition_disk
            ;;
        5)
            install_base_system
            ;;
        6)
            generate_fstab
            ;;
        7)
            chroot_setup
            ;;
        8)
            reboot_system
            break
            ;;
        9)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select again."
            ;;
    esac

    read -p "Press Enter to return to the menu..."
done
