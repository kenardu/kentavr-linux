#!/bin/bash
# Скрипт для сборки ISO-образа Kentavr Linux

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[Kentavr Build]${NC} $1"
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

# Проверка наличия необходимых пакетов
print_message "Проверка наличия необходимых пакетов..."
REQUIRED_PKGS="archiso arch-install-scripts"

for pkg in $REQUIRED_PKGS; do
    if ! pacman -Q $pkg &>/dev/null; then
        print_warning "Пакет $pkg не установлен. Устанавливаем..."
        pacman -S --noconfirm $pkg
    fi
done

# Определение рабочих каталогов
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ISO_DIR="$PROJECT_DIR/iso"
WORK_DIR="$PROJECT_DIR/work"
OUT_DIR="$PROJECT_DIR/out"

# Создание временных каталогов
print_message "Создание рабочих каталогов..."
mkdir -p "$WORK_DIR" "$OUT_DIR"

# Копирование профиля archiso
print_message "Подготовка профиля ISO..."
mkdir -p "$WORK_DIR/profile"
cp -r /usr/share/archiso/configs/releng/* "$WORK_DIR/profile/"

# Копирование наших настроек
cp "$ISO_DIR/profiledef.sh" "$WORK_DIR/profile/"
cp "$ISO_DIR/pacman.conf" "$WORK_DIR/profile/"

# Копирование скрипта установки
mkdir -p "$WORK_DIR/profile/airootfs/usr/local/bin/"
cp "$PROJECT_DIR/installer/kentavr-install.sh" "$WORK_DIR/profile/airootfs/usr/local/bin/"
chmod +x "$WORK_DIR/profile/airootfs/usr/local/bin/kentavr-install.sh"

# Создание пакетов (если необходимо)
# TODO: Добавить сборку пакетов

# Создание ISO-образа
print_message "Создание ISO-образа..."
cd "$WORK_DIR/profile"
mkdir -p "$WORK_DIR/profile/airootfs/etc/skel"

# Создаем список пакетов
cat > "$WORK_DIR/profile/packages.x86_64" << EOF
# Базовые пакеты
base
base-devel
linux
linux-firmware
archlinux-keyring
syslinux
memtest86+
edk2-shell
memtest86+-efi

# Системные инструменты
sudo
parted
gptfdisk
dosfstools
e2fsprogs
grub
efibootmgr
networkmanager
wireless_tools
wpa_supplicant
dhcpcd
nano
vim
dialog
bash-completion

# Графические пакеты (легковесное окружение)
xorg
xorg-xinit
xfce4
xfce4-goodies
lightdm
lightdm-gtk-greeter
network-manager-applet

# Приложения
firefox
pcmanfm
terminator
EOF

# Настройка пользователя live системы
mkdir -p "$WORK_DIR/profile/airootfs/etc/systemd/system/getty@tty1.service.d/"
cat > "$WORK_DIR/profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
EOF

# Создаем скрипт для автоматического запуска
mkdir -p "$WORK_DIR/profile/airootfs/root"
cat > "$WORK_DIR/profile/airootfs/root/.automated_script.sh" << EOF
#!/bin/bash
# Автоматический запуск
# Запуск установщика Kentavr Linux в интерактивном режиме
dialog --title "Kentavr Linux" --yesno "Добро пожаловать в Kentavr Linux!\n\nЗапустить установщик сейчас?" 10 60
if [ \$? -eq 0 ]; then
    exec /usr/local/bin/kentavr-install.sh
else
    echo "Для запуска установщика позже выполните: sudo kentavr-install.sh"
fi
EOF
chmod +x "$WORK_DIR/profile/airootfs/root/.automated_script.sh"

# Настройка графического входа
mkdir -p "$WORK_DIR/profile/airootfs/etc/lightdm"
cat > "$WORK_DIR/profile/airootfs/etc/lightdm/lightdm.conf" << EOF
[LightDM]
greeter-session=lightdm-gtk-greeter
EOF

# Настройка окружения рабочего стола
mkdir -p "$WORK_DIR/profile/airootfs/etc/skel/.config"
echo "exec startxfce4" > "$WORK_DIR/profile/airootfs/etc/skel/.xinitrc"

# Копирование конфигурационных файлов из нашего iso/airootfs в рабочий профиль
if [ -d "$ISO_DIR/airootfs" ]; then
    cp -r "$ISO_DIR/airootfs/"* "$WORK_DIR/profile/airootfs/"
fi

# Сборка ISO
print_message "Сборка ISO образа..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$WORK_DIR/profile"

print_success "ISO-образ успешно создан!"
print_message "Путь к образу: $OUT_DIR/kentavr-$(date +%Y.%m.%d)-x86_64.iso"

# Очистка
read -p "Очистить рабочие каталоги? (y/N): " CLEAN
if [[ "$CLEAN" =~ ^[Yy]$ ]]; then
    print_message "Очистка рабочих каталогов..."
    rm -rf "$WORK_DIR"
fi

print_success "Готово!"
exit 0 