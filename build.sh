#!/bin/bash
# Главный скрипт для сборки Kentavr Linux

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${BLUE}[Kentavr]${NC} $1"
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

cat << "EOF"
  _  __          _                    
 | |/ /___ _ __ | |_ __ ___   ___ _ __ 
 | ' // _ \ '_ \| __/ _' \ \ / / | '__|
 | . \  __/ | | | || (_| |\ V /| | |   
 |_|\_\___|_| |_|\__\__,_| \_/ |_|_|   
                                      
EOF
echo -e "${BLUE}Система сборки Kentavr Linux${NC}\n"

# Проверка параметров командной строки
if [[ $# -eq 0 ]]; then
    print_message "Доступные команды:"
    echo "  iso     - Собрать ISO образ"
    echo "  clean   - Очистить временные файлы"
    echo "  help    - Показать эту справку"
    exit 0
fi

# Главная логика
case "$1" in
    iso)
        print_message "Запуск сборки ISO образа..."
        # Устанавливаем права на выполнение
        chmod +x scripts/build-iso.sh
        chmod +x installer/kentavr-install.sh
        
        # Запускаем сборку ISO
        sudo ./scripts/build-iso.sh
        ;;
    clean)
        print_message "Очистка временных файлов..."
        rm -rf work/ out/
        print_success "Очистка завершена."
        ;;
    help)
        print_message "Доступные команды:"
        echo "  iso     - Собрать ISO образ"
        echo "  clean   - Очистить временные файлы"
        echo "  help    - Показать эту справку"
        ;;
    *)
        print_error "Неизвестная команда: $1"
        print_message "Используйте './build.sh help' для просмотра доступных команд"
        exit 1
        ;;
esac

exit 0 