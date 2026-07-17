#!/bin/bash
# Desinstala o serviço SGF. O banco de dados (/opt/sgf/sgf_dados.json)
# e os backups são PRESERVADOS — remova /opt/sgf manualmente se quiser.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root:  sudo ./desinstalar.sh"
    exit 1
fi

systemctl disable --now sgf.service 2>/dev/null || true
rm -f /etc/systemd/system/sgf.service /etc/cron.d/sgf-backup
systemctl daemon-reload

echo "Serviço removido. Dados preservados em /opt/sgf (apague com: rm -rf /opt/sgf)"
