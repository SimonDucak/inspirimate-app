#!/bin/bash
# Serve a prebuilt Flutter web app, and rebuild it after an agent task.
#   bash scripts/flutter.sh serve   — web.command (workspace start and restart)
#   bash scripts/flutter.sh build   — build.command (sandboxd runs this when a task finishes)
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  rm -rf "$HOME/flutter"
  cp -a /opt/flutter "$HOME/flutter"
fi
export PATH="$HOME/flutter/bin:$PATH"
export PUB_CACHE="$HOME/.pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true

# preview/ is the directory the static server always serves.
# index.html is replaced last so a refresh during publish still gets a whole page.
publish() {
  staging="$(mktemp -d)"
  cp -a build/web/. "$staging/"
  mkdir -p preview

  find preview -type f ! -name index.html -print0 |
    while IFS= read -r -d '' file; do
      rel="${file#preview/}"
      if [ ! -f "$staging/$rel" ]; then
        rm -f "$file"
      fi
    done

  find "$staging" -type f ! -name index.html -print0 |
    while IFS= read -r -d '' file; do
      rel="${file#"$staging"/}"
      mkdir -p "preview/$(dirname "$rel")"
      cp -a "$file" "preview/$rel"
    done

  cp -a "$staging/index.html" preview/index.html
  rm -rf "$staging"
}

show_building_page() {
  mkdir -p preview
  cp -a building.html preview/index.html
}

# no-store so the 5s refresh in building.html cannot reuse a cached page.
serve_preview() {
  exec python3 -c '
import os, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
os.chdir(sys.argv[1])
class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
ThreadingHTTPServer(("0.0.0.0", 3000), Handler).serve_forever()
' preview
}

build_web() {
  flutter build web --release --pwa-strategy=none
}

case "${1:-serve}" in
  build)
    show_building_page
    build_web
    publish
    ;;
  serve)
    if [ ! -f preview/flutter_bootstrap.js ]; then
      if [ -f build/web/index.html ]; then
        publish
      else
        show_building_page
        python3 -c '
import os, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
os.chdir(sys.argv[1])
class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
ThreadingHTTPServer(("0.0.0.0", 3000), Handler).serve_forever()
' preview &
        server_pid=$!
        trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM
        build_web
        publish
        wait "$server_pid"
        exit
      fi
    fi
    serve_preview
    ;;
  *)
    echo "usage: bash scripts/flutter.sh [serve|build]" >&2
    exit 2
    ;;
esac
