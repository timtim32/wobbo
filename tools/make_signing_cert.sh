#!/bin/bash
# Creates Wobbo's self-signed code-signing certificate in the login keychain
# (standalone-app design D2). Run it once on the release Mac. Every release is
# signed with it, so macOS keeps permissions such as Accessibility across updates.
#
#   tools/make_signing_cert.sh <backup-folder>
#
# The backup folder receives wobbo-signing.p12 and its password (mode 0600).
# Keep both somewhere safe: a new certificate makes every user grant
# Accessibility again.
set -euo pipefail

NAME="Wobbo"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
OPENSSL=/usr/bin/openssl # LibreSSL: writes a .p12 that `security import` reads

if [ $# -ne 1 ]; then
	echo "usage: $0 <backup-folder>" >&2
	exit 2
fi
BACKUP="$1"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
	echo "A certificate named \"$NAME\" is already in the login keychain; nothing to do." >&2
	exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 7300 \
	-config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

PASSWORD="$("$OPENSSL" rand -base64 24)"
"$OPENSSL" pkcs12 -export -name "$NAME" -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
	-out "$WORK/wobbo-signing.p12" -passout "pass:$PASSWORD"

# -T: codesign may use the key without asking every time.
security import "$WORK/wobbo-signing.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null

mkdir -p "$BACKUP"
umask 077
cp "$WORK/wobbo-signing.p12" "$BACKUP/wobbo-signing.p12"
printf '%s\n' "$PASSWORD" >"$BACKUP/wobbo-signing.password"
chmod 600 "$BACKUP/wobbo-signing.p12" "$BACKUP/wobbo-signing.password"

echo "Created the \"$NAME\" signing certificate in the login keychain."
echo "Backup: $BACKUP/wobbo-signing.p12 (password in wobbo-signing.password). Keep both safe."
