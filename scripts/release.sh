#!/usr/bin/env bash
# Архив версий сайта в ветке backups:
#   releases/NNN/files/   — полная копия сайта в этой версии
#   releases/NNN/meta.json — когда, кто, что изменили, статус
#   live.txt              — номер версии, которая сейчас на сайте
#
#   release.sh new                 — сохранить новую версию из site/ (или из ROLLBACK_TO)
#   release.sh build <id> <out>    — собрать папку для выкладки
#   release.sh status <id> <st>    — записать статус: live | failed
#   release.sh prune <keep>        — оставить последние <keep> версий
set -euo pipefail
B="${BACKUPS_DIR:-backups}"
mkdir -p "$B/releases"
cmd="$1"; shift

meta() { echo "$B/releases/$1/meta.json"; }

case "$cmd" in
new)
  prev=$(cat "$B/live.txt" 2>/dev/null || true)
  last=$(ls "$B/releases" | sort -n | tail -1)
  id=$(printf '%03d' $((10#${last:-0} + 1)))
  if [ -n "${ROLLBACK_TO:-}" ]; then
    from=$(printf '%03d' $((10#$ROLLBACK_TO)))
    [ -d "$B/releases/$from/files" ] || { echo "::error::версии №$from нет в архиве"; exit 1; }
    src="$B/releases/$from/files"; type=rollback
    message="Откат на версию №$from"
  else
    src=site; type=deploy; from=""
    message="${MESSAGE:-}"
  fi
  mkdir -p "$B/releases/$id/files"
  cp -R "$src/." "$B/releases/$id/files/"
  jq -n --arg id "$id" --arg type "$type" --arg from "$from" --arg prev "$prev" \
        --arg time "$(date '+%d.%m.%Y %H:%M')" --arg message "$message" \
        --arg author "${AUTHOR:-}" --arg sha "${SHA:-}" \
        '{id:$id, type:$type, from:$from, prev:$prev, time:$time, message:$message, author:$author, sha:$sha, status:"checking"}' \
        > "$(meta "$id")"
  echo "id=$id"; echo "prev=$prev"
  ;;
build)
  id="$1"; out="$2"
  rm -rf "$out"; mkdir -p "$out"
  cp -R "$B/releases/$id/files/." "$out/"
  # метка версии в каждой странице — по ней проверка после выкладки видит, что на сайте именно эта версия
  find "$out" -name '*.html' -exec sed -i "s|<head>|<head>\n  <meta name=\"release\" content=\"$id\">|" {} +
  mkdir -p "$out/_deploys"
  cp journal/index.html "$out/_deploys/"
  for m in "$B"/releases/*/meta.json; do cat "$m"; done \
    | jq -s --arg live "$id" --arg repo "${REPO:-}" '{live:$live, repo:$repo, releases:(sort_by(.id)|reverse)}' \
    > "$out/_deploys/history.json"
  ;;
status)
  id="$1"; st="$2"
  tmp=$(mktemp); jq --arg st "$st" '.status=$st' "$(meta "$id")" > "$tmp" && mv "$tmp" "$(meta "$id")"
  if [ "$st" = live ]; then
    old=$(cat "$B/live.txt" 2>/dev/null || true)
    if [ -n "$old" ] && [ "$old" != "$id" ]; then
      tmp=$(mktemp); jq '.status="done"' "$(meta "$old")" > "$tmp" && mv "$tmp" "$(meta "$old")"
    fi
    echo "$id" > "$B/live.txt"
  fi
  ;;
prune)
  keep="$1"; live=$(cat "$B/live.txt" 2>/dev/null || true)
  ls "$B/releases" | sort -n | head -n -"$keep" | while read -r r; do
    [ "$r" = "$live" ] || rm -rf "$B/releases/$r"
  done
  ;;
esac
