# Hermes Agent GCP Template

## Architecture

Google Cloud Compute Engine VM yang menjalankan container Docker resmi Hermes
Agent (image `nousresearch/hermes-agent:v2026.7.20`, pinned digest), dengan
dashboard (UI web) aktif di port 8080 dan data persisten di volume `/data` pada
disk VM (tidak hilang saat instance di-restart).

- `Dockerfile` — sama dengan template Railway: image resmi + entrypoint
  helper (`docker-entrypoint.sh`) + environment dashboard/gateway.
- `docker-entrypoint.sh` — menerjemahkan `ADMIN_USERNAME` / `ADMIN_PASSWORD` /
  `HERMES_DASHBOARD_BASIC_AUTH_SECRET` ke variabel resmi, lalu `exec /init ...`.
- `startup-script.sh` — host-level: install Docker, buat `/data/.env` (password
  random kalau belum ada), `docker pull` + `docker run --restart unless-stopped`
  dengan volume `-v /data:/data`. Idempotent (dipanggil ulang saat reset).
- `deploy.sh` — front-end dari Cloud Shell / laptop: buat VM e2-micro Ubuntu
  22.04 disk 30GB, buka firewall tcp:8080, tampilkan URL dashboard.
- `/data/.env` di VM menyimpan kredensial dashboard; jangan commit ke git.

## Key patterns

- Data hanya di `/data` → container boleh dihapus/diganti bebas; identitas &
  kredensial Hermes (`/data/.hermes`) persisten di disk VM.
- Startup idempotent: `reset` aman, tidak kehilangan data.
- Dashboard dibuka di 0.0.0.0:8080 dengan basic auth (bukan publik tanpa
  password).
- Auto-start: `--restart unless-stopped` + `systemctl docker` enabled.

## GCP notes

- Free tier: `e2-micro` + 30GB disk standard di `us-east1` / `us-central1` /
  `us-west1`. Jangan pindah region kalau mau tetap gratis.
- Zona tertentu kadang `does not have enough resources` → ganti ZONE di `.env`
  (us-central1-a/f, us-west1-b, us-east1-b/c terbukti bekerja).
- `deploy.sh delete yes` hapus VM+firewall; snapshot disk dulu kalau mau simbol.