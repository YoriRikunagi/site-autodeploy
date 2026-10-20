#!/usr/bin/env bash
# Вариант выкладки на обычный хостинг или VPS по SSH (Beget, Timeweb, свой сервер).
# На сервере:  ~/site/releases/NNN/  — версии,  ~/site/current -> releases/NNN  — то, что видит посетитель.
# Корень сайта в панели хостинга указывается на ~/site/current.
# Переключение версии — смена одной ссылки, поэтому выкладка и откат мгновенные и без «полусломанного» сайта.
#
# Нужны секреты GitHub: SSH_HOST, SSH_USER, SSH_KEY (приватный ключ), SITE_PATH (например ~/site)
set -euo pipefail
ID="$1"; SRC="$2"
SSH="ssh -o StrictHostKeyChecking=accept-new $SSH_USER@$SSH_HOST"

# 1. заливаем новую версию рядом с текущей; uploads и конфиги с паролями живут вне релизов и подключаются ссылками
$SSH "mkdir -p $SITE_PATH/releases/$ID $SITE_PATH/shared"
rsync -az --delete -e "ssh -o StrictHostKeyChecking=accept-new" "$SRC/" "$SSH_USER@$SSH_HOST:$SITE_PATH/releases/$ID/"
$SSH "cd $SITE_PATH && for f in \$(ls shared); do ln -sfn ../../shared/\$f releases/$ID/\$f; done"

# 2. запоминаем прошлую версию и переключаем сайт на новую
$SSH "cd $SITE_PATH && readlink current > previous 2>/dev/null || true; ln -sfn releases/$ID current.tmp && mv -Tf current.tmp current"

# 3. резервная копия базы перед выкладкой (если на сайте есть MySQL)
if [ -n "${DB_NAME:-}" ]; then
  $SSH "mkdir -p $SITE_PATH/db-backups && mysqldump $DB_NAME | gzip > $SITE_PATH/db-backups/$ID.sql.gz && ls -t $SITE_PATH/db-backups/* | tail -n +31 | xargs -r rm"
fi

# 4. храним последние 30 версий
$SSH "cd $SITE_PATH/releases && ls | sort -n | head -n -30 | xargs -r rm -rf"
