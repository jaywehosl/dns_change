#!/bin/bash

# Проверка на запуск от root
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Этот скрипт необходимо запускать от имени root (через sudo)."
  exit 1
fi

# Путь к конфигурационному файлу
CONFIG_FILE="/etc/network/interfaces"

# Проверяем существование файла
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Ошибка: Файл $CONFIG_FILE не найден!"
  exit 1
fi

echo "=== Скрипт обновления DNS для конфигурации Aeza ==="

# Запрос новых IP-адресов DNS у пользователя
read -p "Введите IP первого DNS-сервера (например, 111.88.96.50): " DNS1
read -p "Введите IP второго DNS-сервера (например, 111.88.96.51): " DNS2

# Валидация ввода (базовая проверка, что поля не пустые)
if [ -z "$DNS1" ] || [ -z "$DNS2" ]; then
  echo "Ошибка: Оба поля DNS должны быть заполнены."
  exit 1
fi

# Создаем резервную копию на всякий случай
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
echo "Создан бэкап конфигурации: ${CONFIG_FILE}.bak"

# Заменяем строки dns-nameservers в файле конфигурации
# Скрипт ищет строки, начинающиеся с dns-nameservers (с возможными пробелами в начале)
sed -i "s/^[[:space:]]*dns-nameservers.*/  dns-nameservers $DNS1 $DNS2/g" "$CONFIG_FILE"

echo "Файл $CONFIG_FILE успешно обновлен."
echo "=== Применение изменений ==="

# Перезапускаем networking для применения новых параметров интерфейса
systemctl restart networking

# Даем системе 2 секунды сгруппироваться
sleep 2

# Перезапускаем systemd-resolved, чтобы он считал обновленные данные из interfaces
if systemctl is-active --quiet systemd-resolved; then
  systemctl restart systemd-resolved
fi

echo "Настройки применены. Проверяем resolvectl status..."
echo "------------------------------------------------"
resolvectl status | grep -A 5 "DNS Servers"
echo "------------------------------------------------"

echo "=== Тестирование времени ответа (Query time) ==="
echo "Выполняем 5 запросов к google.com..."
echo "------------------------------------------------"

for i in {1..5}; do
  # Выполняем dig, вытаскиваем строку с Query time и убираем лишние пробелы для красоты
  QUERY_TIME=$(dig google.com | grep "Query time" | xargs)
  echo "Запрос $i: $QUERY_TIME"
  # Небольшая пауза между запросами, чтобы тест был честным, а не из локального кэша dig
  sleep 0.5
done

echo "------------------------------------------------"
echo "Готово! Скрипт успешно завершил работу."
