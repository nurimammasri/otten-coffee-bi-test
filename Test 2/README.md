# Test 2 — BI Dashboard (Apache Superset)

Dashboard **"E-Commerce Business Overview"** dibangun menggunakan Apache Superset yang berjalan secara lokal via Docker.

---

## 📋 Isi Direktori

```
Test 2/
  README.md               ← Panduan ini
  test2_explanation.html  ← Dokumentasi desain dashboard (buka di browser → Print to PDF)
```

---

## ⚙️ Prasyarat

Pastikan sudah terinstall:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (aktif & berjalan)
- Docker Compose (sudah bundled dengan Docker Desktop)

---

## 🚀 Cara Menjalankan Apache Superset

### Langkah 1 — Masuk ke direktori Superset

```powershell
cd C:\superset
```

> ℹ️ Superset di-install via Docker Compose di folder `C:\superset`. Jika foldernya berbeda, sesuaikan path-nya.

---

### Langkah 2 — Start Superset

```powershell
# Jika container sudah pernah dibuat sebelumnya (start ulang):
docker compose start

# Jika pertama kali atau ingin rebuild dari awal:
docker compose up -d
```

---

### Langkah 3 — Buka di Browser

Setelah container running, buka:

```
http://localhost:8088
```

Login dengan:
- **Username:** `admin`
- **Password:** `admin`

---

### Langkah 4 — Install Driver PostgreSQL (jika container baru/rebuild)

Driver `psycopg2-binary` perlu diinstall manual di dalam container karena **tidak persist** saat container di-rebuild:

```powershell
docker exec superset_app pip install psycopg2-binary
```

> ⚠️ **Penting:** Langkah ini hanya diperlukan jika container di-recreate (`docker compose up` dari awal). Jika hanya `docker compose start`, driver tetap ada.

---

### Langkah 5 — Stop Superset

```powershell
docker compose stop
```

---

## 🔌 Koneksi Database

Superset terhubung ke PostgreSQL Supabase (read-only):

| Field    | Value |
|----------|-------|
| Host     | `aws-1-ap-northeast-1.pooler.supabase.com` |
| Port     | `5432` |
| Database | `postgres` |
| Username | `public_readonly.hkmqxnppvspaoldrzzam` |
| Password | `moajj_masoa_javan` |

> 🔒 Koneksi ini **read-only** — hanya SELECT dan EXPLAIN yang bisa dijalankan.

---

## 📊 Dataset yang Digunakan

| Dataset | Dipakai oleh Chart |
|---------|--------------------|
| `ds_order_enriched` | Chart 2 (Revenue Trend), Chart 5 (Payment Method), Chart 6 (Late Delivery), Chart 7 (Orders by State) |
| `ds_kpi_metrics` | Chart 1 (KPI Cards: Revenue, Orders, AOV + MoM%) |
| `ds_order_status` | Chart 4 (Order Status Donut) |
| `ds_late_delivery` | Chart 6 (Late Delivery Rate by Category) |
| `ds_customer_segments` | Chart 8 (Customer Segment Distribution) |

Dataset dibuat via **SQL Lab** di Superset → disimpan sebagai *virtual dataset*.

---

## 🗺️ Layout Dashboard

```
┌─────────────────────────────────────────────────────────┐
│  📊 E-Commerce Business Overview                        │
│  Filters: [Date Range] [Category] [Order Status] [State]│
├──────────────┬──────────────┬──────────────────────────┤
│ KPI Revenue  │  KPI Orders  │   KPI Avg Order Value    │  ← Row 1
│ (MoM ★)      │   (MoM)      │       (MoM)              │
├──────────────────────────┬──────────────────────────────┤
│  Monthly Revenue Trend   │   Order Status Donut         │  ← Row 2
│  (Line Chart)            │                              │
├──────────────────────────┬──────────────────────────────┤
│  Top 10 Categories       │  Revenue by Payment Method   │  ← Row 3
│  (Horizontal Bar)        │  (Stacked Bar)               │
├──────────────┬───────────┴──────────────────────────────┤
│ Late Delivery│ Orders by State │ Customer Segments       │  ← Row 4
│ by Category  │ (Bar Chart)     │ (Pie + Table)           │
└──────────────┴─────────────────┴────────────────────────┘
```

---

## ✅ Fitur Bonus yang Diimplementasikan

| ★ | Fitur | Detail |
|---|-------|--------|
| ★1 | **MoM KPI Card** | Big Number chart dengan *Time Comparison* "1 month ago" → tampilkan % perubahan bulan ke bulan |
| ★2 | **Cross-Filtering** | *Dashboard → Edit → Enable Cross-Filtering* → klik satu chart, chart lain ikut filter |
| ★3 | **Custom SQL Dataset (3+ JOIN)** | `ds_order_enriched` join 7 tabel; `ds_customer_segments` join 3 tabel |

---

## 📄 Dokumentasi Lengkap

Buka `test2_explanation.html` di browser untuk dokumentasi desain chart lengkap beserta SQL query dan business insight per chart.

**Cara export ke PDF:**
1. Buka `test2_explanation.html` di Chrome
2. `Ctrl + P` → Destination: **Save as PDF**
3. Klik Save

---

## 🔧 Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `localhost:8088` tidak bisa diakses | Pastikan Docker Desktop running → `docker compose start` di folder `C:\superset` |
| Error koneksi ke database | Install ulang driver: `docker exec superset_app pip install psycopg2-binary` |
| Chart kosong / no data | Cek filter Date Range di dashboard — pastikan range mencakup 2016–2018 |
| Container tidak ada | Jalankan `docker compose up -d` untuk membuat ulang container |
| Lupa password Superset | Default: username `admin`, password `admin` |
