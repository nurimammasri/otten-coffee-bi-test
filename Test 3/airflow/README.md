# Airflow DAG for dbt with Astronomer Cosmos

Direktori ini berisi DAG (Directed Acyclic Graph) Apache Airflow yang digunakan untuk mengorkestrasi transformasi data dbt secara native menggunakan **Astronomer Cosmos**.

## Kenapa menggunakan Astronomer Cosmos?
Berbeda dengan `BashOperator` biasa yang mengeksekusi `dbt run` sebagai satu *black-box task*, Cosmos secara otomatis membaca file `dbt_project.yml` dan merepresentasikan setiap model dbt (staging, intermediate, mart) sebagai **task individual** di dalam Airflow UI. 

Hal ini memberikan:
- **Visibilitas penuh:** Kita bisa melihat lineage dbt (Staging -> Intermediate -> Mart) langsung di UI Airflow.
- **Granularity:** Jika model `mart_monthly_revenue` gagal, kita hanya perlu merestart model itu saja dari UI Airflow, tanpa menjalankan ulang `staging`.
- **Integrasi native:** Testing (`dbt test`) otomatis menjadi task di Airflow.

---

## Tahapan Menjalankan DAG Ini di Lokal (Docker)

Jika kamu ingin menjalankan dan melihat DAG ini di komputermu sendiri, kamu bisa menggunakan Docker dengan Astro CLI (cara termudah menjalankan Airflow lokal).

### Prasyarat
1. Telah menginstal [Docker Desktop](https://www.docker.com/products/docker-desktop).
2. Telah menginstal [Astro CLI](https://docs.astronomer.io/astro/cli/install-cli).

### Langkah-langkah Eksekusi

**1. Inisialisasi Project Airflow Lokal**
Buka terminal dan buat folder baru untuk environment Airflow, lalu jalankan inisialisasi:
```bash
mkdir my-astro-project
cd my-astro-project
astro dev init
```

**2. Masukkan File DAG dan dbt Project**
- Copy file `otten_dbt_dag.py` yang ada di folder ini ke dalam folder `dags/` di `my-astro-project`.
- Masukkan seluruh folder dbt project kamu ke dalam folder `dags/` dengan nama folder `dbt_pipeline`. 

**3. Install Dependencies (Astronomer Cosmos)**
Buka file `requirements.txt` yang ada di dalam `my-astro-project`, dan tambahkan baris berikut:
```text
astronomer-cosmos
dbt-postgres
```

**4. Jalankan Airflow**
Di dalam folder `my-astro-project`, jalankan perintah ini di terminal:
```bash
astro dev start
```
*Docker akan mendownload image Airflow dan mengaktifkan web server.*

**5. Akses Airflow Web UI**
- Buka browser dan pergi ke `http://localhost:8080`.
- Login menggunakan kredensial default (Username: `admin`, Password: `admin`).

**6. Konfigurasi Koneksi Database**
- Di Airflow UI, pilih menu **Admin** -> **Connections**.
- Buat koneksi baru:
  - **Connection Id**: `postgres_default`
  - **Connection Type**: `Postgres`
  - **Host, Schema, Login, Password, Port**: *(Isi dengan kredensial database PostgreSQL kamu tempat dbt berjalan)*.

**7. Trigger DAG**
- Kembali ke halaman utama (DAGs).
- Cari DAG bernama `otten_coffee_dbt_cosmos_pipeline`.
- Nyalakan *toggle switch* (Unpause) dan klik tombol **Play (Trigger DAG)**.
- Klik nama DAG-nya dan pergi ke tab **Graph** untuk melihat setiap tahapan dbt tervisualisasi dan berjalan secara berurutan!
