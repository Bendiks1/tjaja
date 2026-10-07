#!/bin/sh
# Installerer Prisvakt som systemd-tjeneste på Debian/Ubuntu (LXC eller VM). Kjør som root.
set -eu
DIR=/opt/prisvakt
REPO=${PRISVAKT_REPO:-https://github.com/Bendiks1/tjaja}

apt-get update
apt-get install -y git python3-venv
id prisvakt >/dev/null 2>&1 || useradd --system --home-dir "$DIR" --shell /usr/sbin/nologin prisvakt
[ -d "$DIR/.git" ] || git clone "$REPO" "$DIR"
git -c safe.directory="$DIR" -C "$DIR" pull --ff-only

python3 -m venv "$DIR/venv"
"$DIR/venv/bin/pip" install --upgrade playwright
# Chromium + systembiblioteker den trenger (kun nødvendig for butikker med "browser": true)
PLAYWRIGHT_BROWSERS_PATH="$DIR/browsers" "$DIR/venv/bin/playwright" install --with-deps chromium

[ -f "$DIR/config.json" ] || cp "$DIR/config.example.json" "$DIR/config.json"
chown -R prisvakt:prisvakt "$DIR"

cp "$DIR/deploy/prisvakt.service" /etc/systemd/system/prisvakt.service
systemctl daemon-reload
systemctl enable prisvakt
echo
echo "Ferdig. Rediger $DIR/config.json (sett f.eks. ntfy_topic og max_pages), og start med:"
echo "  systemctl start prisvakt && journalctl -u prisvakt -f"
