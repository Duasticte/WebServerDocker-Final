#!/usr/bin/env bash
set -Eeuo pipefail
echo '[TEST] Checking supplied website files and project configuration'

for file in \
  website/index.html \
  website/style.css \
  website/script.js \
  Dockerfile \
  compose.yaml \
  .gitlab-ci.yml \
  Jenkinsfile; do
  if [[ ! -s "$file" ]]; then
    echo "[ERROR] Missing or empty file: $file" >&2
    exit 1
  fi
done

command -v docker >/dev/null || {
  echo '[ERROR] Docker CLI is not installed' >&2
  exit 1
}

docker compose version >/dev/null

WEB_IMAGE='example/webserverdocker' \
IMAGE_TAG='check' \
MYSQL_ROOT_PASSWORD='dummy-root-password' \
MYSQL_PASSWORD='dummy-app-password' \
  docker compose -f compose.yaml config --quiet
echo "[TEST] All required files exist"
echo '[TEST] Docker Compose configuration is valid'
