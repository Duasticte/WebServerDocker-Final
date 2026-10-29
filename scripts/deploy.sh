#!/usr/bin/env bash
set -Eeuo pipefail

: "${HUB_USER:?Set HUB_USER to your Docker Hub username}"
: "${HUB_TOKEN:?Set HUB_TOKEN to a Docker Hub access token}"
: "${IMAGE_TAG:?Set IMAGE_TAG for this pipeline run}"
: "${MYSQL_ROOT_PASSWORD:?Set MYSQL_ROOT_PASSWORD in CI/CD variables}"
: "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD in CI/CD variables}"

DOCKERHUB_USER="$(printf '%s' "$HUB_USER" | tr '[:upper:]' '[:lower:]')"
export HUB_USER="$DOCKERHUB_USER"
export WEB_IMAGE="${DOCKERHUB_USER}/webserverdocker"
export IMAGE_TAG MYSQL_ROOT_PASSWORD MYSQL_PASSWORD

IMAGE_REF="${WEB_IMAGE}:${IMAGE_TAG}"
logout_docker() {
  docker logout >/dev/null 2>&1 || true
}
trap logout_docker EXIT

echo "[DOCKER] Signing in to Docker Hub and publishing ${IMAGE_REF}"
printf '%s' "$HUB_TOKEN" |
  docker login --username "$HUB_USER" --password-stdin >/dev/null

docker push "$IMAGE_REF"

# GitLab and Jenkins share one Docker Engine on Kali.
# Deployments are serialized; builds can run independently.
LOCK_FILE=/tmp/webserverdocker-deploy.lock
(umask 000; touch "$LOCK_FILE")
exec 9>"$LOCK_FILE"
echo '[DOCKER] Waiting for the shared deployment lock'
flock -x 9
echo '[DOCKER] Recording the previous web image, if any'
OLD_CONTAINER="$(docker compose -p webserverdocker -f compose.yaml ps -q web | head -n 1)"
OLD_IMAGE_REF=''
if [[ -n "$OLD_CONTAINER" ]]; then
  OLD_IMAGE_REF="$(docker inspect --format '{{.Config.Image}}' "$OLD_CONTAINER")"
fi


echo '[DOCKER] Stopping this project containers; preserving the MySQL volume'
docker compose -p webserverdocker -f compose.yaml down --remove-orphans
echo '[DOCKER] Pulling the image and official MySQL/phpMyAdmin images'
docker compose -p webserverdocker -f compose.yaml pull


echo '[DOCKER] Starting the full Compose project'
docker compose -p webserverdocker -f compose.yaml up -d --no-build --force-recreate

echo '[DOCKER] Current Compose services:'
docker compose -p webserverdocker -f compose.yaml ps

echo '[DOCKER] Checking website HTTP response'
HTTP_OK=0

for attempt in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:8088/ -o /dev/null; then
    HTTP_OK=1
    break
  fi
  sleep 2
done

if [[ "$HTTP_OK" -ne 1 ]]; then
  echo '[ERROR] Website did not respond on http://127.0.0.1:8088' >&2
  docker compose -p webserverdocker -f compose.yaml logs --tail=50 web || true
  exit 1
fi

# Remove only the previous local image tag used by this project.
# Do not remove images used by other labs, or the MySQL volume.
if [[ -n "$OLD_IMAGE_REF" &&
      "$OLD_IMAGE_REF" == "${WEB_IMAGE}:"* &&
      "$OLD_IMAGE_REF" != "$IMAGE_REF" ]]; then
  echo "[DOCKER] Removing previous project image tag: ${OLD_IMAGE_REF}"
  docker image rm "$OLD_IMAGE_REF" >/dev/null 2>&1 ||
    echo '[DOCKER] Previous image tag is still referenced; leaving it in place'
fi

echo "[SUCCESS] Image published: ${IMAGE_REF}"
echo '[SUCCESS] Website: http://localhost:8088'
echo '[SUCCESS] phpMyAdmin: http://localhost:8089'
echo '[SUCCESS] MySQL is available internally as service db on port 3306'
