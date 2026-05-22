#!/bin/bash

# Проверка на запуск от root
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка! Этот скрипт необходимо запускать с root правами."
  exit 1
fi

CONFIG_FILE="/etc/network/interfaces"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Ошибка: Файл $CONFIG_FILE не найден!"
  exit 1
fi

echo "Автоматическое обновление DNS для серверов под управлением AezaVM"

#ввод напрямую из TTY, чтобы пайп от curl не ломал интерактивность
read -p "Введите IP первого DNS-сервера (например, 111.88.96.50): " DNS1 < /dev/tty
read -p "Введите IP второго DNS-сервера (например, 111.88.96.51): " DNS2 < /dev/tty

if [ -z "$DNS1" ] || [ -z "$DNS2" ]; then
  echo "Ошибка! Оба поля IP адресов DNS-серверов должны быть заполнены."
  exit 1
fi

#бэкап
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
echo "Создан бэкап конфигурации: ${CONFIG_FILE}.bak"

#смена DNS во всех секциях
sed -i "s/^[[:space:]]*dns-nameservers.*/  dns-nameservers $DNS1 $DNS2/g" "$CONFIG_FILE"

echo "Файл $CONFIG_FILE успешно обновлен."
echo "Применение изменений.."

#перезапуск сети и резолвера
systemctl restart networking
sleep 2

if systemctl is-active --quiet systemd-resolved; then
  systemctl restart systemd-resolved
fi

echo "Настройки применены. Проверяем статус резолвера..."
echo "      "
resolvectl status | grep -A 5 "DNS Servers"
echo "      "

echo "Тестирование времени ответа:"
echo "Выполняем 5 запросов к google.com..."
echo "      "

for i in {1..5}; do
  QUERY_TIME=$(dig google.com | grep "Query time" | xargs)
  echo "Запрос $i: $QUERY_TIME"
  sleep 0.5
done

echo "      "
echo "Готово! Скрипт успешно завершил работу."
