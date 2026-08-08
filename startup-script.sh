#!/bin/bash
# startup-script.sh — dijalankan oleh Compute Engine saat pertama kali boot
# (dan saat `gcloud compute instances reset`). Idompoten: bisa diulang.
set -e

IMAGE="${IMAGE:-nousresearch/hermes-agent:v2026.7.20}"
PORT="${PORT:-8080}"

echo "[hermes-gcp] startup: image=$IMAGE port=$PORT"

# ---------- 1. Install Docker (kalau belum ada) ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "[hermes-gcp] Installing docker.io ..."
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable docker
  systemctl start docker
fi

# ---------- 2. Buat /data/.env sekali (kalau belum) ----------
mkdir -p /data
if [ ! -f /data/.env ]; then
  RANDOM_PW="$(openssl rand -base64 18 | tr -d '/+=')"
  cat > /data/.env <<INI
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$RANDOM_PW
PORT=${PORT}
INI
  chmod 600 /data/.env
  echo "[hermes-gcp] DASHBOARD PASSWORD BARU (simpan ya): $RANDOM_PW"
fi

set -a
. /data/.env
set +a

# ---------- 3. Jalankan container (hapus yang lama dulu, volume /data tetap) ----------
set +e
docker rm -f hermes >/dev/null 2>&1
set -e

docker pull "$IMAGE"
EXTRA_ENV=""
if [ -n "${HERMES_DASHBOARD_BASIC_AUTH_SECRET:-}" ]; then
  EXTRA_ENV="-e HERMES_DASHBOARD_BASIC_AUTH_SECRET=$HERMES_DASHBOARD_BASIC_AUTH_SECRET"
fi

docker run -d \
  --name hermes \
  --restart unless-stopped \
  -p 8080:8080 \
  -v /data:/data \
  -e PORT=8080 \
  -e ADMIN_USERNAME="$ADMIN_USERNAME" \
  -e ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  $EXTRA_ENV \
  "$IMAGE"

# ---------- 4. Tandai selesai supaya mudah grep ----------
echo "[hermes-gcp] DONE — dashboard: http://$(hostname -I | awk '{print $1}'):8080"