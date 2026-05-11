# 🛠️ Panduan Lengkap Pembuatan Dashboard — Apache Superset
## Test 2: "E-Commerce Business Overview"

---

## FASE 1 — Setup & Koneksi Database

### Step 1.1 — Jalankan Superset

```powershell
cd C:\superset
docker compose start
```

Buka browser: **http://localhost:8088** → Login `admin` / `admin`

---

### Step 1.2 — Install Driver PostgreSQL

Wajib dilakukan sekali (atau setiap kali container di-rebuild):

```powershell
docker exec superset_app pip install psycopg2-binary
```

---

### Step 1.3 — Tambahkan Koneksi Database

1. Klik menu **Settings** (ikon ⚙️ kanan atas) → **Database Connections**
2. Klik tombol **+ Database**
3. Pilih tipe database: **PostgreSQL**
4. Isi form koneksi:

| Field        | Value |
|--------------|-------|
| Display Name | `Olist Supabase` |
| Host         | `aws-1-ap-northeast-1.pooler.supabase.com` |
| Port         | `5432` |
| Database     | `postgres` |
| Username     | `public_readonly.hkmqxnppvspaoldrzzam` |
| Password     | `moajj_masoa_javan` |

5. Klik **Test Connection** → pastikan muncul ✅ "Connection looks good!"
6. Klik **Connect**

---

## FASE 2 — Membuat Custom SQL Datasets

Dataset dibuat di **SQL Lab**, lalu di-save sebagai Virtual Dataset.

### Step 2.1 — Buka SQL Lab

Menu atas → **SQL** → **SQL Lab**

Pastikan pilih schema: `public`

---

### Step 2.2 — Buat Dataset `ds_order_enriched`

Ini adalah dataset utama yang di-join dari 7 tabel. Dipakai oleh Chart 2, 5, 6, 7.

Ketik query berikut di SQL Lab:

```sql
-- Dataset: ds_order_enriched
-- Joins: orders + customers + order_items + products
--        + product_category_name_translation + order_payments + order_reviews

SELECT
    o.order_id,
    o.order_status,
    DATE_TRUNC('month', o.order_purchase_timestamp)  AS order_month,
    o.order_purchase_timestamp                        AS ordered_at,
    o.order_delivered_customer_date                   AS delivered_at,
    o.order_estimated_delivery_date                   AS estimated_at,

    -- Customer geography
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,

    -- Product category (English)
    COALESCE(t.product_category_name_english, 'uncategorized') AS category,

    -- Revenue metrics
    SUM(oi.price)                                     AS items_revenue,
    SUM(oi.freight_value)                             AS freight_revenue,
    SUM(op.payment_value)                             AS total_payment,
    SUM(op.payment_value) FILTER (WHERE op.payment_type = 'credit_card')
                                                      AS credit_card_payment,
    SUM(op.payment_value) FILTER (WHERE op.payment_type = 'boleto')
                                                      AS boleto_payment,
    SUM(op.payment_value) FILTER (
        WHERE op.payment_type NOT IN ('credit_card', 'boleto'))
                                                      AS other_payment,

    -- Delivery performance
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN TRUE
        ELSE FALSE
    END                                               AS is_late,
    ROUND((EXTRACT(EPOCH FROM (
        o.order_delivered_customer_date - o.order_estimated_delivery_date
    )) / 86400.0)::numeric, 1)                        AS delay_days,

    -- Review score
    ROUND(AVG(r.review_score)::numeric, 1)            AS avg_review_score

FROM orders o
JOIN customers c          ON c.customer_id    = o.customer_id
JOIN order_items oi       ON oi.order_id      = o.order_id
JOIN products p           ON p.product_id     = oi.product_id
LEFT JOIN product_category_name_translation t
                          ON t.product_category_name = p.product_category_name
LEFT JOIN order_payments op ON op.order_id    = o.order_id
LEFT JOIN order_reviews r   ON r.order_id     = o.order_id
WHERE o.order_status != 'canceled'
GROUP BY 1,2,3,4,5,6,7,8,9,10,17,18
```

**Cara save sebagai dataset:**
1. Klik **▶ Run** untuk test query
2. Klik tombol **SAVE** (kanan atas) → **Save dataset**
3. Beri nama: `ds_order_enriched`
4. Klik **Save & Explore**

---

### Step 2.3 — Buat Dataset `ds_customer_segments`

Dipakai oleh Chart 8 (Customer Segment Distribution).

```sql
-- Dataset: ds_customer_segments
-- Klasifikasi pelanggan: new / returning / at_risk / churned

WITH customer_summary AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)                    AS total_orders,
        ROUND(SUM(op.payment_value)::numeric, 2)      AS total_spend,
        MAX(o.order_purchase_timestamp)               AS last_order_at
    FROM orders o
    JOIN customers c      ON c.customer_id = o.customer_id
    JOIN order_payments op ON op.order_id  = o.order_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id, c.customer_state
),
ref_date AS (SELECT MAX(last_order_at) AS max_date FROM customer_summary)
SELECT
    cs.*,
    EXTRACT(DAY FROM (r.max_date - cs.last_order_at)) AS days_since_last_order,
    CASE
        WHEN cs.total_orders = 1                                                          THEN 'new'
        WHEN cs.total_orders > 1 AND EXTRACT(DAY FROM (r.max_date - cs.last_order_at)) <= 180  THEN 'returning'
        WHEN cs.total_orders > 1 AND EXTRACT(DAY FROM (r.max_date - cs.last_order_at)) <= 365  THEN 'at_risk'
        ELSE 'churned'
    END                                               AS segment
FROM customer_summary cs CROSS JOIN ref_date r
```

**Cara save:**
1. Klik **▶ Run**
2. Klik **SAVE** → **Save dataset**
3. Beri nama: `ds_customer_segments`
4. Klik **Save & Explore**

---

### Step 2.4 — Buat Dataset `ds_kpi_metrics` (untuk KPI Cards)

```sql
-- Dataset untuk KPI Cards dengan MoM calculation
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)  AS month,
    ROUND(SUM(op.payment_value)::numeric, 2)          AS total_revenue,
    COUNT(DISTINCT o.order_id)                        AS total_orders,
    ROUND(AVG(op.payment_value)::numeric, 2)          AS avg_order_value
FROM orders o
JOIN order_payments op ON op.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY 1
```

Save sebagai: `ds_kpi_metrics`

---

## FASE 3 — Membuat Chart Satu per Satu

### Step 3.1 — Chart 1: KPI Scorecard (3 Cards)

**Cara buat Chart 1A — Total Revenue (MoM):**

1. Menu atas → **Charts** → **+ Chart**
2. Pilih dataset: `ds_kpi_metrics`
3. Pilih chart type: **Big Number with Trendline**
4. Klik **Create new chart**

**Konfigurasi:**
| Setting | Value |
|---------|-------|
| Metric | `SUM(total_revenue)` |
| Time Column | `month` |
| Time Grain | `Month` |
| Time Range | `No filter` (biar filter dari dashboard) |
| Comparison Period Lag | `1` (untuk MoM) |
| Comparison Suffix | `vs last month` |
| Show Trendline | ✅ Centang |

5. Klik **Save** → beri nama `KPI - Total Revenue (MoM)`

**Ulangi untuk Chart 1B & 1C** dengan metric berbeda:
- Chart 1B: metric = `COUNT_DISTINCT(order_id)` → nama `KPI - Total Orders (MoM)`
- Chart 1C: metric = `AVG(avg_order_value)` → nama `KPI - Avg Order Value (MoM)`

---

### Step 3.2 — Chart 2: Monthly Revenue Trend

1. **+ Chart** → dataset: `ds_order_enriched` → type: **Line Chart**
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| X-axis | `order_month` |
| Metrics | `SUM(total_payment)` |
| Time Grain | `Month` |
| Time Range | `No filter` |

3. Di **Customize** tab:
   - Y-axis label: `Revenue (R$)`
   - Show data labels: ✅

4. Save → nama: `Monthly Revenue Trend`

---

### Step 3.3 — Chart 3: Top 10 Categories by Revenue

1. **+ Chart** → dataset: `ds_order_enriched` → type: **Bar Chart** (horizontal)
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| Dimensions (Y-axis) | `category` |
| Metrics (X-axis) | `SUM(total_payment)` |
| Row Limit | `10` |
| Sort By | `SUM(total_payment) DESC` |

3. Di **Customize**: Orient = Horizontal
4. Save → nama: `Top 10 Categories by Revenue`

---

### Step 3.4 — Chart 4: Order Status Distribution

1. **+ Chart** → dataset: pilih tabel langsung `orders` → type: **Pie Chart**
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| Dimensions | `order_status` |
| Metrics | `COUNT(*)` |
| Donut | ✅ Centang |
| Show Labels | ✅ |
| Show Legend | ✅ |

3. Save → nama: `Order Status Distribution`

---

### Step 3.5 — Chart 5: Revenue by Payment Method Over Time

1. **+ Chart** → dataset: `ds_order_enriched` → type: **Bar Chart**
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| X-axis | `order_month` |
| Metrics | `SUM(credit_card_payment)`, `SUM(boleto_payment)`, `SUM(other_payment)` |
| Stack | ✅ Centang (Stacked) |
| Time Grain | `Month` |

3. Di **Customize**: warna manual:
   - credit_card → biru
   - boleto → oranye
   - other → abu

4. Save → nama: `Revenue by Payment Method Over Time`

---

### Step 3.6 — Chart 6: Late Delivery Rate by Category

1. **+ Chart** → dataset: `ds_order_enriched` → type: **Bar Chart**
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| Dimensions | `category` |
| Metrics | Custom: `ROUND(SUM(CASE WHEN is_late THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(DISTINCT order_id), 0), 1)` |
| Metric Label | `late_rate_pct` |
| Filters | `delivered_at IS NOT NULL` |
| Row Limit | `15` |
| Sort By | `late_rate_pct DESC` |

3. Save → nama: `Late Delivery Rate by Category`

---

### Step 3.7 — Chart 7: Customer Volume by State

1. **+ Chart** → dataset: `ds_order_enriched` → type: **Bar Chart** (Horizontal)
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| Dimensions | `customer_state` |
| Metrics | `COUNT_DISTINCT(order_id)` |
| Row Limit | `10` |
| Sort By | `COUNT_DISTINCT(order_id) DESC` |

3. Save → nama: `Customer Volume by State`

---

### Step 3.8 — Chart 8: Customer Segment Distribution

1. **+ Chart** → dataset: `ds_customer_segments` → type: **Pie Chart**
2. Konfigurasi:

| Setting | Value |
|---------|-------|
| Dimensions | `segment` |
| Metrics | `COUNT(*)` |
| Donut | Opsional |
| Show Labels | ✅ |

3. Save → nama: `Customer Segment Distribution`

---

## FASE 4 — Merakit Dashboard

### Step 4.1 — Buat Dashboard Baru

1. Menu atas → **Dashboards** → **+ Dashboard**
2. Klik **Edit dashboard**
3. Beri nama: `E-Commerce Business Overview`

---

### Step 4.2 — Tambahkan Chart ke Dashboard

Di panel kanan (Charts panel), cari tiap chart dan drag ke canvas:

**Urutan penempatan:**

```
Row 1: [KPI Revenue MoM] [KPI Orders MoM] [KPI Avg Order Value MoM]
Row 2: [Monthly Revenue Trend (lebar 3x)] [Order Status Donut (lebar 1x)]
Row 3: [Top 10 Categories]               [Revenue by Payment Method]
Row 4: [Late Delivery Rate]  [Orders by State]  [Customer Segments]
```

**Cara drag:**
- Di panel kanan, klik tab **Charts**
- Cari nama chart → drag ke posisi yang diinginkan di canvas
- Resize dengan menarik sudut chart

---

### Step 4.3 — Tambahkan Dashboard Filters

1. Klik ikon **Filter** (🔽) di toolbar atas
2. Klik **+ Add/Edit Filters**
3. Tambahkan 4 filter berikut:

#### Filter 1: Date Range
| Setting | Value |
|---------|-------|
| Filter Type | Time Range |
| Dataset | `ds_order_enriched` |
| Time Column | `ordered_at` |
| Default Value | `2016-01-01 : 2018-09-01` |
| Scope (affects charts) | Semua chart |

#### Filter 2: Product Category
| Setting | Value |
|---------|-------|
| Filter Type | Value |
| Dataset | `ds_order_enriched` |
| Column | `category` |
| Filter Type | Multi-select |
| Default Value | All |
| Scope | Chart 3, 5, 6, 8 |

#### Filter 3: Order Status
| Setting | Value |
|---------|-------|
| Filter Type | Value |
| Dataset | `ds_order_enriched` |
| Column | `order_status` |
| Filter Type | Multi-select |
| Scope | Chart 1, 2, 3, 4, 5 |

#### Filter 4: Customer State
| Setting | Value |
|---------|-------|
| Filter Type | Value |
| Dataset | `ds_order_enriched` |
| Column | `customer_state` |
| Filter Type | Multi-select |
| Scope | Chart 1, 7, 8 |

4. Klik **Save** untuk simpan semua filter

---

### Step 4.4 — Aktifkan Cross-Filtering (Bonus ★)

1. Pastikan masih di mode **Edit Dashboard**
2. Klik ikon **⋯** (titik tiga) di toolbar → **Dashboard properties**
   - ATAU: Klik **Edit** → cari toggle **Enable cross-filtering**
3. Aktifkan toggle: **Enable cross-filtering** → ON
4. Klik **Apply**

> Sekarang klik pada bar/slice di satu chart akan otomatis filter chart lainnya.

---

### Step 4.5 — Simpan & Publish Dashboard

1. Klik tombol **Save** (kanan atas)
2. Klik **Publish** agar dashboard bisa dilihat tanpa mode edit

---

## FASE 5 — Verifikasi Final

Checklist sebelum submit:

- [ ] Dashboard bisa dibuka di `http://localhost:8088`
- [ ] Semua 8 chart tampil data (tidak kosong)
- [ ] 3 KPI Cards menampilkan MoM % change (↑/↓)
- [ ] Filter Date Range mengubah semua chart
- [ ] Filter Category mengubah chart yang relevan
- [ ] Cross-filtering: klik category bar → chart lain ikut filter
- [ ] `ds_order_enriched` join 7 tabel → terverifikasi di SQL Lab
- [ ] `ds_customer_segments` join 3 tabel → terverifikasi di SQL Lab

---

## 🔧 Troubleshooting Umum

| Masalah | Solusi |
|---------|--------|
| Chart error "No data" | Cek filter Date Range → pastikan range 2016-2018 |
| "Database driver not found" | `docker exec superset_app pip install psycopg2-binary` lalu restart |
| MoM% tidak muncul | Pastikan "Comparison Period Lag" = 1 dan Time Column sudah diset |
| Cross-filter tidak bekerja | Pastikan toggle Enable Cross-Filtering aktif di dashboard properties |
| Dataset tidak muncul di chart builder | Refresh halaman, lalu cek di Charts → pilih dataset ulang |
| Query error di SQL Lab | Pastikan schema = `public`, bukan schema lain |

---

## 📄 Referensi

- Dokumentasi desain per chart: `test2_explanation.html`
- Panduan menjalankan Superset: `README.md`
