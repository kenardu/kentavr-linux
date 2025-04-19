#!/bin/bash
# Инициализация git-репозитория для Kentavr Linux

set -e

# Создаем git-репозиторий
git init

# Добавляем .gitignore
cat > .gitignore << EOF
# Временные файлы
work/
out/
*.iso
*.log
*.tmp

# Кэш
__pycache__/
*.py[cod]
*$py.class

# Файлы окружения
.env
.venv
env/
venv/
ENV/

# Системные файлы
.DS_Store
Thumbs.db
EOF

# Добавляем все файлы
git add .

# Делаем первый коммит
git commit -m "Инициализация Kentavr Linux"

# Информация
echo "Git-репозиторий инициализирован."
echo "Используйте следующие команды для добавления удаленного репозитория:"
echo "git remote add origin <url-репозитория>"
echo "git push -u origin master"

exit 0 