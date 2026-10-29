#!/usr/bin/env bash
set -Eeuo pipefail

: "${HUB_USER:?Set HUB_USER to your Docker Hub username}"
: "${IMAGE_TAG:?Set IMAGE_TAG for this pipeline run}"
DOCKERHUB_USER="$(printf '%s' "$HUB_USER" | tr '[:upper:]' '[:lower:]')"
export WEB_IMAGE="${DOCKERHUB_USER}/webserverdocker"
IMAGE_REF="${WEB_IMAGE}:${IMAGE_TAG}"
echo "[BUILD] Building custom Nginx image ${IMAGE_REF}"
docker build --pull --tag "$IMAGE_REF" --file Dockerfile .
echo '[BUILD] Starting a temporary container for an HTTP smoke test'
SMOKE_CONTAINER="webserverdocker-smoke-$$"

cleanup() {
  docker rm -f "$SMOKE_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach --name "$SMOKE_CONTAINER" \
  --publish 127.0.0.1::80 "$IMAGE_REF" >/dev/null
HOST_PORT="$(docker port "$SMOKE_CONTAINER" 80/tcp | head -n 1 | awk -F: '{print $NF}')"
: "${HOST_PORT:?Could not determine the temporary container port}"

HTTP_OK=0

for attempt in $(seq 1 25); do
  if curl --fail --silent "http://127.0.0.1:${HOST_PORT}/" -o /dev/null; then
    HTTP_OK=1
    break
  fi
  sleep 1
done

if [[ "$HTTP_OK" -ne 1 ]]; then
  docker logs "$SMOKE_CONTAINER" || true
  echo '[ERROR] HTTP smoke test failed; image will not be published' >&2
  exit 1
fi

echo "[BUILD] HTTP smoke test passed for ${IMAGE_REF}"
