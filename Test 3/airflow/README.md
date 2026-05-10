# Airflow DAG for dbt with Astronomer Cosmos (Docker Compose)

Direktori ini berisi DAG (Directed Acyclic Graph) Apache Airflow yang digunakan untuk mengorkestrasi transformasi data dbt secara native menggunakan **Astronomer Cosmos**. Setup ini menggunakan instalasi **Official Apache Airflow via Docker Compose**.

## Tahapan Menjalankan DAG Ini di Lokal (Docker Compose)

### Prasyarat
1. Telah menginstal [Docker Desktop](https://www.docker.com/products/docker-desktop).

### Langkah-langkah Eksekusi

**1. Masuk ke Folder Airflow**
Buka terminal dan navigasi ke direktori ini:
```bash
cd "Test 3/airflow"
```

**2. Persiapkan Folder Pendukung**
Jalankan perintah berikut (jika kamu menggunakan Linux/Mac/WSL) untuk memastikan folder-folder ini ada dan punya izin yang tepat:
```bash
mkdir -p ./dags ./logs ./plugins ./config
echo -e "AIRFLOW_UID=$(id -u)" > .env
```
*(Catatan: File `.env` dengan `AIRFLOW_UID=50000` sudah saya buatkan secara default untuk pengguna Windows/Mac).*

**3. Letakkan dbt Project Kamu**
Copy/masukkan seluruh folder `dbt` project milikmu ke dalam direktori `dags/` (misal dengan nama `dbt_pipeline`). Hal ini diperlukan agar container Airflow dapat mengakses konfigurasi `dbt_project.yml` milikmu.

**4. Build Image Docker (Sangat Penting)**
Karena kita menggunakan library tambahan (`astronomer-cosmos` dan `dbt-postgres`), kita harus mem-build custom Docker image berdasarkan `Dockerfile` yang telah disediakan, jangan memakai image polosnya:
```bash
docker compose build
```

**5. Inisialisasi Database Airflow**
Jalankan perintah ini SATU KALI SAJA di awal untuk membuat tabel-tabel metadata Airflow di Postgres:
```bash
docker compose up airflow-init
```
Tunggu hingga proses selesai dan muncul tulisan `airflow-init_1 exited with code 0`.

**6. Jalankan Airflow Secara Penuh**
Nyalakan seluruh kontainer Airflow (Webserver, Scheduler, Celery Workers, dll) di latar belakang:
```bash
docker compose up -d
```

**7. Akses Airflow Web UI**
- Buka browser dan pergi ke `http://localhost:8080`.
- Login menggunakan kredensial default:
  - **Username**: `airflow`
  - **Password**: `airflow`

**8. Konfigurasi Koneksi Database**
- Di Airflow UI, pilih menu **Admin** -> **Connections**.
- Buat koneksi baru:
  - **Connection Id**: `postgres_default`
  - **Connection Type**: `Postgres`
  - **Host, Schema, Login, Password, Port**: *(Isi dengan kredensial database PostgreSQL kamu tempat dbt berjalan)*.

**9. Trigger DAG**
- Kembali ke halaman utama (DAGs).
- Cari DAG bernama `otten_coffee_dbt_cosmos_pipeline`.
- Nyalakan *toggle switch* (Unpause) dan klik tombol **Play (Trigger DAG)**.

**10. Mematikan Airflow**
Jika sudah selesai mengetes, matikan server dengan perintah:
```bash
docker compose down
```
