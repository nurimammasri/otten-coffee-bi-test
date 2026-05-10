import pandas as pd
from sqlalchemy import create_engine, text
import glob
import os

def get_date_cols(table_name):
    """Return list of date columns per table to parse as datetime during import."""
    date_cols_map = {
        "orders": [
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "order_reviews": [
            "review_creation_date",
            "review_answer_timestamp",
        ],
    }
    return date_cols_map.get(table_name, [])

def main():
    print("\n=======================================================")
    print("=== OTTEN COFFEE: CSV to PostgreSQL Auto-Importer ===")
    print("=======================================================\n")

    db_password = "nurimammasri"

    try:
        engine = create_engine(f"postgresql+psycopg2://postgres:{db_password}@localhost:5432/postgres")
        engine.connect()
        print("[OK] Koneksi ke PostgreSQL berhasil!\n")
    except Exception as e:
        print(f"[X] Gagal terhubung. Error: {e}")
        return

    csv_files = glob.glob("*.csv")
    if not csv_files:
        print("Tidak ada file CSV yang ditemukan.")
        return

    print(f"Ditemukan {len(csv_files)} file CSV. Memulai proses import...\n")

    for file in csv_files:
        table_name = os.path.splitext(file)[0]
        date_cols = get_date_cols(table_name)
        print(f"-> Sedang membaca {file} ...")

        try:
            df = pd.read_csv(file, parse_dates=date_cols)
            print(f"   Mengimpor {len(df):,} baris ke tabel '{table_name}'...")
            # DROP CASCADE agar view dbt yang menempel tidak memblokir
            with engine.begin() as conn:
                conn.execute(text(f'DROP TABLE IF EXISTS "{table_name}" CASCADE'))
            df.to_sql(table_name, engine, if_exists='replace', index=False, chunksize=10000)
            print(f"   [OK] Selesai: Tabel '{table_name}' berhasil dibuat.\n")
        except Exception as e:
            print(f"   [X] Gagal memproses {file}. Error: {e}\n")

    print("=======================================================")
    print("SEMUA DATA BERHASIL DIIMPOR KE POSTGRESQL LOKAL!")
    print("=======================================================")
    print("Sekarang kamu bisa kembali ke Airflow dan jalankan (Trigger) DAG-nya!")

if __name__ == "__main__":
    main()
