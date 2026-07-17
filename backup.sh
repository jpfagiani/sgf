#!/bin/bash
# Backup do banco do SGF (sgf_dados.json). Mantém os últimos 30.
# Agendado pelo instalador em /etc/cron.d/sgf-backup (diário, 20h00).
set -euo pipefail

DIR=/opt/sgf
DEST="$DIR/backups"

[ -f "$DIR/sgf_dados.json" ] || exit 0
mkdir -p "$DEST"
cp "$DIR/sgf_dados.json" "$DEST/sgf_dados_$(date +%F_%H%M).json"

# Retenção: apaga os mais antigos, mantendo 30
ls -1t "$DEST"/sgf_dados_*.json 2>/dev/null | tail -n +31 | xargs -r rm --
