#!/bin/bash
set -euo pipefail

SRC_ISO="/home/srv/mixos/builds/work-amd64/live-image-amd64.hybrid.iso"
DEST_DIR="/home/srv/mixos/builds"

YYYYMMDD=$(date +%Y%m%d)
OUTPUT_NAME="mixos-forky-2.0-amd64.${YYYYMMDD}.iso"

mkdir -p "$DEST_DIR"
mv "$SRC_ISO" "${DEST_DIR}/${OUTPUT_NAME}"
cd "$DEST_DIR"
sha256sum "$OUTPUT_NAME" > "${OUTPUT_NAME}.sha256"
md5sum "$OUTPUT_NAME" > "${OUTPUT_NAME}.md5"
ls -lh "$OUTPUT_NAME"
echo "SHA256: $(cat "${OUTPUT_NAME}.sha256")"
echo "=== Build output ready ==="
