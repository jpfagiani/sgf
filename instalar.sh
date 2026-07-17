#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  SGF - Sistema de Gestão de Frota — instalador para Debian 13
#  Uso:  sudo ./instalar.sh [porta]     (porta padrão: 80)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

DEST=/opt/sgf
PORT="${1:-80}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Execute como root:  sudo ./instalar.sh"
    exit 1
fi

# Python 3 (já vem no Debian; garante caso seja uma instalação mínima)
if ! command -v python3 >/dev/null 2>&1; then
    echo "[1/5] Instalando python3..."
    apt-get update -qq && apt-get install -y -qq python3
else
    echo "[1/5] python3 OK ($(python3 --version))"
fi

echo "[2/5] Copiando arquivos para $DEST ..."
mkdir -p "$DEST"
cp -f servidor.py run_sgf.py index.html logo.png logo_pp.png backup.sh "$DEST/"
chmod +x "$DEST/backup.sh"

# Migração de dados: se houver um sgf_dados.json ao lado do instalador
# e ainda não existir banco no destino, ele é aproveitado.
# NUNCA sobrescreve um banco já existente.
if [ -f sgf_dados.json ] && [ ! -f "$DEST/sgf_dados.json" ]; then
    echo "      -> banco sgf_dados.json encontrado, migrando."
    cp sgf_dados.json "$DEST/"
fi

echo "[3/5] Criando usuário de serviço 'sgf' ..."
id -u sgf >/dev/null 2>&1 || useradd --system --home "$DEST" --shell /usr/sbin/nologin sgf
chown -R sgf:sgf "$DEST"

echo "[4/5] Instalando serviço systemd (porta $PORT) ..."
sed "s|@PORT@|$PORT|" sgf.service > /etc/systemd/system/sgf.service
systemctl daemon-reload
systemctl enable --now sgf.service

echo "[5/5] Agendando backup diário do banco (20h00) ..."
cat > /etc/cron.d/sgf-backup <<'EOF'
0 20 * * * sgf /opt/sgf/backup.sh
EOF

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "════════════════════════════════════════════════════════"
echo " SGF instalado e ATIVO."
echo "   Acesso na rede:   http://${IP:-<ip-do-servidor>}$( [ "$PORT" != 80 ] && echo ":$PORT" )"
echo "   Status:           systemctl status sgf"
echo "   Logs:             journalctl -u sgf -f"
echo "════════════════════════════════════════════════════════"
