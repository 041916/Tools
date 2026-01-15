#!/usr/bin/env bash

# ============================================
# Arch Linux Automated Installation Script
# Author: Auto-generated
# Version: v5.0
# Features: WiFi + Desktop + GPU Drivers
# Mirror: Tsinghua University
# ============================================

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables
partition_type=""
boot_mode=""
install_disk=""
username=""
password=""
hostname=""
desktop_environment=""
gpu_driver=""
install_de_flag=false
install_gpu_flag=false
wifi_ssid=""
wifi_password=""
use_wifi=false

# Log functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
log_config() { echo -e "${CYAN}[CONFIG]${NC} $1"; }
log_network() { echo -e "${WHITE}[NETWORK]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Please run this script as root!"
        exit 1
    fi
}

# Check network connection
check_network() {
    log_info "Checking network connection..."
    
    # First check for wired connection
    if ip link show | grep -q "state UP" && ! ip link show | grep "wlp\|wlan" | grep -q "state UP"; then
        log_success "Wired network connection detected"
        return 0
    fi
    
    # Check for WiFi interface
    if ! ip link show | grep -q "wlp\|wlan"; then
        log_error "No network interface detected! Please connect Ethernet cable or ensure WiFi device is present"
        return 1
    fi
    
    # WiFi interface found but no active connection
    log_warning "No wired connection detected, will use WiFi"
    return 2
}

# Install WiFi tools
install_wifi_tools() {
    log_info "Installing WiFi connection tools..."
    
    # Check if iwd is already installed
    if ! command -v iwctl &> /dev/null; then
        pacman -Sy --noconfirm iwd
    fi
    
    # Start iwd service
    systemctl start iwd
    systemctl enable iwd
    
    log_success "WiFi tools installed"
}

# Scan available WiFi networks
scan_wifi_networks() {
    log_info "Scanning for WiFi networks..."
    
    # Get wireless interface name
    local wifi_device=$(ip link show | grep -E "wlp|wlan" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [[ -z "$wifi_device" ]]; then
        log_error "No wireless interface found!"
        return 1
    fi
    
    # Enable wireless interface
    ip link set "$wifi_device" up
    
    # Wait for interface to come up
    sleep 2
    
    # Scan for networks
    iwctl station "$wifi_device" scan
    sleep 3
    
    # Get network list
    local networks=$(iwctl station "$wifi_device" get-networks)
    
    if [[ -z "$networks" ]] || [[ "$networks" == *"No networks"* ]]; then
        log_error "No WiFi networks found!"
        return 1
    fi
    
    # Display network list
    echo ""
    echo "=========================================="
    echo "         Available WiFi Networks"
    echo "=========================================="
    echo "$networks"
    echo "=========================================="
    echo ""
    
    return 0
}

# Connect to WiFi network
connect_to_wifi() {
    log_info "Configuring WiFi connection..."
    
    # Get wireless interface name
    local wifi_device=$(ip link show | grep -E "wlp|wlan" | head -1 | cut -d: -f2 | tr -d ' ')
    
    if [[ -z "$wifi_device" ]]; then
        log_error "No wireless interface found!"
        return 1
    fi
    
    echo ""
    echo "=========================================="
    echo "           WiFi Connection Setup"
    echo "=========================================="
    
    # Enter WiFi SSID
    read -rp "Enter WiFi network name (SSID): " wifi_ssid
    
    if [[ -z "$wifi_ssid" ]]; then
        log_error "WiFi name cannot be empty!"
        return 1
    fi
    
    # Enter WiFi password
    read -rsp "Enter WiFi password (input hidden): " wifi_password
    echo ""
    
    # Connect using iwd
    log_info "Connecting to WiFi network: $wifi_ssid"
    
    if [[ -n "$wifi_password" ]]; then
        # Connect with password
        echo -e "$wifi_password" | iwctl station "$wifi_device" connect "$wifi_ssid" --passphrase
    else
        # Connect without password (open network)
        iwctl station "$wifi_device" connect "$wifi_ssid"
    fi
    
    # Wait for connection
    sleep 5
    
    # Check connection status
    if iwctl station "$wifi_device" show | grep -q "connected"; then
        log_success "Successfully connected to WiFi network: $wifi_ssid"
        
        # Get IP address
        if dhcpcd "$wifi_device" &> /dev/null; then
            local ip_addr=$(ip addr show "$wifi_device" | grep -oP 'inet \K[\d.]+')
            log_success "IP address obtained: $ip_addr"
        fi
        
        # Test internet connection
        if ping -c 3 archlinux.org &> /dev/null; then
            log_success "Internet connection test passed"
            return 0
        else
            log_warning "Connected to WiFi but cannot access internet"
            return 0  # Still return success, connection established
        fi
    else
        log_error "Failed to connect to WiFi network!"
        return 1
    fi
}

# Configure network (WiFi or wired)
configure_network() {
    log_step "Configuring network connection..."
    
    # Check network status
    if check_network; then
        log_success "Wired network connection working"
        use_wifi=false
        return 0
    fi
    
    local network_status=$?
    
    if [[ $network_status -eq 2 ]]; then
        # Need WiFi connection
        use_wifi=true
        
        # Install WiFi tools
        install_wifi_tools
        
        # Scan WiFi networks
        if ! scan_wifi_networks; then
            echo ""
            echo "Manually enter WiFi network?"
            echo "1) Yes"
            echo "2) No, rescan"
            echo "3) Exit installation"
            read -rp "Enter choice (1-3): " wifi_choice
            
            case $wifi_choice in
                1)
                    # Manually enter network info
                    ;;
                2)
                    scan_wifi_networks
                    ;;
                3)
                    log_error "Installation cancelled"
                    exit 1
                    ;;
                *)
                    log_error "Invalid choice!"
                    exit 1
                    ;;
            esac
        fi
        
        # Connect to WiFi
        if ! connect_to_wifi; then
            log_error "Network connection failed, cannot continue installation!"
            exit 1
        fi
    else
        log_error "Network connection failed!"
        exit 1
    fi
    
    log_success "Network configuration complete"
}

# WiFi configuration for chroot
setup_wifi_in_chroot() {
    if [[ "$use_wifi" == true ]] && [[ -n "$wifi_ssid" ]]; then
        log_info "Configuring system WiFi connection..."
        
        # Create WiFi config directory
        mkdir -p /mnt/etc/iwd/
        
        # Create WiFi config file
        cat > /mnt/etc/iwd/main.conf << EOF
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
EOF
        
        # Create network config file
        cat > /mnt/etc/iwd/$wifi_ssid.psk << EOF
[Security]
PreSharedKey=$wifi_password

[Settings]
AutoConnect=true
EOF
        
        # Set file permissions
        chmod 600 /mnt/etc/iwd/$wifi_ssid.psk
        
        log_success "WiFi configuration saved to new system"
    fi
}

# Sync system time
sync_time() {
    log_info "Synchronizing system time..."
    timedatectl set-ntp true
    sleep 2
    
    # Wait for NTP synchronization
    for i in {1..10}; do
        if timedatectl status | grep -q "synchronized: yes"; then
            log_success "System time synchronized (NTP)"
            return 0
        fi
        sleep 1
    done
    
    log_warning "NTP sync may take longer, continuing installation..."
    hwclock --hctosys
    log_success "Time synchronized using hardware clock"
}

# Show disk information
show_disks() {
    log_info "Available disks:"
    lsblk -f
    echo ""
}

# Detect GPU type
detect_gpu() {
    log_info "Detecting GPU type..."
    
    if lspci | grep -i "nvidia" &> /dev/null; then
        echo "nvidia"
    elif lspci | grep -i "amd" &> /dev/null; then
        echo "amd"
    elif lspci | grep -i "intel" &> /dev/null; then
        echo "intel"
    else
        echo "unknown"
    fi
}

# Check system boot mode
check_boot_mode() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        echo "uefi"
    else
        echo "bios"
    fi
}

# Set up Tsinghua University mirrors
setup_mirrors() {
    log_info "Setting up Tsinghua University mirrors..."
    
    # Backup original mirrorlist
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Create new mirrorlist
    cat > /etc/pacman.d/mirrorlist << EOF
# Tsinghua University Mirror
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch
EOF
    
    # Create mirrorlist for chrooted system
    mkdir -p /mnt/etc/pacman.d/
    cat > /mnt/etc/pacman.d/mirrorlist << EOF
# Tsinghua University Mirror
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch
EOF
    
    # Update pacman configuration
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    sed -i '/^ParallelDownloads/ s/=.*/=10/' /etc/pacman.conf
    
    # Add archlinuxcn repository
    cat >> /etc/pacman.conf << EOF

[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
EOF
    
    # Copy pacman config to target system
    cp /etc/pacman.conf /mnt/etc/pacman.conf
    
    log_success "Tsinghua University mirrors configured"
}

# Disk partitioning - GPT (UEFI)
partition_disk_gpt() {
    local disk=$1
    
    log_info "Using GPT partition table (UEFI mode)..."
    
    # Clear disk signatures
    sgdisk -Z "$disk"
    
    # Create GPT partition table
    sgdisk -o "$disk"
    
    # Create EFI partition (512MB)
    sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$disk"
    
    # Create swap partition (based on memory size)
    local mem_size=$(free -g | awk '/Mem:/ {print $2}')
    local swap_size=$((mem_size < 16 ? mem_size + 1 : 8))
    sgdisk -n 2:0:+${swap_size}G -t 2:8200 -c 2:"Linux swap" "$disk"
    
    # Create root partition (remaining space)
    sgdisk -n 3:0:0 -t 3:8304 -c 3:"Linux x86-64 root (/)" "$disk"
    
    # Refresh partition table
    partprobe "$disk"
    
    log_success "GPT partitioning complete"
    
    # Set partition variables
    BOOT_PART="${disk}1"
    SWAP_PART="${disk}2"
    ROOT_PART="${disk}3"
}

# Disk partitioning - MBR (BIOS)
partition_disk_mbr() {
    local disk=$1
    
    log_info "Using MBR partition table (BIOS mode)..."
    
    # Get memory size for swap partition
    local mem_size=$(free -g | awk '/Mem:/ {print $2}')
    local swap_size=$((mem_size < 16 ? mem_size + 1 : 8))
    
    # Clear partition table
    dd if=/dev/zero of="$disk" bs=512 count=1 conv=notrunc
    
    # Create MBR partition table using fdisk
    {
        echo o
        echo n
        echo p
        echo 1
        echo 
        echo +512M
        echo n
        echo p
        echo 2
        echo 
        echo +${swap_size}G
        echo t
        echo 2
        echo 82
        echo n
        echo p
        echo 3
        echo 
        echo 
        echo w
    } | fdisk "$disk"
    
    # Reread partition table
    partprobe "$disk"
    
    # Set partition variables
    if [[ "$disk" =~ "nvme" ]] || [[ "$disk" =~ "mmcblk" ]]; then
        BOOT_PART="${disk}p1"
        SWAP_PART="${disk}p2"
        ROOT_PART="${disk}p3"
    else
        BOOT_PART="${disk}1"
        SWAP_PART="${disk}2"
        ROOT_PART="${disk}3"
    fi
    
    log_success "MBR partitioning complete"
}

# Format partitions
format_partitions() {
    log_info "Formatting partitions..."
    
    # Format boot partition
    if [[ "$partition_type" == "gpt" ]]; then
        mkfs.fat -F32 "$BOOT_PART"
        log_success "EFI partition formatted"
    else
        mkfs.ext4 "$BOOT_PART"
        log_success "BIOS boot partition formatted"
    fi
    
    # Format swap partition
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
    log_success "Swap partition activated"
    
    # Format root partition
    mkfs.ext4 "$ROOT_PART"
    log_success "Root partition formatted"
}

# Mount partitions
mount_partitions() {
    log_info "Mounting partitions..."
    
    # Mount root partition
    mount "$ROOT_PART" /mnt
    
    # Create and mount boot directory
    if [[ "$partition_type" == "gpt" ]]; then
        mkdir -p /mnt/boot/efi
        mount "$BOOT_PART" /mnt/boot/efi
    else
        mkdir -p /mnt/boot
        mount "$BOOT_PART" /mnt/boot
    fi
    
    log_success "Partitions mounted"
}

# Install base system
install_base_system() {
    log_info "Installing base system..."
    
    # Set up Tsinghua mirrors
    setup_mirrors
    
    # Base package list
    local base_packages="base base-devel linux linux-firmware linux-headers"
    base_packages+=" networkmanager network-manager-applet"
    
    # Add tools based on network type
    if [[ "$use_wifi" == true ]]; then
        base_packages+=" iwd wpa_supplicant wireless_tools netctl"
        log_info "WiFi support packages added"
    fi
    
    base_packages+=" sudo nano vim git wget curl bash-completion"
    base_packages+=" htop neofetch man-db man-pages"
    base_packages+=" openssh rsync cronie"
    base_packages+=" ntfs-3g exfat-utils fuse fuse2"
    base_packages+=" xdg-user-dirs xdg-utils"
    base_packages+=" pulseaudio pulseaudio-alsa alsa-utils"
    base_packages+=" noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu"
    
    # Install bootloader based on partition type
    if [[ "$partition_type" == "gpt" ]]; then
        base_packages+=" grub efibootmgr dosfstools"
    else
        base_packages+=" grub"
    fi
    
    # Install microcode
    base_packages+=" amd-ucode intel-ucode"
    
    # Install base packages
    pacstrap /mnt $base_packages
    
    # Configure WiFi (if needed)
    setup_wifi_in_chroot
    
    log_success "Base system installation complete"
}

# Generate fstab
generate_fstab() {
    log_info "Generating fstab file..."
    genfstab -U /mnt >> /mnt/etc/fstab
    log_success "fstab generated"
}

# Install and configure GRUB bootloader
install_grub() {
    local disk=$1
    
    log_info "Installing GRUB bootloader..."
    
    if [[ "$partition_type" == "gpt" ]]; then
        # Install GRUB for UEFI
        arch-chroot /mnt grub-install --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --recheck
    else
        # Install GRUB for BIOS
        arch-chroot /mnt grub-install --target=i386-pc \
            --recheck "$disk"
    fi
    
    # Generate GRUB configuration
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    log_success "GRUB bootloader installed"
}

# Install desktop environment
install_desktop_environment() {
    log_info "Installing desktop environment: $desktop_environment"
    
    local de_packages="xorg xorg-server xorg-xinit xorg-xrandr xorg-xset"
    de_packages+=" mesa mesa-utils"
    de_packages+=" xdg-utils"
    
    case $desktop_environment in
        "kde")
            de_packages+=" plasma-meta kde-applications-meta"
            de_packages+=" sddm sddm-kcm"
            display_manager="sddm"
            ;;
        "gnome")
            de_packages+=" gnome gnome-extra gnome-tweaks"
            de_packages+=" gdm"
            display_manager="gdm"
            ;;
        "xfce")
            de_packages+=" xfce4 xfce4-goodies xfce4-terminal"
            de_packages+=" lightdm lightdm-gtk-greeter lightdm-settings"
            display_manager="lightdm"
            ;;
        "cinnamon")
            de_packages+=" cinnamon cinnamon-translations nemo-fileroller"
            de_packages+=" lightdm lightdm-gtk-greeter"
            display_manager="lightdm"
            ;;
        "mate")
            de_packages+=" mate mate-extra mate-media"
            de_packages+=" lightdm lightdm-gtk-greeter"
            display_manager="lightdm"
            ;;
        "lxqt")
            de_packages+=" lxqt breeze-icons oxygen-icons"
            de_packages+=" sddm"
            display_manager="sddm"
            ;;
        "deepin")
            de_packages+=" deepin deepin-extra"
            de_packages+=" lightdm"
            display_manager="lightdm"
            ;;
    esac
    
    # Install desktop environment packages
    arch-chroot /mnt pacman -S --noconfirm --needed $de_packages
    
    # Enable display manager
    arch-chroot /mnt systemctl enable $display_manager
    
    log_success "Desktop environment installed"
}

# Install GPU drivers
install_gpu_driver() {
    log_info "Installing GPU driver: $gpu_driver"
    
    local driver_packages=""
    
    case $gpu_driver in
        "nvidia")
            # NVIDIA proprietary driver
            driver_packages="nvidia nvidia-utils nvidia-settings nvidia-prime"
            # 32-bit library support (for Steam etc.)
            driver_packages+=" lib32-nvidia-utils"
            ;;
        "nvidia-open")
            # NVIDIA open-source driver
            driver_packages="nvidia-open nvidia-utils nvidia-settings"
            driver_packages+=" lib32-nvidia-utils"
            ;;
        "amd")
            # AMD open-source driver
            driver_packages="mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon"
            driver_packages+=" xf86-video-amdgpu"
            ;;
        "intel")
            # Intel driver
            driver_packages="mesa vulkan-intel lib32-mesa lib32-vulkan-intel"
            driver_packages+=" intel-media-driver libva-intel-driver"
            driver_packages+=" xf86-video-intel"
            ;;
        "vmware")
            # VMware driver
            driver_packages="xf86-video-vmware xf86-input-vmmouse"
            ;;
        "virtualbox")
            # VirtualBox driver
            driver_packages="virtualbox-guest-utils virtualbox-guest-modules-arch"
            ;;
    esac
    
    # Install driver packages
    if [[ -n "$driver_packages" ]]; then
        arch-chroot /mnt pacman -S --noconfirm --needed $driver_packages
        
        # For NVIDIA drivers, need to configure initramfs
        if [[ "$gpu_driver" == "nvidia" ]] || [[ "$gpu_driver" == "nvidia-open" ]]; then
            arch-chroot /mnt mkinitcpio -P
        fi
        
        # For VirtualBox, need to enable service
        if [[ "$gpu_driver" == "virtualbox" ]]; then
            arch-chroot /mnt systemctl enable vboxservice
        fi
    fi
    
    log_success "GPU driver installed"
}

# Install additional software
install_additional_software() {
    log_info "Installing additional software..."
    
    local software_packages=""
    
    # Browsers
    software_packages+=" firefox firefox-i18n-zh-cn chromium"
    
    # Office software
    software_packages+=" libreoffice-fresh libreoffice-fresh-zh-cn"
    software_packages+=" okular gimp inkscape"
    
    # Multimedia
    software_packages+=" vlc ffmpeg audacity"
    software_packages+=" gst-plugins-good gst-plugins-bad gst-plugins-ugly"
    
    # Development tools
    software_packages+=" code python python-pip nodejs npm"
    software_packages+=" docker docker-compose"
    
    # System tools
    software_packages+=" timeshift bleachbit"
    software_packages+=" gnome-disk-utility gparted"
    software_packages+=" fcitx5 fcitx5-configtool fcitx5-chinese-addons fcitx5-gtk fcitx5-qt"
    
    # Network tools
    software_packages+=" transmission-qt qbittorrent"
    software_packages+=" telegram-desktop"
    
    # Games
    software_packages+=" steam"
    
    # Install software packages
    arch-chroot /mnt pacman -S --noconfirm --needed $software_packages
    
    # Enable Docker service
    arch-chroot /mnt systemctl enable docker
    
    # Add user to docker group
    arch-chroot /mnt usermod -aG docker "$username"
    
    log_success "Additional software installed"
}

# Configure Network Manager (WiFi support)
configure_network_manager() {
    log_info "Configuring Network Manager..."
    
    # Ensure NetworkManager config directory exists
    mkdir -p /mnt/etc/NetworkManager/conf.d/
    
    # Create NetworkManager configuration
    cat > /mnt/etc/NetworkManager/conf.d/wifi.conf << EOF
[device]
wifi.backend=iwd
EOF
    
    # If using WiFi, configure auto-connection
    if [[ "$use_wifi" == true ]] && [[ -n "$wifi_ssid" ]]; then
        # Create NetworkManager connection configuration
        mkdir -p /mnt/etc/NetworkManager/system-connections/
        
        cat > "/mnt/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection" << EOF
[connection]
id=$wifi_ssid
uuid=$(uuidgen)
type=wifi
interface-name=*

[wifi]
mode=infrastructure
ssid=$wifi_ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$wifi_password

[ipv4]
method=auto

[ipv6]
addr-gen-mode=stable-privacy
method=auto

[proxy]
EOF
        
        # Set correct permissions
        chmod 600 "/mnt/etc/NetworkManager/system-connections/$wifi_ssid.nmconnection"
        
        log_success "WiFi network configuration saved"
    fi
    
    log_success "Network Manager configured"
}

# User configuration
configure_user() {
    local username=$1
    local desktop=$2
    
    log_info "Configuring user environment..."
    
    # Create user directories
    arch-chroot /mnt sudo -u $username xdg-user-dirs-update
    
    # Create desktop environment startup script
    if [[ "$desktop" != "none" ]]; then
        cat > /mnt/home/$username/.xinitrc << EOF
#!/bin/bash

# Start desktop environment based on selection
case "$desktop" in
    kde)
        exec startplasma-x11
        ;;
    gnome)
        exec gnome-session
        ;;
    xfce)
        exec startxfce4
        ;;
    cinnamon)
        exec cinnamon-session
        ;;
    mate)
        exec mate-session
        ;;
    lxqt)
        exec startlxqt
        ;;
    deepin)
        exec startdde
        ;;
    *)
        # Default to startx
        exec $desktop
        ;;
esac
EOF
        
        arch-chroot /mnt chown $username:$username /home/$username/.xinitrc
        arch-chroot /mnt chmod +x /home/$username/.xinitrc
    fi
    
    # Configure Chinese input method
    cat > /mnt/home/$username/.pam_environment << EOF
GTK_IM_MODULE DEFAULT=fcitx
QT_IM_MODULE  DEFAULT=fcitx
XMODIFIERS    DEFAULT=@im=fcitx
SDL_IM_MODULE DEFAULT=fcitx
EOF
    
    arch-chroot /mnt chown $username:$username /home/$username/.pam_environment
    
    log_success "User environment configured"
}

# Main chroot configuration
chroot_configuration() {
    local hostname=$1
    local username=$2
    local password=$3
    
    log_step "Starting chroot configuration..."
    
    # Create chroot script
    cat > /mnt/chroot_main.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc

# Localization settings
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "$hostname" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS

# Set root password
echo "root:$password" | chpasswd

# Create new user
useradd -m -G wheel,storage,power,audio,video,network -s /bin/bash "$username"
echo "$username:$password" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
sed -i 's/^# %wheel/%wheel/' /etc/sudoers

# Enable NetworkManager and iwd
systemctl enable NetworkManager
systemctl enable iwd
systemctl enable sshd
systemctl enable cronie

# Install archlinuxcn keyring
pacman -Sy --noconfirm archlinuxcn-keyring

# Clean cache
pacman -Scc --noconfirm

# Create completion flag
touch /etc/arch-install-complete

exit 0
EOF
    
    # Replace variables in the script
    sed -i "s/\$hostname/$hostname/g" /mnt/chroot_main.sh
    sed -i "s/\$username/$username/g" /mnt/chroot_main.sh
    sed -i "s/\$password/$password/g" /mnt/chroot_main.sh
    
    # Execute chroot main script
    chmod +x /mnt/chroot_main.sh
    arch-chroot /mnt /chroot_main.sh
    rm /mnt/chroot_main.sh
    
    # Configure Network Manager
    configure_network_manager
    
    # Install desktop environment
    if [[ "$install_de_flag" == true ]] && [[ "$desktop_environment" != "none" ]]; then
        install_desktop_environment
    fi
    
    # Install GPU driver
    if [[ "$install_gpu_flag" == true ]] && [[ "$gpu_driver" != "none" ]]; then
        install_gpu_driver
    fi
    
    # Install additional software
    if [[ "$install_de_flag" == true ]]; then
        install_additional_software
        configure_user "$username" "$desktop_environment"
    fi
    
    log_success "Chroot configuration complete"
}

# Post-install cleanup
post_install_cleanup() {
    log_info "Performing post-install cleanup..."
    
    # Unmount partitions
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    
    log_success "Cleanup complete"
}

# Show completion message
show_completion_message() {
    local hostname=$1
    
    echo ""
    echo "=========================================="
    echo "      Arch Linux Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Installation Summary:"
    echo "Partition type: $partition_type"
    echo "Boot mode: $boot_mode"
    echo "Hostname: $hostname"
    echo "Username: $username"
    echo "Network: $( [[ "$use_wifi" == true ]] && echo "WiFi ($wifi_ssid)" || echo "Wired" )"
    echo "Mirror: Tsinghua University"
    
    if [[ "$install_de_flag" == true ]]; then
        echo "Desktop environment: $desktop_environment"
    else
        echo "Desktop environment: None (CLI only)"
    fi
    
    if [[ "$install_gpu_flag" == true ]]; then
        echo "GPU driver: $gpu_driver"
    fi
    
    echo ""
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Reboot your computer:"
    echo "   umount -R /mnt  # If not already unmounted"
    echo "   reboot"
    echo ""
    echo "2. After first boot:"
    
    if [[ "$use_wifi" == true ]]; then
        echo "   - WiFi network '$wifi_ssid' is configured"
        echo "   - System will auto-connect to WiFi"
    fi
    
    if [[ "$install_de_flag" == true ]]; then
        echo "   - System will boot to desktop environment"
        echo "   - Login with username '$username'"
        echo "   - Recommended to update: sudo pacman -Syu"
    else
        echo "   - Login with username '$username'"
        echo "   - Install desktop environment (optional):"
        echo "     sudo pacman -S xorg plasma kde-applications"
        echo "     sudo systemctl enable sddm"
        echo "     reboot"
    fi
    
    echo ""
    echo "3. Further optimization:"
    echo "   - Install AUR helper: yay or paru"
    echo "   - Configure system backup: timeshift"
    echo "   - Adjust desktop settings"
    echo ""
    
    if [[ "$use_wifi" == true ]]; then
        echo "4. WiFi network information:"
        echo "   SSID: $wifi_ssid"
        echo "   Password: [saved]"
        echo ""
    fi
    
    log_success "Installation script completed!"
}

# Main function
main() {
    clear
    
    echo "=========================================="
    echo "    Arch Linux Automated Installer v5.0"
    echo "=========================================="
    echo "  Support: GPT/UEFI or MBR/BIOS"
    echo "  Features: WiFi + Desktop + GPU Drivers"
    echo "  Mirror: Tsinghua University"
    echo "=========================================="
    echo ""
    
    # Check environment
    check_root
    
    # Configure network connection (wired or WiFi)
    configure_network
    
    # Sync system time
    sync_time
    
    # Detect boot mode and GPU
    boot_mode=$(check_boot_mode)
    detected_gpu=$(detect_gpu)
    
    log_config "Detected boot mode: $boot_mode"
    log_config "Detected GPU type: $detected_gpu"
    
    # Show disk information
    show_disks
    
    # User input - disk selection
    read -rp "Enter disk to install to (e.g., /dev/sda): " install_disk
    
    if [[ ! -b "$install_disk" ]]; then
        log_error "Disk $install_disk does not exist!"
        exit 1
    fi
    
    # User input - partition type
    echo ""
    echo "Select partition table type:"
    echo "1) GPT (UEFI boot, recommended for modern computers)"
    echo "2) MBR (BIOS boot, compatibility for older computers)"
    read -rp "Enter choice (1-2): " partition_choice
    
    case $partition_choice in
        1)
            partition_type="gpt"
            log_config "Selected GPT partition table (UEFI)"
            ;;
        2)
            partition_type="mbr"
            log_config "Selected MBR partition table (BIOS)"
            ;;
        *)
            log_error "Invalid choice!"
            exit 1
            ;;
    esac
    
    # Check partition type compatibility with boot mode
    if [[ "$boot_mode" == "uefi" && "$partition_type" == "mbr" ]]; then
        log_warning "Warning: UEFI boot mode recommends GPT partition table!"
        read -rp "Continue anyway? (y/N): " continue_install
        if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # User input - system configuration
    echo ""
    read -rp "Enter hostname: " hostname
    read -rp "Enter username: " username
    read -rsp "Enter password: " password
    echo ""
    read -rsp "Confirm password: " password_confirm
    echo ""
    
    if [[ "$password" != "$password_confirm" ]]; then
        log_error "Passwords do not match!"
        exit 1
    fi
    
    # User input - desktop environment selection
    echo ""
    echo "Install desktop environment?"
    echo "1) Yes (recommended for desktop use)"
    echo "2) No (CLI only, for servers)"
    read -rp "Enter choice (1-2): " de_choice
    
    if [[ "$de_choice" == "1" ]]; then
        install_de_flag=true
        echo ""
        echo "Select desktop environment:"
        echo "1) KDE Plasma (recommended, feature complete)"
        echo "2) GNOME (modern, clean)"
        echo "3) XFCE (lightweight, fast)"
        echo "4) Cinnamon (traditional, user-friendly)"
        echo "5) MATE (classic, stable)"
        echo "6) LXQt (ultra lightweight)"
        echo "7) Deepin (beautiful, China-focused)"
        echo "8) Skip (no desktop)"
        read -rp "Enter choice (1-8): " de_type
        
        case $de_type in
            1) desktop_environment="kde" ;;
            2) desktop_environment="gnome" ;;
            3) desktop_environment="xfce" ;;
            4) desktop_environment="cinnamon" ;;
            5) desktop_environment="mate" ;;
            6) desktop_environment="lxqt" ;;
            7) desktop_environment="deepin" ;;
            8) 
                desktop_environment="none"
                install_de_flag=false
                ;;
            *)
                log_error "Invalid choice!"
                exit 1
                ;;
        esac
    else
        desktop_environment="none"
        install_de_flag=false
    fi
    
    # User input - GPU driver selection
    echo ""
    echo "Install GPU drivers?"
    echo "1) Auto-install (based on detected hardware)"
    echo "2) Manual selection"
    echo "3) Skip (install manually later)"
    read -rp "Enter choice (1-3): " gpu_choice
    
    if [[ "$gpu_choice" == "1" ]]; then
        install_gpu_flag=true
        case $detected_gpu in
            nvidia) gpu_driver="nvidia" ;;
            amd) gpu_driver="amd" ;;
            intel) gpu_driver="intel" ;;
            *) 
                log_warning "Cannot auto-detect GPU type, please select manually"
                gpu_choice="2"
                ;;
        esac
    fi
    
    if [[ "$gpu_choice" == "2" ]]; then
        install_gpu_flag=true
        echo ""
        echo "Select GPU driver:"
        echo "1) NVIDIA (proprietary driver)"
        echo "2) NVIDIA (open-source driver)"
        echo "3) AMD (open-source driver)"
        echo "4) Intel (integrated graphics)"
        echo "5) VMware (virtual machine)"
        echo "6) VirtualBox (virtual machine)"
        echo "7) Skip"
        read -rp "Enter choice (1-7): " driver_type
        
        case $driver_type in
            1) gpu_driver="nvidia" ;;
            2) gpu_driver="nvidia-open" ;;
            3) gpu_driver="amd" ;;
            4) gpu_driver="intel" ;;
            5) gpu_driver="vmware" ;;
            6) gpu_driver="virtualbox" ;;
            7) 
                gpu_driver="none"
                install_gpu_flag=false
                ;;
            *)
                log_error "Invalid choice!"
                exit 1
                ;;
        esac
    fi
    
    if [[ "$gpu_choice" == "3" ]]; then
        gpu_driver="none"
        install_gpu_flag=false
    fi
    
    # Confirm installation
    echo ""
    echo "=========================================="
    echo "Installation Summary:"
    echo "=========================================="
    echo "Disk: $install_disk"
    echo "Partition type: $partition_type"
    echo "Boot mode: $boot_mode"
    echo "Hostname: $hostname"
    echo "Username: $username"
    echo "Network: $( [[ "$use_wifi" == true ]] && echo "WiFi ($wifi_ssid)" || echo "Wired" )"
    echo "Mirror: Tsinghua University"
    echo "Desktop environment: $desktop_environment"
    echo "GPU driver: $gpu_driver"
    echo "=========================================="
    echo ""
    
    read -rp "Confirm and start installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warning "Installation cancelled"
        exit 0
    fi
    
    # Start installation process
    log_step "Starting Arch Linux installation..."
    
    # Execute installation steps
    if [[ "$partition_type" == "gpt" ]]; then
        partition_disk_gpt "$install_disk"
    else
        partition_disk_mbr "$install_disk"
    fi
    
    format_partitions
    mount_partitions
    install_base_system
    generate_fstab
    install_grub "$install_disk"
    chroot_configuration "$hostname" "$username" "$password"
    post_install_cleanup
    
    # Show completion message
    show_completion_message "$hostname"
}

# Execute main function
main "$@"