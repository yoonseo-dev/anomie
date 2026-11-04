#!/usr/bin/env bash
# 배포 서버의 DB를 백업한다 (gzip SQL). 최근 BACKUP_KEEP_DAYS일치만 남긴다.
#
#   bash scripts/backup-db.sh                     # ~/backups/anomie-YYYYmmdd-HHMM.sql.gz
#   crontab -e 에 매일 새벽 4시:  0 4 * * * cd ~/anomie && bash scripts/backup-db.sh >> ~/backups/backup.log 2>&1
#
# 서버가 사라지면 백업도 같이 사라지므로, 가끔 PC로 받아 두거나 S3에 올린다:
#   scp -i <키.pem> ubuntu@<탄력적 IP>:~/backups/anomie-*.sql.gz .
# 되살리기: gunzip -c 파일.sql.gz | docker compose -f docker-compose.prod.yml exec -T db psql -U anomie anomie
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP="${BACKUP_KEEP_DAYS:-14}"
mkdir -p "$DIR"

file="$DIR/anomie-$(date +%Y%m%d-%H%M).sql.gz"
docker compose -f "$ROOT/docker-compose.prod.yml" exec -T db pg_dump -U anomie anomie | gzip > "$file"
echo "백업: $file ($(du -h "$file" | cut -f1))"

find "$DIR" -name 'anomie-*.sql.gz' -mtime +"$KEEP" -delete
