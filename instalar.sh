#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  SGF - Sistema de Gestão de Frota — instalador para Debian 13
#  Uso:  sudo ./instalar.sh [porta]     (porta padrão: 80)
# ─────────────────────────────────────────────────────────────
set -euo pipefail

DEST=/opt/sgf
# Convenção de portas do ecossistema (mesma rede/servidor de outros projetos
# do CDPNI): 80 portal-sistemas, 8080 painel do GWOS, 8443 portal-samba.
# O SGF fica na 8091 por padrão — evita colidir com os três acima quando os
# quatro dividem a mesma máquina, o que é o caso mais comum.
PORT="${1:-8091}"

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

# Porta ocupada por outro serviço só apareceria depois, como "Address already
# in use" repetido no journal enquanto o systemd reinicia em laço. Melhor dizer
# agora, com o nome do culpado — mesmo padrão adotado no portal-sistemas.
if command -v ss >/dev/null 2>&1 && ss -lntH "sport = :$PORT" 2>/dev/null | grep -q .; then
    echo "A porta $PORT já está ocupada por outro processo:"
    ss -lptnH "sport = :$PORT" 2>/dev/null | sed 's/^/  /'
    echo
    if [ "$PORT" = "80" ] || [ "$PORT" = "8080" ] || [ "$PORT" = "8443" ]; then
        echo "Pela convenção do ecossistema, essa porta já pertence a outro sistema:"
        echo "  80    portal-sistemas    8080  painel do GWOS    8443  portal-samba"
        echo "Reinstale numa porta livre, por exemplo:  sudo ./instalar.sh 8091"
    else
        echo "Libere a porta, ou reinstale em outra:  sudo ./instalar.sh <porta>"
    fi
    exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DEST"
if [ "$(realpath "$SRC")" = "$(realpath "$DEST")" ]; then
    # Repositório clonado direto em /opt/sgf: nada a copiar
    echo "[2/5] Instalando a partir do próprio $DEST (cópia dispensada)."
else
    echo "[2/5] Copiando arquivos para $DEST ..."
    cp -f "$SRC"/servidor.py "$SRC"/run_sgf.py "$SRC"/index.html \
          "$SRC"/logo.png "$SRC"/logo_pp.png "$SRC"/backup.sh "$DEST/"

    # Migração de dados: se houver um sgf_dados.json ao lado do instalador
    # e ainda não existir banco no destino, ele é aproveitado.
    # NUNCA sobrescreve um banco já existente.
    if [ -f "$SRC/sgf_dados.json" ] && [ ! -f "$DEST/sgf_dados.json" ]; then
        echo "      -> banco sgf_dados.json encontrado, migrando."
        cp "$SRC/sgf_dados.json" "$DEST/"
    fi
fi
chmod +x "$DEST/backup.sh"

echo "[3/5] Criando usuário de serviço 'sgf' ..."
id -u sgf >/dev/null 2>&1 || useradd --system --home "$DEST" --shell /usr/sbin/nologin sgf
chown -R sgf:sgf "$DEST"

echo "[4/5] Instalando serviço systemd (porta $PORT) ..."
sed "s|@PORT@|$PORT|" "$SRC/sgf.service" > /etc/systemd/system/sgf.service
systemctl daemon-reload
systemctl enable --now sgf.service

echo "[5/5] Agendando backup diário do banco (20h00) ..."
cat > /etc/cron.d/sgf-backup <<'EOF'
0 20 * * * sgf /opt/sgf/backup.sh
EOF

# O firewall do Samba (nftables, política DROP) só libera esta porta se for
# reinstalado/re-executado DEPOIS do SGF instalado — ele detecta o SGF sozinho,
# mas só quando roda. Instalando o SGF depois, é preciso avisar.
if command -v nft >/dev/null 2>&1 && nft list tables 2>/dev/null | grep -q "inet cdpni"; then
    echo
    echo "⚠  Firewall do Samba detectado nesta máquina (política padrão: bloquear)."
    echo "   Para a rede alcançar a porta $PORT, rode uma vez:"
    echo "     cd /opt/smb && sudo bash scripts/atualizar_firewall.sh"
    echo "   (idempotente — não altera usuários, RAID nem dados já configurados)"
fi

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "════════════════════════════════════════════════════════"
echo " SGF instalado e ATIVO."
echo "   Acesso na rede:   http://${IP:-<ip-do-servidor>}$( [ "$PORT" != 80 ] && echo ":$PORT" )"
echo "   Status:           systemctl status sgf"
echo "   Logs:             journalctl -u sgf -f"
echo "════════════════════════════════════════════════════════"
