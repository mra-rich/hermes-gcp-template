#!/usr/bin/env bash
# deploy.sh — deploy Hermes Agent ke Google Cloud Compute Engine.
# Jalankan dari Cloud Shell GCP (gcloud sudah ada) atau laptop dengan gcloud.
#
#   ./deploy.sh            bikin VM + firewall + tampilkan URL dashboard
#   ./deploy.sh reset       ke-reset VM (startup dijalankan ulang, data aman)
#   ./deploy.sh info        tampilkan status VM & IP
#   ./deploy.sh delete      hapus VM + firewall (berhenti bayar/kuota)
set -euo pipefail

# ---------- default (bisa di-override lewat .env) ----------
[ -f .env ] && { set -a; source .env; set +a; }

GCLOUD_BIN="${GCLOUD_BIN:-gcloud}"
command -v "$GCLOUD_BIN" >/dev/null 2>&1 || {
  echo "✗ 'gcloud' tidak ditemukan. Buka https://console.cloud.google.com → "
  echo "  klik ikon Cloud Shell ( >_ ) di kanan atas, lalu jalankan lagi."
  exit 1
}

PROJECT_ID="${PROJECT_ID:-}"
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID="$("$GCLOUD_BIN" config get-value project 2>/dev/null | tr -d '\n' || true)"
fi
if [ -z "$PROJECT_ID" ]; then
  echo "✗ Project GCP belum tahu. Isi PROJECT_ID di .env (salin dari .env.example) "
  echo "   atau: gcloud config set project <PROJECT_ID>"
  exit 1
fi

REGION="${REGION:-us-east1}"
ZONE="${ZONE:-us-east1-c}"
VM_NAME="${VM_NAME:-hermes-gcp}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-micro}"
IMAGE="${IMAGE:-nousresearch/hermes-agent:v2026.7.20}"
PORT="${PORT:-8080}"
FIREWALL_NAME="hermes-gcp-allow-${PORT}"

usage() {
  echo "Usage: ./deploy.sh [deploy|reset|info|delete]"
  exit 0
}

instance_exists() {
  "$GCLOUD_BIN" compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" >/dev/null 2>&1
}

wait_running() {
  echo -n "Menunggu VM RUNNING ..."
  for _ in $(seq 1 30); do
    st="$("$GCLOUD_BIN" compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" \
           --format='value(status)' 2>/dev/null || true)"
    if [ "$st" = "RUNNING" ]; then echo " ✓"; return; fi
    printf '.'
    sleep 5
  done
  echo
  echo "✗ VM belum RUNNING setelah ~150s. Cek: gcloud compute instances list --project $PROJECT_ID"
}

external_ip() {
  "$GCLOUD_BIN" compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" \
    --format='value(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "?"
}

show_info() {
  if instance_exists; then
    st="$("$GCLOUD_BIN" compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(status)')"
    ip="$(external_ip)"
    echo
    echo "===== ${VM_NAME} ====="
    echo "  Status  : $st"
    echo "  IP      : $ip"
    echo "  Dashboard: http://${ip}:${PORT}"
    echo "  Health   : http://${ip}:${PORT}/api/status"
    echo "  SSH      : $GCLOUD_BIN compute ssh $VM_NAME --zone $ZONE"
    echo "  Password : SSH masuk lalu cat /data/.env"
    echo
  else
    echo "✗ VM belum ada. Jalankan ./deploy.sh"
  fi
}

deploy_cmd() {
  "$GCLOUD_BIN" config set project "$PROJECT_ID" >/dev/null
  echo "→ Project : $PROJECT_ID"
  echo "→ VM      : $VM_NAME ($MACHINE_TYPE @ $ZONE)"

  # salinan startup-script dengan IMAGE sesuai .env (biar gampang ganti image di reset)
  START_TMP="/tmp/hermes-startup-$$.sh"
  sed "s|^IMAGE=.*|IMAGE=\"$IMAGE\"|" startup-script.sh > "$START_TMP"

  # 1. Bikin VM (kalau belum ada) pakai startup-script
  if ! instance_exists; then
    echo "  * membuat VM ..."
    "$GCLOUD_BIN" compute instances create "$VM_NAME" \
      --project "$PROJECT_ID" --zone "$ZONE" \
      --machine-type "$MACHINE_TYPE" \
      --image-family ubuntu-2204-lts \
      --image-project ubuntu-os-cloud \
      --boot-disk-size=30 --boot-disk-type=pd-standard \
      --tags hermes-ui \
      --metadata-from-file startup-script="$START_TMP"
  else
    echo "  → VM sudah ada, pasang startup terbaru ..."
    "$GCLOUD_BIN" compute instances add-metadata "$VM_NAME" \
      --project "$PROJECT_ID" --zone "$ZONE" \
      --metadata-from-file startup-script="$START_TMP"
  fi
  rm -f "$START_TMP"

  # 2. Firewall port dashboard (idempotent)
  if ! "$GCLOUD_BIN" compute firewall-rules describe "$FIREWALL_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "  → buka firewall tcp:$PORT ..."
    "$GCLOUD_BIN" compute firewall-rules create "$FIREWALL_NAME" \
      --project "$PROJECT_ID" \
      --network default --direction INGRESS --priority 1000 \
      --action allow --rules "tcp:${PORT}" \
      --source-ranges 0.0.0.0/0 \
      --target-tags hermes-ui
  else
    echo "  → firewall sudah ada"
  fi

  wait_running
  echo "  Tunggu container nyala (boot awal ~60-90 detik) ..."
  sleep 20
  show_info
}

reset_cmd() {
  if ! instance_exists; then
    echo "✗ VM belum ada. Jalankan ./deploy.sh dulu."
    exit 1
  fi
  "$GCLOUD_BIN" compute instances reset "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" >/dev/null
  wait_running
  echo "  ↔ startup dijalankan ulang (data /data persistenda). Menunggu container ..."
  sleep 20
  show_info
}

delete_cmd() {
  [ -n "${1:-}" ] && [ "$1" = "yes" ] || {
    echo "Untuk menghapus: ./deploy.sh delete yes"
    exit 1
  }
  "$GCLOUD_BIN" compute instances delete "$VM_NAME" --zone "$ZONE" --project "$PROJECT_ID" --quiet
  "$GCLOUD_BIN" compute firewall-rules delete "$FIREWALL_NAME" --project "$PROJECT_ID" --quiet 2>/dev/null || true
  echo "✓ VM $VM_NAME dihapus (data boot disk ikut terhapus; kalau mau simpan, snapshot dulu)."
}

cmd="${1:-deploy}"
case "$cmd" in
  deploy)      deploy_cmd ;;
  create)      deploy_cmd ;;
  reset)       reset_cmd ;;
  info)        show_info ;;
  delete)      delete_cmd "${2:-}" ;;
  help|-h|--h) usage ;;
  *)           usage ;;
esac