#!/bin/bash
# Kentavr Linux Installer Script

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[Kentavr Installer]${NC} $1"
}

print_error() {
    echo -e "${RED}[Ошибка]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Успешно]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[Внимание]${NC} $1"
}

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root."
    exit 1
fi

clear
cat << "EOF"
  _  __          _                    
 | |/ /___ _ __ | |_ __ ___   ___ _ __ 
 | ' // _ \ '_ \| __/ _' \ \ / / | '__|
 | . \  __/ | | | || (_| |\ V /| | |   
 |_|\_\___|_| |_|\__\__,_| \_/ |_|_|   
                                       
EOF
echo -e "${BLUE}Установщик Kentavr Linux${NC}\n"

# Проверка подключения к интернету
print_message "Проверка подключения к интернету..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    print_error "Нет подключения к интернету. Проверьте соединение и попробуйте снова."
    exit 1
fi
print_success "Соединение с интернетом установлено."

# Выбор диска для установки
print_message "Доступные диски:"
lsblk -d -p -n -l -o NAME,SIZE,MODEL | grep -v "loop"
echo ""

read -p "Введите путь к диску для установки (например, /dev/sda): " TARGET_DISK

if [ ! -b "$TARGET_DISK" ]; then
    print_error "Неправильный диск: $TARGET_DISK"
    exit 1
fi

print_warning "Все данные на $TARGET_DISK будут удалены! Это действие необратимо!"
read -p "Вы уверены? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_message "Установка отменена."
    exit 0
fi

# Разметка диска
print_message "Разметка диска $TARGET_DISK..."

# Создаем разделы: EFI (550M), swap (по размеру RAM, макс 8G) и root (остальное)
MEM_SIZE=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_SIZE" -gt 8 ]; then
    SWAP_SIZE=8G
else
    SWAP_SIZE="${MEM_SIZE}G"
fi

# Удаляем существующую таблицу разделов
wipefs -a "$TARGET_DISK"

# Создаем новую GPT таблицу разделов
parted -s "$TARGET_DISK" mklabel gpt

# Создаем раздел EFI
parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 551MiB
parted -s "$TARGET_DISK" set 1 esp on

# Создаем раздел swap
parted -s "$TARGET_DISK" mkpart primary linux-swap 551MiB "$SWAP_SIZE"

# Создаем раздел root
parted -s "$TARGET_DISK" mkpart primary ext4 "$SWAP_SIZE" 100%

# Форматирование разделов
print_message "Форматирование разделов..."
mkfs.fat -F32 "${TARGET_DISK}1"
mkswap "${TARGET_DISK}2"
mkfs.ext4 "${TARGET_DISK}3"

# Монтирование разделов
print_message "Монтирование разделов..."
mount "${TARGET_DISK}3" /mnt
mkdir -p /mnt/boot
mount "${TARGET_DISK}1" /mnt/boot
swapon "${TARGET_DISK}2"

# Установка базовой системы
print_message "Установка базовой системы..."
pacstrap /mnt base base-devel linux linux-firmware

# Генерация fstab
print_message "Генерация fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Настройка системы
print_message "Настройка системы..."
arch-chroot /mnt /bin/bash -c "
    # Настройка времени
    ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
    hwclock --systohc
    
    # Локализация
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
    echo 'ru_RU.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
    echo 'LANG=ru_RU.UTF-8' > /etc/locale.conf
    echo 'KEYMAP=ru' > /etc/vconsole.conf
    
    # Настройка сети
    echo 'kentavr' > /etc/hostname
    echo '127.0.0.1 localhost' > /etc/hosts
    echo '::1       localhost' >> /etc/hosts
    echo '127.0.1.1 kentavr.localdomain kentavr' >> /etc/hosts
    
    # Установка загрузчика
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=KENTAVR
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # Установка важных пакетов
    pacman -S --noconfirm networkmanager sudo vim
    systemctl enable NetworkManager
    
    # Создание пользователя
    useradd -m -G wheel -s /bin/bash user
    echo 'user:password' | chpasswd
    echo 'root:password' | chpasswd
    
    # Настройка sudo
    echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
"

# Финальная настройка
print_message "Установка завершена. Настройка системы..."

# Размонтирование и перезагрузка
print_message "Размонтирование разделов..."
umount -R /mnt

print_success "Установка Kentavr Linux завершена!"
print_message "Теперь вы можете перезагрузить компьютер и войти в новую систему."
print_warning "Не забудьте изменить пароли пользователя и root после первого входа!"
print_message "Имя пользователя: user"
print_message "Пароль: password"

read -p "Перезагрузить систему сейчас? (y/N): " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    print_message "Перезагрузка системы..."
    reboot
fi

exit 0 