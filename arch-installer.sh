#!/bin/bash

# Arch Linux Installer для NVMe диска
# ВНИМАНИЕ: Этот скрипт удалит все данные на /dev/nvme0n1!

set -e

DISK="/dev/nvme0n1"
BOOT_PART="${DISK}p1"
CRYPT_PART="${DISK}p2"

echo "========================================"
echo "Arch Linux Installer для NVMe"
echo "========================================"
echo "Диск: $DISK"
echo "Boot раздел: $BOOT_PART"
echo "Зашифрованный раздел: $CRYPT_PART"
echo ""
echo "ВНИМАНИЕ: Все данные на диске будут удалены!"
read -p "Продолжить? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Установка отменена."
    exit 1
fi

# Проверка UEFI
if [ ! -d /sys/firmware/efi ]; then
    echo "Ошибка: Система не загружена в UEFI режиме!"
    exit 1
fi

echo ""
echo "=== Шаг 1: Разметка диска ==="
parted -s $DISK mklabel gpt
parted -s $DISK mkpart ESP fat32 1MiB 512MiB
parted -s $DISK set 1 boot on
parted -s $DISK mkpart primary 513MiB 100%

echo ""
echo "=== Шаг 2: Шифрование раздела ==="
echo "Введите пароль для шифрования диска:"
cryptsetup luksFormat $CRYPT_PART

echo "Откройте зашифрованный раздел (введите пароль снова):"
cryptsetup open $CRYPT_PART luks

echo ""
echo "=== Шаг 3: Создание логических разделов ==="
pvcreate /dev/mapper/luks
vgcreate main /dev/mapper/luks
lvcreate -l 100%FREE main -n root

echo ""
echo "=== Шаг 4: Форматирование разделов ==="
mkfs.ext4 /dev/mapper/main-root
mkfs.fat -F 32 $BOOT_PART

echo ""
echo "=== Шаг 5: Монтирование разделов ==="
mount /dev/mapper/main-root /mnt
mkdir -p /mnt/boot
mount $BOOT_PART /mnt/boot

echo ""
echo "=== Шаг 6: Установка базовой системы ==="
pacstrap -K /mnt base linux linux-firmware base-devel lvm2 dhcpcd net-tools iproute2 networkmanager vim micro efibootmgr iwd

echo ""
echo "=== Шаг 7: Генерация fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo ""
echo "=== Шаг 8: Настройка системы ==="

# Создаем скрипт для выполнения внутри chroot
cat > /mnt/setup-chroot.sh << 'EOF'
#!/bin/bash

# Настройка локали
sed -i 's/#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

# Настройка времени
ln -sf /usr/share/zoneinfo/Europe/Kiev /etc/localtime
hwclock --systohc

# Имя хоста
echo "arch" > /etc/hostname

# Пароль root
echo "Установите пароль для root:"
passwd

# Создание пользователя
echo "Создание пользователя 'user':"
useradd -m -G wheel,users,video -s /bin/bash user
echo "Установите пароль для пользователя 'user':"
passwd user

# Включение сервисов
systemctl enable dhcpcd
systemctl enable iwd.service

# Настройка mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf

# Пересборка ядра
mkinitcpio -p linux

# Установка загрузчика
bootctl install --path=/boot

# Настройка загрузчика
cat > /boot/loader/loader.conf << 'LOADER'
timeout 3
default arch
LOADER

# Получение UUID зашифрованного раздела
CRYPT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)

# Создание записи для загрузчика
cat > /boot/loader/entries/arch.conf << ARCHCONF
title Arch Linux by ZProger
linux /vmlinuz-linux
initrd /initramfs-linux.img
options rw cryptdevice=UUID=${CRYPT_UUID}:main root=/dev/mapper/main-root
ARCHCONF

# Настройка sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo ""
echo "Настройка завершена!"
EOF

chmod +x /mnt/setup-chroot.sh
arch-chroot /mnt /setup-chroot.sh
rm /mnt/setup-chroot.sh

echo ""
echo "========================================"
echo "Установка завершена!"
echo "========================================"
echo ""
echo "Для завершения установки выполните:"
echo "1. umount -R /mnt"
echo "2. reboot"
echo ""
echo "После перезагрузки:"
echo "1. Войдите под пользователем 'user'"
echo "2. Установите графическое окружение:"
echo ""
echo "   sudo pacman -Syu"
echo "   sudo pacman -S xorg bspwm sxhkd xorg-xinit xterm git python3"
echo "   echo 'exec bspwm' >> ~/.xinitrc"
echo "   git clone https://github.com/Zproger/bspwm-dotfiles.git"
echo "   cd bspwm-dotfiles"
echo "   python3 Builder/install.py"
echo "   startx"
echo ""
read -p "Нажмите Enter для продолжения..."