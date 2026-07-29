#!/bin/sh
# docs/legal/*.md 최신본을 legal-site/content/로 복사 (배포 전 실행)
set -e
cd "$(dirname "$0")/.."
cp ../docs/legal/*.md content/
echo "synced $(ls content | wc -l) files from docs/legal"
