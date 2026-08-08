# Hermes Agent GCP Template (khusus mra-rich)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) ke **Google
Cloud Compute Engine** — pakai image resmi Nous Research, dashboard web (UI)
aktif di port 8080, data persisten di disk VM (tidak hilang saat restart).

Template ini adalah versi **GCP** dari template Railway
(`mra-rich/hermes-agent-railway-template`) — struktur & entrypoint sama persis,
yang berbeda hanya cara deploy-nya: bukan satu-klik Railway, tapi **satu
perintah `deploy.sh`** dari Google (tersedia gratis di Cloud Shell).

## Isi repo

| File | Fungsi |
|---|---|
| `Dockerfile` | Sama dengan versi Railway (image resmi, pinned v2026.7.20) |
| `docker-entrypoint.sh` | Sama dengan versi Railway (peta variabel → dashboard) |
| `deploy.sh` | **Deploy ke GCP** — bikin VM, firewall, jalankan container |
| `startup-script.sh` | Script di VM: install Docker + jalankan Hermes + data persisten |
| `docker-compose.yml` | Coban versi jalan lokal (opsional) |
| `.env.example` | Variabel yang bisa kamu set sebelum deploy |
| `CLAUDE.md` | Catatan arsitektur untuk asisten/agen |

## Cara deploy (3 langkah)

1. **Buka Cloud Shell GCP**: https://console.cloud.google.com → klik ikon
   `>_` di kanan atas.
2. **Clone repo ini**:
   ```bash
   git clone https://github.com/<kamu>/hermes-gcp-template.git
   cd hermes-gcp-template
   ```
3. **(Opsional) set env** — salin `.env.example` → `.env`, isi username/
   password dashboard (kalau dikosongkan, password digenerate random & disimpan
   di file `/data/.env` dalam VM):
   ```bash
   cp .env.example .env
   nano .env
   ```
4. **Deploy**:
   ```bash
   ./deploy.sh
   ```
   Script akan: cek `gcloud` (sudah ada di Cloud Shell) → bikin VM
   `e2-micro` Ubuntu 22.04 disk 30GB → buka firewall port 8080 → jalankan
   container Hermes → tampilkan URL dashboard.

   Misal output:
   ```
   ✅ VM   : hermes-gcp (us-east1-c, e2-micro, RUNNING)
   ✅ Portal: http://34.xx.xx.xx:8080
   Username: admin | Password: (cat /data/.env di VM)
   ```

## Setelah deploy

- **Dashboard (UI)**: buka `http://<IP_VM>:8080` → login pakai username/
  password → kelola model, kredensial, skills, channel Telegram/WA, dsb.
- **Health check**: `http://<IP_VM>:8080/api/status`
- **Data**: semua tersimpan di `/data/.hermes` (disk VM — aman saat restart,
  TERMINATED/start ulang tidak menghapus).
- **SSH**: `gcloud compute ssh hermes-gcp --zone us-east1-c`
- **Lihat password**: di dalam VM, `cat /data/.env`
- **Ubah password**: edit `/data/.env` di VM → `sudo docker restart hermes`

## Biaya

Default template: `e2-micro` di region free tier (`us-east1` / `us-central1` /
`us-west1`) + disk 30GB → **masih dalam free tier GCP = gratis**. Kalau kamu
ubah region / machine type / tambah disk → mulai dikenai biaya. Pasang budget
alert di GCP Billing supaya gak kaget.

## Upgrade Hermes

Ganti tag+dari digest di `Dockerfile` (lihat
[release notes](https://github.com/NousResearch/hermes-agent/releases)),
komit, lalu `./deploy.sh reset` untuk reload VM dengan image baru. Jangan
pakai tag `latest`. Setelah image diganti, data `/data` tidak ikut hilang
(kontainer dihapus, volume tidak).

## Hapus semua (biar gak ada tagihan)

```bash
gcloud compute instances delete hermes-gcp --zone us-east1-c
gcloud compute firewall-rules delete hermes-gcp-allow-8080
```

## Apache 2.0
Template based on [arjunkomath/hermes-agent-railway-template](https://github.com/arjunkomath/hermes-agent-railway-template).