#!/usr/bin/env bash

# ============================================
# Arch Linux Automated Installation Script
# Author: Auto-generated
# Version: v5.2 with Logging
# Features: WiFi + Desktop + GPU Drivers + Logging
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

# Logging variables
LOG_FILE="/tmp/arch-install-$(date +%Y%m%d-%H%M%S).log"
DEBUG_LOG="/tmp/arch-install-debug-$(date +%Y%m%d-%H%M%S).log"
SCRIPT_START_TIME=$(date +%s)

# Initialize logging
init_logging() {
    # Create log files
    touch "$LOG_FILE"
    touch "$DEBUG_LOG"
    
    # Log script start
    {
        echo "=========================================="
        echo "Arch Linux Installation Log"
        echo "Start Time: $(date)"
        echo "Script Version: v5.2"
        echo "Log File: $LOG_FILE"
        echo "Debug Log: $DEBUG_LOG"
        echo "=========================================="
        echo ""
    } | tee -a "$LOG_FILE" "$DEBUG_LOG"
}

# Log functions with file logging
log_info() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[INFO]${NC} $message"
    echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
    echo "[$timestamp] [INFO] $message" >> "$DEBUG_LOG"
}

log_success() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
    echo "[$timestamp] [SUCCESS] $message" >> "$DEBUG_LOG"
}

log_warning() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING]${NC} $message"
    echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
    echo "[$timestamp] [WARNING] $message" >> "$DEBUG_LOG"
}

log_error() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} $message"
    echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
    echo "[$timestamp] [ERROR] $message" >> "$DEBUG_LOG"
    
    # Log error to separate error file
    echo "[$timestamp] [ERROR] $message" >> "/tmp/arch-install-errors.log"
}

log_step() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${PURPLE}[STEP]${NC} $message"
    echo "[$timestamp] [STEP] $message" >> "$LOG_FILE"
    echo "[$timestamp] [STEP] $message" >> "$DEBUG_LOG"
}

log_config() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[CONFIG]${NC} $message"
    echo "[$timestamp] [CONFIG] $message" >> "$LOG_FILE"
    echo "[$timestamp] [CONFIG] $message" >> "$DEBUG_LOG"
}

log_network() { 
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${WHITE}[NETWORK]${NC} $message"
    echo "[$timestamp] [NETWORK] $message" >> "$LOG_FILE"
    echo "[$timestamp] [NETWORK] $message" >> "$DEBUG_LOG"
}

# Debug logging (verbose)
log_debug() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [DEBUG] $message" >> "$DEBUG_LOG"
}

# Log command execution
log_command() {
    local cmd="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [COMMAND] $cmd" >> "$DEBUG_LOG"
    
    # Execute command and capture output
    local output
    local exit_code
    
    log_debug "Executing: $cmd"
    
    if output=$(eval "$cmd" 2>&1); then
        exit_code=0
        log_debug "Command succeeded with exit code: $exit_code"
    else
        exit_code=$?
        log_debug "Command failed with exit code: $exit_code"
    fi
    
    # Log output if not empty
    if [[ -n "$output" ]]; then
        echo "[$timestamp] [OUTPUT] $output" >> "$DEBUG_LOG"
    fi
    
    echo "[$timestamp] [EXIT_CODE] $exit_code" >> "$DEBUG_LOG"
    
    return $exit_code
}

# Log system information
log_system_info() {
    log_step "Collecting system information..."
    
    {
        echo "=== System Information ==="
        echo "Date: $(date)"
        echo "Uptime: $(uptime)"
        echo ""
        echo "=== CPU Information ==="
        lscpu | grep -E "Model name|CPU\(s\)|Thread|Core" | head -10
        echo ""
        echo "=== Memory Information ==="
        free -h
        echo ""
        echo "=== Disk Information ==="
        lsblk -f
        echo ""
        echo "=== Network Interfaces ==="
        ip addr show | grep -E "^[0-9]+:|inet " | head -20
        echo ""
        echo "=== Boot Mode ==="
        if [[ -d /sys/firmware/efi/efivars ]]; then
            echo "UEFI"
        else
            echo "BIOS"
        fi
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "System information logged"
}

# Log installation summary
log_installation_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    
    {
        echo ""
        echo "=========================================="
        echo "          INSTALLATION SUMMARY"
        echo "=========================================="
        echo "Installation Time: $(date)"
        echo "Duration: $duration seconds"
        echo "Hostname: $hostname"
        echo "Username: $username"
        echo "Install Disk: $install_disk"
        echo "Partition Type: $partition_type"
        echo "Boot Mode: $boot_mode"
        echo "Network Type: $( [[ "$use_wifi" == true ]] && echo "WiFi ($wifi_ssid)" || echo "Wired" )"
        echo "Desktop Environment: $desktop_environment"
        echo "GPU Driver: $gpu_driver"
        echo "Log File: $LOG_FILE"
        echo "Debug Log: $DEBUG_LOG"
        echo "=========================================="
        echo ""
        echo "=== Critical Files Created ==="
        find /mnt/etc -name "*.conf" -o -name "fstab" -o -name "hostname" -o -name "hosts" 2>/dev/null | head -10
        echo ""
        echo "=== Installed Services ==="
        ls /mnt/etc/systemd/system/multi-user.target.wants/ 2>/dev/null || echo "No services found"
        echo ""
    } | tee -a "$LOG_FILE" >> "$DEBUG_LOG"
}

# Save logs to installed system
save_logs_to_system() {
    log_info "Saving installation logs to new system..."
    
    # Create log directory in new system
    arch-chroot /mnt mkdir -p /var/log/arch-install
    
    # Copy logs
    cp "$LOG_FILE" /mnt/var/log/arch-install/install.log
    cp "$DEBUG_LOG" /mnt/var/log/arch-install/debug.log
    
    # Create installation info file
    cat > /mnt/var/log/arch-install/install-info.txt << EOF
Arch Linux Installation Report
==============================
Installation Date: $(date)
Installation Script: v5.2 with Logging
Hostname: $hostname
Username: $username
Install Disk: $install_disk
Partition Type: $partition_type
Desktop Environment: $desktop_environment
GPU Driver: $gpu_driver
Network: $( [[ "$use_wifi" == true ]] && echo "WiFi ($wifi_ssid)" || echo "Wired" )

Installation Steps Completed:
1. Disk partitioning ✓
2. Filesystem creation ✓
3. Base system installation ✓
4. Fstab generation ✓
5. GRUB installation ✓
6. System configuration ✓
7. Software installation ✓

Log Files:
- /var/log/arch-install/install.log
- /var/log/arch-install/debug.log

For troubleshooting, check:
1. /var/log/pacman.log - Package installation log
2. /var/log/Xorg.0.log - X11 log (if desktop installed)
3. journalctl -xe - System logs
EOF
    
    log_success "Logs saved to /var/log/arch-install/"
}

# Check if running as root
check_root() {
    log_info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "Please run this script as root!"
        exit 1
    fi
    log_success "Root privileges confirmed"
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
        log_command "pacman -Sy --noconfirm iwd"
    fi
    
    # Start iwd service
    log_command "systemctl start iwd"
    log_command "systemctl enable iwd"
    
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
    log_command "ip link set $wifi_device up"
    
    # Wait for interface to come up
    sleep 2
    
    # Scan for networks
    log_command "iwctl station $wifi_device scan"
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
    
    # Log networks
    echo "[WiFi Networks]" >> "$DEBUG_LOG"
    echo "$networks" >> "$DEBUG_LOG"
    
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
    
    # Log connection attempt (without password)
    echo "[WiFi Connection Attempt]" >> "$DEBUG_LOG"
    echo "SSID: $wifi_ssid" >> "$DEBUG_LOG"
    echo "Interface: $wifi_device" >> "$DEBUG_LOG"
    
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
            echo "IP Address: $ip_addr" >> "$DEBUG_LOG"
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
    log_command "timedatectl set-ntp true"
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
    log_command "hwclock --hctosys"
    log_success "Time synchronized using hardware clock"
}

# Show disk information
show_disks() {
    log_info "Available disks:"
    log_command "lsblk -f"
    echo ""
}

# Detect GPU type
detect_gpu() {
    log_info "Detecting GPU type..."
    
    local gpu_type="unknown"
    
    if lspci | grep -i "nvidia" &> /dev/null; then
        gpu_type="nvidia"
    elif lspci | grep -i "amd" &> /dev/null; then
        gpu_type="amd"
    elif lspci | grep -i "intel" &> /dev/null; then
        gpu_type="intel"
    fi
    
    log_info "Detected GPU: $gpu_type"
    echo "$gpu_type"
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
    log_command "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup"
    
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
    
    # Add archlinuxcn repository (commented out for stability)
    cat >> /etc/pacman.conf << EOF

# [archlinuxcn]
# Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/\$arch
EOF
    
    # Copy pacman config to target system
    cp /etc/pacman.conf /mnt/etc/pacman.conf
    
    log_success "Tsinghua University mirrors configured"
}

# Disk partitioning - GPT (UEFI)
partition_disk_gpt() {
    local disk=$1
    
    log_info "Using GPT partition table (UEFI mode)..."
    
    # Log partition information before
    {
        echo "=== Disk Information Before Partitioning ==="
        fdisk -l "$disk"
        echo ""
    } >> "$DEBUG_LOG"
    
    # Clear disk signatures
    log_command "sgdisk -Z $disk"
    
    # Create GPT partition table
    log_command "sgdisk -o $disk"
    
    # Create EFI partition (512MB)
    log_command "sgdisk -n 1:0:+512M -t 1:ef00 -c 1:\"EFI System\" $disk"
    
    # Create swap partition (based on memory size)
    local mem_size=$(free -g | awk '/Mem:/ {print $2}')
    local swap_size=$((mem_size < 16 ? mem_size + 1 : 8))
    log_command "sgdisk -n 2:0:+${swap_size}G -t 2:8200 -c 2:\"Linux swap\" $disk"
    
    # Create root partition (remaining space)
    log_command "sgdisk -n 3:0:0 -t 3:8304 -c 3:\"Linux x86-64 root (/)\" $disk"
    
    # Refresh partition table
    log_command "partprobe $disk"
    
    # Log partition information after
    {
        echo "=== Disk Information After Partitioning ==="
        fdisk -l "$disk"
        echo ""
        echo "=== Partition Details ==="
        sgdisk -p "$disk"
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "GPT partitioning complete"
    
    # Set partition variables
    BOOT_PART="${disk}1"
    SWAP_PART="${disk}2"
    ROOT_PART="${disk}3"
    
    # Log partition assignments
    log_info "Partition assignments:"
    log_info "  Boot: $BOOT_PART"
    log_info "  Swap: $SWAP_PART"
    log_info "  Root: $ROOT_PART"
}

# Disk partitioning - MBR (BIOS)
partition_disk_mbr() {
    local disk=$1
    
    log_info "Using MBR partition table (BIOS mode)..."
    
    # Get memory size for swap partition
    local mem_size=$(free -g | awk '/Mem:/ {print $2}')
    local swap_size=$((mem_size < 16 ? mem_size + 1 : 8))
    
    # Log partition information before
    {
        echo "=== Disk Information Before Partitioning ==="
        fdisk -l "$disk"
        echo ""
    } >> "$DEBUG_LOG"
    
    # Clear partition table
    log_command "dd if=/dev/zero of=$disk bs=512 count=1 conv=notrunc"
    
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
    log_command "partprobe $disk"
    
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
    
    # Log partition information after
    {
        echo "=== Disk Information After Partitioning ==="
        fdisk -l "$disk"
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "MBR partitioning complete"
    
    # Log partition assignments
    log_info "Partition assignments:"
    log_info "  Boot: $BOOT_PART"
    log_info "  Swap: $SWAP_PART"
    log_info "  Root: $ROOT_PART"
}

# Format partitions
format_partitions() {
    log_info "Formatting partitions..."
    
    # Format boot partition
    if [[ "$partition_type" == "gpt" ]]; then
        log_command "mkfs.fat -F32 $BOOT_PART"
        log_success "EFI partition formatted"
    else
        log_command "mkfs.ext4 $BOOT_PART"
        log_success "BIOS boot partition formatted"
    fi
    
    # Format swap partition
    log_command "mkswap $SWAP_PART"
    log_command "swapon $SWAP_PART"
    log_success "Swap partition activated"
    
    # Format root partition
    log_command "mkfs.ext4 $ROOT_PART"
    log_success "Root partition formatted"
}

# Mount partitions
mount_partitions() {
    log_info "Mounting partitions..."
    
    # Mount root partition
    log_command "mount $ROOT_PART /mnt"
    
    # Create and mount boot directory
    if [[ "$partition_type" == "gpt" ]]; then
        log_command "mkdir -p /mnt/boot/efi"
        log_command "mount $BOOT_PART /mnt/boot/efi"
    else
        log_command "mkdir -p /mnt/boot"
        log_command "mount $BOOT_PART /mnt/boot"
    fi
    
    # Log mount information
    {
        echo "=== Mount Information ==="
        mount | grep "/mnt"
        echo ""
        echo "=== Disk Usage ==="
        df -h | grep -E "/mnt|Filesystem"
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "Partitions mounted"
}

# Install base system
install_base_system() {
    log_info "Installing base system..."
    
    # Set up Tsinghua mirrors
    setup_mirrors
    
    # Base package list - ONLY ESSENTIAL PACKAGES
    local base_packages="base base-devel linux linux-firmware"
    base_packages+=" networkmanager"
    
    # Add tools based on network type
    if [[ "$use_wifi" == true ]]; then
        base_packages+=" iwd"
    fi
    
    # Essential utilities only
    base_packages+=" sudo nano vim git wget curl"
    base_packages+=" man-db man-pages"
    base_packages+=" openssh"
    base_packages+=" xdg-user-dirs xdg-utils"
    base_packages+=" noto-fonts"
    
    # Install bootloader based on partition type
    if [[ "$partition_type" == "gpt" ]]; then
        base_packages+=" grub efibootmgr dosfstools"
    else
        base_packages+=" grub"
    fi
    
    # Install microcode
    base_packages+=" amd-ucode intel-ucode"
    
    log_info "Installing packages: $base_packages"
    
    # Log package installation
    {
        echo "=== Package Installation Details ==="
        echo "Packages to install: $base_packages"
        echo "Date: $(date)"
        echo ""
    } >> "$DEBUG_LOG"
    
    # Install base packages
    log_command "pacstrap /mnt $base_packages"
    
    # Log installed packages
    {
        echo "=== Installed Packages ==="
        arch-chroot /mnt pacman -Q
        echo ""
    } >> "$DEBUG_LOG"
    
    # Configure WiFi (if needed)
    setup_wifi_in_chroot
    
    log_success "Base system installation complete"
}

# Generate fstab
generate_fstab() {
    log_info "Generating fstab file..."
    
    # Log original fstab (if exists)
    {
        echo "=== Original fstab ==="
        cat /mnt/etc/fstab 2>/dev/null || echo "No fstab found"
        echo ""
    } >> "$DEBUG_LOG"
    
    # Generate fstab
    log_command "genfstab -U /mnt >> /mnt/etc/fstab"
    
    # Log generated fstab
    {
        echo "=== Generated fstab ==="
        cat /mnt/etc/fstab
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "fstab generated"
}

# Install and configure GRUB bootloader
install_grub() {
    local disk=$1
    
    log_info "Installing GRUB bootloader..."
    
    if [[ "$partition_type" == "gpt" ]]; then
        # Install GRUB for UEFI
        log_command "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck"
    else
        # Install GRUB for BIOS
        log_command "arch-chroot /mnt grub-install --target=i386-pc --recheck $disk"
    fi
    
    # Generate GRUB configuration
    log_command "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg"
    
    # Log GRUB configuration
    {
        echo "=== GRUB Configuration ==="
        cat /mnt/boot/grub/grub.cfg 2>/dev/null | head -50
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "GRUB bootloader installed"
}

# Install desktop environment (moved to chroot)
install_desktop_environment() {
    log_info "Installing desktop environment: $desktop_environment"
    
    local de_packages="xorg xorg-server xorg-xinit"
    de_packages+=" mesa"
    
    case $desktop_environment in
        "kde")
            de_packages+=" plasma"
            de_packages+=" sddm"
            display_manager="sddm"
            ;;
        "gnome")
            de_packages+=" gnome"
            de_packages+=" gdm"
            display_manager="gdm"
            ;;
        "xfce")
            de_packages+=" xfce4 xfce4-goodies"
            de_packages+=" lightdm lightdm-gtk-greeter"
            display_manager="lightdm"
            ;;
        "cinnamon")
            de_packages+=" cinnamon"
            de_packages+=" lightdm lightdm-gtk-greeter"
            display_manager="lightdm"
            ;;
        "mate")
            de_packages+=" mate"
            de_packages+=" lightdm lightdm-gtk-greeter"
            display_manager="lightdm"
            ;;
        "lxqt")
            de_packages+=" lxqt"
            de_packages+=" sddm"
            display_manager="sddm"
            ;;
        "deepin")
            de_packages+=" deepin"
            de_packages+=" lightdm"
            display_manager="lightdm"
            ;;
    esac
    
    log_info "Installing desktop packages: $de_packages"
    
    # Install desktop environment packages
    log_command "arch-chroot /mnt pacman -S --noconfirm --needed $de_packages"
    
    # Enable display manager
    log_command "arch-chroot /mnt systemctl enable $display_manager"
    
    log_success "Desktop environment installed"
}

# Install GPU drivers (moved to chroot)
install_gpu_driver() {
    log_info "Installing GPU driver: $gpu_driver"
    
    local driver_packages=""
    
    case $gpu_driver in
        "nvidia")
            # NVIDIA proprietary driver
            driver_packages="nvidia nvidia-utils"
            ;;
        "nvidia-open")
            # NVIDIA open-source driver
            driver_packages="nvidia-open nvidia-utils"
            ;;
        "amd")
            # AMD open-source driver
            driver_packages="mesa vulkan-radeon"
            driver_packages+=" xf86-video-amdgpu"
            ;;
        "intel")
            # Intel driver
            driver_packages="mesa vulkan-intel"
            driver_packages+=" intel-media-driver"
            driver_packages+=" xf86-video-intel"
            ;;
        "vmware")
            # VMware driver
            driver_packages="xf86-video-vmware xf86-input-vmmouse"
            ;;
        "virtualbox")
            # VirtualBox driver
            driver_packages="virtualbox-guest-utils"
            ;;
    esac
    
    log_info "Installing GPU driver packages: $driver_packages"
    
    # Install driver packages
    if [[ -n "$driver_packages" ]]; then
        log_command "arch-chroot /mnt pacman -S --noconfirm --needed $driver_packages"
        
        # For NVIDIA drivers, need to configure initramfs
        if [[ "$gpu_driver" == "nvidia" ]] || [[ "$gpu_driver" == "nvidia-open" ]]; then
            log_command "arch-chroot /mnt mkinitcpio -P"
        fi
        
        # For VirtualBox, need to enable service
        if [[ "$gpu_driver" == "virtualbox" ]]; then
            log_command "arch-chroot /mnt systemctl enable vboxservice"
        fi
    fi
    
    log_success "GPU driver installed"
}

# Install additional software (moved to chroot)
install_additional_software() {
    log_info "Installing additional software..."
    
    local software_packages=""
    
    # Browsers
    software_packages+=" firefox chromium"
    
    # Office software
    software_packages+=" libreoffice-fresh"
    
    # Multimedia
    software_packages+=" vlc"
    
    # Development tools
    software_packages+=" python nodejs"
    software_packages+=" docker docker-compose"
    
    # System tools
    software_packages+=" htop neofetch"
    
    log_info "Installing software packages: $software_packages"
    
    # Install software packages
    if log_command "arch-chroot /mnt pacman -S --noconfirm --needed $software_packages"; then
        log_success "Additional software installed"
        
        # Enable Docker service
        log_command "arch-chroot /mnt systemctl enable docker"
        
        # Add user to docker group
        log_command "arch-chroot /mnt usermod -aG docker $username"
    else
        log_warning "Some packages failed to install, continuing..."
        # Try installing packages one by one
        for pkg in $software_packages; do
            log_info "Trying to install: $pkg"
            log_command "arch-chroot /mnt pacman -S --noconfirm --needed $pkg" || \
                log_warning "Failed to install: $pkg"
        done
    fi
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
    log_command "arch-chroot /mnt sudo -u $username xdg-user-dirs-update"
    
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
        
        log_command "arch-chroot /mnt chown $username:$username /home/$username/.xinitrc"
        log_command "arch-chroot /mnt chmod +x /home/$username/.xinitrc"
    fi
    
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

# Log chroot start
echo "[CHROOT] Starting configuration at $(date)" >> /var/log/arch-install/chroot.log

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
hwclock --systohc
echo "[CHROOT] Timezone configured" >> /var/log/arch-install/chroot.log

# Localization settings
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "[CHROOT] Locale configured" >> /var/log/arch-install/chroot.log

# Network configuration
echo "$hostname" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS
echo "[CHROOT] Network configured" >> /var/log/arch-install/chroot.log

# Set root password
echo "root:$password" | chpasswd
echo "[CHROOT] Root password set" >> /var/log/arch-install/chroot.log

# Create new user
useradd -m -G wheel,storage,power,audio,video,network -s /bin/bash "$username"
echo "$username:$password" | chpasswd
echo "[CHROOT] User $username created" >> /var/log/arch-install/chroot.log

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
sed -i 's/^# %wheel/%wheel/' /etc/sudoers
echo "[CHROOT] Sudo configured" >> /var/log/arch-install/chroot.log

# Enable essential services
systemctl enable NetworkManager
systemctl enable sshd
echo "[CHROOT] Services enabled" >> /var/log/arch-install/chroot.log

# Update package database
pacman -Sy
echo "[CHROOT] Package database updated" >> /var/log/arch-install/chroot.log

# Clean cache
pacman -Scc --noconfirm
echo "[CHROOT] Package cache cleaned" >> /var/log/arch-install/chroot.log

# Create completion flag
touch /etc/arch-install-complete
echo "[CHROOT] Configuration complete at $(date)" >> /var/log/arch-install/chroot.log

exit 0
EOF
    
    # Replace variables in the script
    sed -i "s/\$hostname/$hostname/g" /mnt/chroot_main.sh
    sed -i "s/\$username/$username/g" /mnt/chroot_main.sh
    sed -i "s/\$password/$password/g" /mnt/chroot_main.sh
    
    # Create log directory in new system
    mkdir -p /mnt/var/log/arch-install
    
    # Execute chroot main script
    chmod +x /mnt/chroot_main.sh
    log_command "arch-chroot /mnt /chroot_main.sh"
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
    
    # Save logs to installed system
    save_logs_to_system
    
    # Unmount partitions
    log_command "umount -R /mnt 2>/dev/null || true"
    log_command "swapoff -a 2>/dev/null || true"
    
    # Log final disk status
    {
        echo "=== Final Disk Status ==="
        lsblk -f
        echo ""
        echo "=== Mount Status ==="
        mount | grep -E "/dev/sd|/dev/nvme|/dev/mmc" || true
        echo ""
    } >> "$DEBUG_LOG"
    
    log_success "Cleanup complete"
}

# Show completion message
show_completion_message() {
    local hostname=$1
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
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
    echo "Installation Time: ${minutes}m ${seconds}s"
    echo "Log File: $LOG_FILE"
    echo "Debug Log: $DEBUG_LOG"
    echo "System Logs: /var/log/arch-install/"
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
        echo "     sudo pacman -S xorg plasma"
        echo "     sudo systemctl enable sddm"
        echo "     reboot"
    fi
    
    echo ""
    echo "3. Troubleshooting:"
    echo "   - Check logs: /var/log/arch-install/"
    echo "   - Check system logs: journalctl -xe"
    echo "   - Check pacman logs: /var/log/pacman.log"
    echo ""
    
    if [[ "$use_wifi" == true ]]; then
        echo "4. WiFi network information:"
        echo "   SSID: $wifi_ssid"
        echo "   Password: [saved]"
        echo ""
    fi
    
    # Log completion
    log_installation_summary
    
    log_success "Installation script completed!"
    log_info "Please check $LOG_FILE for detailed installation log"
}

# Emergency log saving
emergency_log_save() {
    local error_msg="$1"
    
    echo ""
    echo "=== EMERGENCY LOG SAVE ==="
    echo "Error: $error_msg"
    echo "Saving logs to /tmp/arch-install-emergency.log"
    echo ""
    
    # Save critical logs
    {
        echo "=== ARCH INSTALL EMERGENCY LOG ==="
        echo "Error: $error_msg"
        echo "Time: $(date)"
        echo "Script Version: v5.2"
        echo ""
        echo "=== Last 50 lines of debug log ==="
        tail -50 "$DEBUG_LOG" 2>/dev/null || echo "Debug log not found"
        echo ""
        echo "=== System Information ==="
        uname -a
        echo ""
        echo "=== Disk Status ==="
        lsblk -f
        echo ""
        echo "=== Mount Status ==="
        mount | grep -E "/mnt|/dev/sd"
        echo ""
        echo "=== Network Status ==="
        ip addr show
        echo ""
    } > "/tmp/arch-install-emergency.log"
    
    echo "Emergency log saved to: /tmp/arch-install-emergency.log"
    echo "Please share this file for troubleshooting"
}

# Error handler
error_handler() {
    local error_msg="$1"
    local line_no="$2"
    
    log_error "Script failed at line $line_no: $error_msg"
    emergency_log_save "$error_msg"
    
    # Try to save logs to disk if mounted
    if mountpoint -q /mnt; then
        mkdir -p /mnt/tmp/arch-install-logs
        cp "$LOG_FILE" /mnt/tmp/arch-install-logs/ 2>/dev/null || true
        cp "$DEBUG_LOG" /mnt/tmp/arch-install-logs/ 2>/dev/null || true
        cp "/tmp/arch-install-emergency.log" /mnt/tmp/arch-install-logs/ 2>/dev/null || true
        log_info "Logs also saved to /mnt/tmp/arch-install-logs/"
    fi
    
    exit 1
}

# Set error trap
trap 'error_handler "$BASH_COMMAND" "$LINENO"' ERR

# Main function
main() {
    # Initialize logging
    init_logging
    log_system_info
    
    clear
    
    echo "=========================================="
    echo "    Arch Linux Automated Installer v5.2"
    echo "         with Full Logging"
    echo "=========================================="
    echo "  Support: GPT/UEFI or MBR/BIOS"
    echo "  Features: WiFi + Desktop + GPU Drivers"
    echo "  Mirror: Tsinghua University"
    echo "  Logging: Enabled"
    echo "=========================================="
    echo ""
    log_info "Starting Arch Linux installation..."
    log_info "Log file: $LOG_FILE"
    log_info "Debug log: $DEBUG_LOG"
    
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
    
    # Log user configuration (without password)
    log_config "Hostname: $hostname"
    log_config "Username: $username"
    log_config "Password: [set]"
    
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
    
    log_config "Desktop environment: $desktop_environment"
    log_config "Install DE flag: $install_de_flag"
    
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
    
    log_config "GPU driver: $gpu_driver"
    log_config "Install GPU flag: $install_gpu_flag"
    
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
    
    # Log installation confirmation
    log_info "Installation confirmed by user"
    log_info "Starting installation process..."
    
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