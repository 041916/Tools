#!/bin/bash

# 警告：运行此脚本会清除目标磁盘上的所有数据
# 使用前请确认数据备份，并修改设备名（如 /dev/sdX）
DISK="/dev/sdX"

# 1. 连接性检查
echo "检查网络连接..."
ping -c 3 archlinux.org || { echo "无网络连接，退出。"; exit 1; }

# 2. 更新系统时钟
timedatectl set-ntp true

# 3. 分区（这里示例为GPT分区，创建EFI和根分区）
echo "开始磁盘分区..."
parted $DISK -- mklabel gpt
parted $DISK -- mkpart primary fat32 1MiB 512MiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart primary ext4 512MiB 100%

# 4. 格式化分区
EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

echo "格式化 EFI 分区..."
mkfs.fat -F32 $EFI_PART

echo "格式化根分区..."
mkfs.ext4 $ROOT_PART

# 5. 挂载分区
mount $ROOT_PART /mnt
mkdir -p /mnt/boot
mount $EFI_PART /mnt/boot

# 6. 从镜像安装基础系统
echo "安装基础系统..."
pacstrap /mnt base linux linux-firmware vim networkmanager

# 7. 生成 fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 8. 进入新系统
echo "进入新系统配置..."
arch-chroot /mnt /bin/bash <<EOF
# 设置时区
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# 语言配置
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 主机名
echo "myarch" > /etc/hostname

# hosts 文件
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   myarch.localdomain myarch
HOSTS

# 设置root密码
echo "请设置root密码："
passwd

# 启用网络管理
systemctl enable NetworkManager

# 其他自定义设置可以在此添加
EOF

# 9. 完成后退出
echo "安装完成！请重启系统。"
