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

## 🚀 Mulai deploy — 1 klik

Buka Cloud Shell dengan repo **sudah ter-clone otomatis**:

[![Buka di Google Cloud Shell](https://gstatic.com/cloudshell/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/mra-rich/hermes-gcp-template.git&cloudshell_workspace=hermes-gcp-template&cloudshell_tutorial=README.md)

setelah terminal terbuka, cukup **3 perintah**:

```bash
cd hermes-gcp-template        # repo sudah ada, masuk folder
cp .env.example .env          # (opsional, sekali — mau ganti password/region?)
./deploy.sh                   # ✅ jalan! bikin VM + buka port + nyalain Hermes
```

> Kalau `cp .env.example .env` dilewati, aman — semua pakai nilai bawaan
> (admin/change-me, region free tier). Dua langkah minimal cukup satu baris:
> `./deploy.sh`.

## Link yang dibutuhkan (semua tuju langsung)

| Keperluan | Link |
|---|---|
| Buat project GCP | https://console.cloud.google.com/projectcreate |
| Cek / link billing | https://console.cloud.google.com/billing |
| Buka terminal Cloud Shell | https://console.cloud.google.com/cloudshell |
| Enable Compute Engine API | https://console.cloud.google.com/apis/library/compute.googleapis.com |
| Daftar VM kamu | https://console.cloud.google.com/compute/instances |
| Lihat repo ini | https://github.com/mra-rich/hermes-gcp-template |

Biar praktis, lakukan dengan urutan ini:
1. Klik **Buat project** → isi nama → Create (catat Project ID)
2. Klik **Billing** → pilih akun billing → project ter-link (wajib walau free tier)
3. Klik **Enable Compute API** → Enable
4. Klik **Cloud Shell** → ketik 3 perintah di atas ✅

## Prasyarat lengkap (sekali, ±10 menit)

Sebelum 3 langkah deploy, GCP minta 4 hal ini **cukup sekali**. Kalau belum
dipasang, `./deploy.sh` akan berhenti di tengah dengan pesan error
(billing/API). Selesaikan ini dulu baru lanjut ke cara deploy.

1. **Akun Google** — login di https://console.cloud.google.com
2. **Project aktif** — di dropdown kiri atas, pilih project (atau buat baru:
   **New Project**). Catat **Project ID**-nya (bukan nama).
3. **Billing ter-link** — menu ☰ → **Billing** → pilih akun billing (atau
   buat baru). GCP mewajibkan link billing walaupun kamu pakai free tier.
   Selama tetap `e2-micro` di region **us-east1 / us-central1 / us-west1**,
   kamu **tidak akan ditagih apa-apa**.
4. **Compute Engine API di-enable** — menu ☰ → **APIs & Services** →
   **Library** → cari **"Compute Engine API"** → **Enable**. (Bisa juga dari
   Cloud Shell: `gcloud services enable compute.googleapis.com` — `deploy.sh`
   juga coba mengaktifkannya otomatis.)

### Cek cepat (kalau ragu)

Buka Cloud Shell (`>_` di kanan atas) lalu ketik:

```bash
gcloud config get-value project
gcloud services list --enabled | grep compute.googleapis.com
billing projects describe <PROJECT_ID> 2>/dev/null | head -2
```

Kalau `gcloud config get-value project` mengeluarkan ID project dan baris
compute ada di daftar services → prasyarat beres, lanjut deploy.

## Cara deploy (3 langkah — setelah prasyarat)

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

## FAQ (biar gak panik)

**"Gratis kok minta kartu/billing?"** — GCP selalu minta billing ter-link
sebagai syarat (semua project). Tagihan tetap 0 selama kamu pakai e2-micro di
region US (free tier). Bisa pasang budget alert di Billing → Budget & alerts.

**"Error: Cloud Billing API disabled" saat deploy** — billing belum ter-link.
Lihat Prasyarat nomor 3.

**"Error: Compute Engine API has not been used"** — API belum di-enable.
Lihat Prasyarat nomor 4.

**"Error: does not have enough resources"** — zona lagi penuh. Ganti
`ZONE=` di `.env` (coba `us-central1-a`, `us-west1-b`, `us-east1-b`, dst).

**"Project ID salah?"** — `deploy.sh` baca `PROJECT_ID` dari `.env`; kalau
kosong dia pakai project default Cloud Shell. Pastikan ID persis (bukan nama
project).

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