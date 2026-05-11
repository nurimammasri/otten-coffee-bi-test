# 🚀 Otten Coffee — Full ELT Pipeline (Airflow + dbt + Astronomer Cosmos)

Pipeline orkestrasi data end-to-end untuk **Otten Coffee** menggunakan **Apache Airflow 2.8.1** yang dijalankan via **Docker Compose**, mengintegrasikan **dbt (data build tool)** dengan **Astronomer Cosmos** untuk transformasi data multi-layer secara native di dalam DAG.

---

## 📋 Daftar Isi

1. [Gambaran Arsitektur](#-gambaran-arsitektur)
2. [Struktur Direktori](#-struktur-direktori)
3. [Teknologi yang Digunakan](#-teknologi-yang-digunakan)
4. [Alur Pipeline (DAG)](#-alur-pipeline-dag)
5. [Arsitektur dbt (Data Transformation)](#-arsitektur-dbt-data-transformation)
6. [Prasyarat](#-prasyarat)
7. [Panduan Setup Lengkap](#-panduan-setup-lengkap)
8. [Konfigurasi Koneksi Airflow](#-konfigurasi-koneksi-airflow)
9. [Menjalankan Pipeline](#-menjalankan-pipeline)
10. [Monitoring & Troubleshooting](#-monitoring--troubleshooting)
11. [Referensi Data Source](#-referensi-data-source)
12. [Struktur Docker Compose](#-struktur-docker-compose)

---

## 🏗️ Gambaran Arsitektur

```
┌───────────────────────────────────────────────────────────────────┐
│                     OTTEN COFFEE ELT PIPELINE                     │
│                                                                   │
│  ┌──────────┐    ┌──────────┐    ┌────────────────────────────┐   │
│  │ Data     │    │PostgreSQL│    │   Apache Airflow (Docker)  │   │
│  │ Source   │───▶│ (Local)  │◀───│                            │   │
│  │ (CSV)    │    │ public.* │    │  ┌──────────────────────┐  │   │
│  └──────────┘    └──────────┘    │  │  DAG Orchestration   │  │   │
│                                  │  │                      │  │   │
│  ┌──────────────────────────┐    │  │  1. Extract (Bash)   │  │   │
│  │  import_csv_to_postgres  │    │  │  2. Load (Bash)      │  │   │
│  │  .py (Pre-Airflow Step)  │    │  │  3. Transform (dbt)  │  │   │
│  └──────────────────────────┘    │  │     via Cosmos       │  │   │
│                                  │  │  4. Quality Check    │  │   │
│                                  │  │  5. Notification     │  │   │
│                                  │  └──────────────────────┘  │   │
│                                  └────────────────────────────┘   │
│                                                                   │
│  dbt Layers:  01_staging (view) → 02_intermediate (view) → 03_mart (table)  │
└───────────────────────────────────────────────────────────────────┘
```

**Alur Data:**
1. **Extract**: Data CSV (Brazilian E-Commerce) diimpor ke PostgreSQL lokal menggunakan script Python
2. **Load**: Airflow mensimulasikan proses load raw data ke Data Warehouse
3. **Transform**: Astronomer Cosmos menjalankan dbt models secara native sebagai task group dalam DAG
4. **Quality Check**: Validasi kualitas data setelah transformasi selesai
5. **Notify**: Notifikasi Slack saat pipeline berhasil

---

## 📁 Struktur Direktori

```
Test 3/airflow/
├── .env                        # Environment variable (AIRFLOW_UID=50000)
├── Dockerfile                  # Custom image: airflow:2.8.1 + cosmos + dbt-postgres
├── docker-compose.yaml         # Konfigurasi lengkap semua container Airflow
├── README.md                   # Dokumentasi ini
│
├── dags/                       # Semua DAG Airflow
│   ├── otten_dbt_dag.py        # ★ DAG utama: Full ELT Pipeline
│   └── dbt_pipeline/           # dbt project (dipasang di dalam dags/)
│       ├── dbt_project.yml     # Konfigurasi utama dbt
│       └── models/
│           ├── 01_staging/     # Layer 1: Pembersihan & standarisasi kolom
│           │   ├── stg_customers.sql
│           │   ├── stg_order_items.sql
│           │   ├── stg_order_payments.sql
│           │   ├── stg_order_reviews.sql
│           │   ├── stg_orders.sql
│           │   └── stg_products.sql
│           ├── 02_intermediate/ # Layer 2: Business logic & enrichment
│           │   ├── int_customer_metrics.sql
│           │   ├── int_orders_enriched.sql
│           │   └── int_seller_metrics.sql
│           └── 03_mart/        # Layer 3: Tabel final untuk dashboard
│               ├── mart_customer_segments.sql
│               ├── mart_monthly_revenue.sql
│               └── mart_product_performance.sql
│
├── data/                       # Data source & script import
│   ├── import_csv_to_postgres.py  # Script Python untuk ingest CSV → PostgreSQL
│   ├── customers.csv              (~8.5 MB)
│   ├── geolocation.csv            (~57 MB)
│   ├── order_items.csv            (~15.8 MB)
│   ├── order_payments.csv         (~5.6 MB)
│   ├── order_reviews.csv          (~15.5 MB)
│   ├── orders.csv                 (~19.4 MB)
│   ├── products.csv               (~830 KB)
│   ├── sellers.csv                (~167 KB)
│   └── product_category_name_translation.csv
│
├── logs/                       # Log runtime Airflow (auto-generated)
├── plugins/                    # Custom Airflow plugins
└── config/                     # Konfigurasi tambahan Airflow
```

---

## 🛠️ Teknologi yang Digunakan

| Komponen | Teknologi | Versi | Peran |
|---|---|---|---|
| Orkestrasi | Apache Airflow | 2.8.1 | Penjadwal & eksekutor pipeline |
| Eksekutor | CeleryExecutor + Redis | latest | Eksekusi task paralel |
| Metadata DB | PostgreSQL | 13 | Database internal Airflow |
| Transformasi | dbt-core + dbt-postgres | latest | SQL transformations multi-layer |
| Integrasi dbt | Astronomer Cosmos | latest | Native dbt-as-tasks dalam DAG |
| Kontainerisasi | Docker + Docker Compose | — | Isolasi environment |
| Data Warehouse | PostgreSQL (lokal) | — | Penyimpanan data Otten Coffee |
| Ingest | Python + pandas + SQLAlchemy | — | Import CSV ke PostgreSQL |

---

## 🔄 Alur Pipeline (DAG)

**DAG ID**: `otten_coffee_full_elt_pipeline`
**Jadwal**: `0 2 * * *` → Setiap hari jam **02:00 WIB**
**Owner**: `BI_Engineer`
**Tags**: `otten-coffee`, `elt`, `dbt`, `cosmos`

```
start_pipeline
     │
     ▼
extract_postgres_data_via_airbyte   ← Simulasi ekstraksi Airbyte connector
     │
     ▼
load_raw_data_to_dwh                ← Simulasi load raw data ke public schema
     │
     ▼
┌──────────────────────────────────────────────────────┐
│              dbt_transformations (TaskGroup)          │
│                                                      │
│  stg_customers ──┐                                   │
│  stg_orders ─────┤                                   │
│  stg_order_items─┤──▶ int_orders_enriched ──▶ mart_* │
│  stg_payments ───┤                                   │
│  stg_reviews ────┤──▶ int_customer_metrics           │
│  stg_products ───┘──▶ int_seller_metrics             │
└──────────────────────────────────────────────────────┘
     │
     ▼
run_data_quality_tests              ← Validasi kualitas data
     │
     ▼
send_slack_notification             ← Alert sukses ke Slack
     │
     ▼
end_pipeline
```

**Konfigurasi DAG penting:**
- `catchup=False` — Tidak menjalankan run yang terlewat
- `max_active_runs=1` — Hanya satu run aktif dalam satu waktu
- `retries=1`, `retry_delay=5 menit` — Auto-retry jika task gagal
- `trigger_rule="all_success"` pada notifikasi — Alert hanya terkirim jika semua task sebelumnya sukses

---

## 🧱 Arsitektur dbt (Data Transformation)

### Layer 1 — Staging (`01_staging`) → Materialized as `VIEW`

Layer ini adalah **cerminan bersih** dari tabel raw di database. Tidak ada business logic — hanya rename kolom, cast tipe data, dan filter baris invalid.

| Model | Source Table | Deskripsi |
|---|---|---|
| `stg_orders` | `public.orders` | Standarisasi nama kolom timestamp (purchased_at, approved_at, shipped_at, delivered_at, estimated_delivery_at) |
| `stg_customers` | `public.customers` | Normalisasi kolom customer_id, customer_unique_id, kota & state |
| `stg_order_items` | `public.order_items` | item_price, freight_cost, product_id, seller_id per item |
| `stg_order_payments` | `public.order_payments` | payment_type, installments, payment_amount |
| `stg_order_reviews` | `public.order_reviews` | score, is_low_score flag, review timestamps |
| `stg_products` | `public.products` | Dimensi produk dan kategori |

### Layer 2 — Intermediate (`02_intermediate`) → Materialized as `VIEW`

Layer ini menerapkan **business logic** dan melakukan **join antar staging** untuk menghasilkan dataset yang siap dikonsumsi mart.

| Model | Source Models | Deskripsi |
|---|---|---|
| `int_orders_enriched` | stg_orders, stg_customers, stg_order_items, stg_order_payments, stg_order_reviews | **Model utama**: 1 baris per order dengan metrik delivery (delivery_delay_days, is_late_delivery, total_delivery_days), metrik payment (total_payment, primary_payment_type), dan review score |
| `int_customer_metrics` | stg_customers, int_orders_enriched | Metrik per customer unik: jumlah order, total spend, avg review |
| `int_seller_metrics` | stg_order_items, int_orders_enriched | Performa per seller: jumlah produk terjual, revenue, rating |

**Kolom turunan penting di `int_orders_enriched`:**
```sql
-- Keterlambatan dalam hari (positif = terlambat, negatif = lebih cepat)
delivery_delay_days = ROUND(EXTRACT(EPOCH FROM (delivered_at - estimated_delivery_at)) / 86400.0, 1)

-- Flag boolean keterlambatan
is_late_delivery = (delivered_at > estimated_delivery_at)

-- Total hari dari pembelian hingga terima
total_delivery_days = ROUND(EXTRACT(EPOCH FROM (delivered_at - purchased_at)) / 86400.0, 1)
```

### Layer 3 — Mart (`03_mart`) → Materialized as `TABLE`

Tabel final yang langsung dikonsumsi dashboard. Setiap tabel mart dibuat ulang sepenuhnya (full refresh) saat pipeline berjalan.

| Model | Grain | Deskripsi |
|---|---|---|
| `mart_monthly_revenue` | 1 baris per bulan | Revenue bulanan, total orders, unique customers, avg order value, MoM growth %, YTD revenue, late delivery rate |
| `mart_customer_segments` | 1 baris per customer unik | Segmentasi pelanggan berdasarkan perilaku pembelian (RFM-style) |
| `mart_product_performance` | 1 baris per produk | Performa produk: unit terjual, revenue, avg rating, return rate |

**Contoh kolom `mart_monthly_revenue`:**
```
month | total_orders | unique_customers | total_revenue | avg_order_value
      | late_delivery_rate_pct | avg_review_score
      | prev_month_revenue | mom_revenue_growth_pct
      | ytd_revenue | ytd_orders
```

**Business rules:**
- Mengecualikan order dengan status `canceled` dan `unavailable`
- Revenue = `SUM(total_payment)` (bukan item price, tapi payment yang benar-benar ter-capture)
- MoM growth menggunakan window function `LAG()` atas kolom bulan

---

## ✅ Prasyarat

Sebelum menjalankan pipeline, pastikan semua prasyarat berikut terpenuhi:

### Software Wajib
- [Docker Desktop](https://www.docker.com/products/docker-desktop) (sudah aktif dan berjalan)
- Python 3.8+ (untuk menjalankan script import CSV)
- Library Python: `pandas`, `sqlalchemy`, `psycopg2-binary`

### Resource Minimum (Docker)
Berdasarkan validasi otomatis `airflow-init`:
- **RAM**: Minimal **4 GB** dialokasikan ke Docker
- **CPU**: Minimal **2 core**
- **Disk**: Minimal **10 GB** free space

> **Cara atur resource Docker Desktop:**  
> Buka Docker Desktop → Settings → Resources → sesuaikan Memory & CPUs

### Database PostgreSQL Lokal
Pipeline ini memerlukan database PostgreSQL lokal sebagai Data Warehouse:
- **Host**: `localhost`
- **Port**: `5432`
- **Database**: `otten_coffee`
- **User**: `postgres`
- **Password**: *(sesuai instalasi lokal kamu)*

> ⚠️ Database `otten_coffee` **harus sudah dibuat** sebelum menjalankan script import.

---

## 🚀 Panduan Setup Lengkap

### Langkah 0 — Install Dependencies Python

Jalankan dari direktori `data/` untuk menginstal library yang dibutuhkan script import:

```bash
pip install pandas sqlalchemy psycopg2-binary
```

### Langkah 1 — Import Data CSV ke PostgreSQL

Sebelum menjalankan Airflow, data raw harus sudah ada di PostgreSQL lokal.

```bash
# Navigasi ke folder data
cd "Test 3/airflow/data"

# Jalankan script import
python import_csv_to_postgres.py
```

Script ini akan:
- Terhubung ke `postgresql://postgres:<password>@localhost:5432/otten_coffee`
- Membaca semua file `.csv` di direktori yang sama
- Melakukan `DROP TABLE CASCADE` + recreate untuk setiap tabel
- Mengimpor ~100K+ baris data dalam chunk 10.000 baris

**Output yang diharapkan:**
```
=======================================================
=== OTTEN COFFEE: CSV to PostgreSQL Auto-Importer ===
=======================================================

[OK] Koneksi ke PostgreSQL berhasil!

Ditemukan 9 file CSV. Memulai proses import...

-> Sedang membaca orders.csv ...
   Mengimpor 99.441 baris ke tabel 'orders'...
   [OK] Selesai: Tabel 'orders' berhasil dibuat.
...
SEMUA DATA BERHASIL DIIMPOR KE POSTGRESQL LOKAL!
```

> ⚠️ **Edit password di script sebelum menjalankan:**  
> Buka `data/import_csv_to_postgres.py` baris 28, ubah `db_password` sesuai password PostgreSQL lokal kamu.

### Langkah 2 — Masuk ke Folder Airflow

```bash
cd "Test 3/airflow"
```

### Langkah 3 — Persiapkan File `.env`

File `.env` sudah tersedia dengan isi:
```env
AIRFLOW_UID=50000
```

Untuk Linux/WSL, generate ulang dengan:
```bash
echo -e "AIRFLOW_UID=$(id -u)" > .env
```

Untuk Windows (sudah ter-set ke `50000` secara default — tidak perlu diubah).

### Langkah 4 — Build Custom Docker Image

Karena Dockerfile menambahkan `astronomer-cosmos` dan `dbt-postgres` ke image base Airflow, **wajib build dulu**:

```bash
docker compose build
```

Isi `Dockerfile`:
```dockerfile
FROM apache/airflow:2.8.1
RUN pip install --no-cache-dir astronomer-cosmos dbt-postgres
```

> ℹ️ Proses build membutuhkan koneksi internet dan bisa memakan waktu 5–15 menit pertama kali.

### Langkah 5 — Inisialisasi Database Airflow

Jalankan **satu kali saja** untuk membuat tabel metadata Airflow:

```bash
docker compose up airflow-init
```

Tunggu hingga muncul output:
```
airflow-init-1 exited with code 0
```

> ⚠️ Jika muncul warning resource (RAM/CPU/disk), pastikan Docker Desktop sudah dikonfigurasi dengan resource yang cukup.

### Langkah 6 — Jalankan Semua Container Airflow

```bash
docker compose up -d
```

Perintah ini menjalankan semua service secara background:

| Container | Peran |
|---|---|
| `airflow-webserver` | UI Airflow di port 8080 |
| `airflow-scheduler` | Menjadwalkan & memicu task |
| `airflow-worker` | Mengeksekusi task (Celery Worker) |
| `airflow-triggerer` | Handle deferred/async tasks |
| `postgres` | Metadata database Airflow |
| `redis` | Celery message broker |

### Langkah 7 — Verifikasi Status Container

```bash
docker compose ps
```

Semua container harus berstatus `healthy` atau `running`. Tunggu 1–2 menit hingga health check selesai.

---

## 🔌 Konfigurasi Koneksi Airflow

### Akses Web UI

Buka browser → `http://localhost:8080`

| Field | Value |
|---|---|
| Username | `airflow` |
| Password | `airflow` |

### Membuat Koneksi PostgreSQL (Wajib)

DAG menggunakan Airflow Connection dengan ID `postgres_default` untuk dbt profile. Buat koneksi ini sebelum men-trigger DAG:

1. Di Airflow UI → **Admin** → **Connections**
2. Klik tombol **+** (Add a new connection)
3. Isi form berikut:

| Field | Value |
|---|---|
| **Connection Id** | `postgres_default` |
| **Connection Type** | `Postgres` |
| **Host** | `host.docker.internal` *(bukan `localhost`!)* |
| **Schema** | `otten_coffee` |
| **Login** | `postgres` |
| **Password** | *(password PostgreSQL lokal kamu)* |
| **Port** | `5432` |

> ⚠️ **PENTING**: Gunakan `host.docker.internal` (bukan `localhost`) agar container Docker dapat mengakses PostgreSQL yang berjalan di host machine Windows/Mac.

4. Klik **Save**

**Cara Airflow menggunakan koneksi ini:**
```python
# Di otten_dbt_dag.py — dbt profile mapping
profile_config = ProfileConfig(
    profile_name="otten_coffee_dwh",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="postgres_default",       # ← Connection ID di atas
        profile_args={"schema": "public"},
    )
)
```

---

## ▶️ Menjalankan Pipeline

### Trigger DAG Manual

1. Buka `http://localhost:8080`
2. Cari DAG bernama **`otten_coffee_full_elt_pipeline`**
3. Aktifkan toggle (Unpause DAG) jika masih paused
4. Klik tombol **▶ Trigger DAG** (ikon play)
5. Konfirmasi dengan klik **Trigger**

### Memantau Eksekusi

Klik nama DAG untuk membuka halaman detail, lalu pilih salah satu view:

| View | Kegunaan |
|---|---|
| **Graph View** | Melihat dependency antar task, status real-time dengan warna |
| **Grid View** | Histori run setiap task dalam grid |
| **Gantt View** | Durasi eksekusi setiap task |
| **Logs** | Klik task → View Logs untuk debug |

### Status Warna Task

| Warna | Status |
|---|---|
| 🟢 Hijau | Success |
| 🔴 Merah | Failed |
| 🟡 Kuning | Running |
| 🟠 Oranye | Retry |
| ⚪ Abu-abu | Queued / Upstream Failed |

---

## 🔍 Monitoring & Troubleshooting

### Cek Log Container

```bash
# Log semua container
docker compose logs -f

# Log spesifik per service
docker compose logs -f airflow-scheduler
docker compose logs -f airflow-worker
docker compose logs -f airflow-webserver
```

### Masuk ke Container (Shell)

```bash
# Masuk ke container webserver untuk debug
docker compose exec airflow-webserver bash

# Test koneksi dbt manual
docker compose exec airflow-webserver dbt debug --project-dir /opt/airflow/dags/dbt_pipeline
```

### Masalah Umum & Solusi

| Masalah | Kemungkinan Penyebab | Solusi |
|---|---|---|
| DAG tidak muncul di UI | File DAG error parsing | Cek `docker compose logs airflow-scheduler` |
| Task dbt gagal `connection refused` | Koneksi `postgres_default` salah host | Pastikan gunakan `host.docker.internal`, bukan `localhost` |
| `airflow-init` gagal dengan warning | RAM/CPU Docker kurang | Tambah alokasi resource di Docker Desktop Settings |
| Task dbt gagal `dbt not found` | Path dbt executable salah | Pastikan `DBT_EXECUTABLE_PATH=/home/airflow/.local/bin/dbt` |
| Import CSV gagal | Password PostgreSQL salah | Edit `db_password` di `data/import_csv_to_postgres.py` |
| Container langsung exit | Build image belum dilakukan | Jalankan `docker compose build` terlebih dahulu |
| `astronomer-cosmos` tidak terinstall | Menggunakan image lama | Jalankan `docker compose build --no-cache` |

### Mematikan Airflow

```bash
# Matikan semua container (data tetap tersimpan)
docker compose down

# Matikan + hapus volume (reset total, data Airflow hilang)
docker compose down --volumes
```

---

## 📊 Referensi Data Source

Dataset yang digunakan adalah **Brazilian E-Commerce Public Dataset** dari Olist, mencakup transaksi e-commerce Brasil tahun 2016–2018.

| File CSV | Tabel PostgreSQL | Ukuran | Deskripsi |
|---|---|---|---|
| `orders.csv` | `orders` | ~19.4 MB | Data order (99K+ rows) dengan timestamps lifecycle |
| `order_items.csv` | `order_items` | ~15.8 MB | Detail item per order (product, seller, price, freight) |
| `order_payments.csv` | `order_payments` | ~5.6 MB | Metode & jumlah pembayaran |
| `order_reviews.csv` | `order_reviews` | ~15.5 MB | Ulasan dan skor dari pelanggan |
| `customers.csv` | `customers` | ~8.5 MB | Data pelanggan dengan kota & state |
| `products.csv` | `products` | ~830 KB | Katalog produk dengan kategori & dimensi |
| `sellers.csv` | `sellers` | ~167 KB | Data seller |
| `geolocation.csv` | `geolocation` | ~57 MB | Koordinat geografis per ZIP code |
| `product_category_name_translation.csv` | `product_category_name_translation` | ~2.6 KB | Terjemahan nama kategori (PT → EN) |

**Tabel yang digunakan dbt** (6 dari 9):
`orders`, `order_items`, `order_payments`, `order_reviews`, `customers`, `products`

---

## 🐳 Struktur Docker Compose

File `docker-compose.yaml` mendefinisikan 7 services utama:

```yaml
# Services yang berjalan standar:
postgres:          # Metadata DB Airflow (postgres:13)
redis:             # Celery broker (redis:latest)
airflow-webserver: # UI → port 8080
airflow-scheduler: # Job scheduler
airflow-worker:    # Celery task executor
airflow-triggerer: # Async/deferred task handler
airflow-init:      # One-time DB migration & user setup

# Service opsional (aktifkan dengan --profile):
airflow-cli:       # CLI debugging (--profile debug)
flower:            # Celery monitoring UI port 5555 (--profile flower)
```

**Volume yang di-mount ke container:**
```
./dags    → /opt/airflow/dags     (DAG files + dbt project)
./logs    → /opt/airflow/logs     (Execution logs)
./config  → /opt/airflow/config   (Airflow config)
./plugins → /opt/airflow/plugins  (Custom plugins)
```

**Executor**: `CeleryExecutor` — memungkinkan eksekusi task secara paralel oleh multiple worker.

### Mengaktifkan Flower (Celery Monitor)

```bash
docker compose --profile flower up -d
```
Akses di: `http://localhost:5555`

---

## 📝 Catatan Pengembangan

- **dbt profile** (`otten_coffee_dwh`) di-resolve sepenuhnya dari Airflow Connection `postgres_default` — tidak memerlukan file `profiles.yml` lokal di dalam container.
- **`LoadMode.DBT_LS`** digunakan oleh Cosmos — lebih cepat karena parsing model menggunakan `dbt ls` tanpa compile penuh.
- **Seluruh model dbt di-select** dengan `select=["path:models"]` — semua model dalam folder `models/` akan dieksekusi.
- Untuk mengaktifkan `AIRFLOW__CORE__LOAD_EXAMPLES: 'false'` di `docker-compose.yaml` agar tampilan UI lebih bersih (saat ini masih `true`).
- Script `import_csv_to_postgres.py` menggunakan `DROP TABLE IF EXISTS ... CASCADE` untuk memastikan view dbt lama tidak memblokir recreate tabel.
