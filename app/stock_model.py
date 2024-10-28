import yfinance as yf
import pandas as pd
from google.cloud import storage
from google.auth import default
import os
from datetime import datetime
from google.oauth2 import service_account
from google.cloud import storage

bucket_name = 'ml-pipeline-ms'

# Get today's date
today_date = datetime.today().strftime('%Y-%m-%d')

# Extract historical data for well-known IT and car companies
tickers = ['AAPL', 'MSFT', 'GOOGL', 'TSLA', 'GM', 'META']
data = yf.download(tickers, start='2000-01-01', end=today_date)
data.reset_index(inplace=True)
print("Data extraction complete.")

# Save the raw data to Parquet file
def save_to_parquet(df, bucket_name, filename, destination_blob_name):
    try:
        # Save DataFrame as a Parquet file
        df.to_parquet(filename, index=False)
        print(f"Data saved to {filename} as Parquet format.")
        
        # Upload to Google Cloud Storage
        upload_to_gcs(bucket_name, filename, destination_blob_name)
        print(f"Parquet file {filename} uploaded successfully to GCS bucket.")
    except Exception as e:
        print(f"Error saving and uploading Parquet file: {e}")

# Function to upload files to Google Cloud Storage
def upload_to_gcs(bucket_name, source_file_name, destination_blob_name):
    print(f"Uploading {source_file_name} to {bucket_name}/{destination_blob_name}...")

    try:
        
        # Load credentials from the mounted secret
        credentials = service_account.Credentials.from_service_account_file('/var/secrets/google/key.json')
        storage_client = storage.Client(credentials=credentials)

        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_file_name)
        print(f"Upload of {source_file_name} complete.")
    except Exception as e:
        print(f"Error uploading file: {e}")
        # Add more specific error handling if needed


# Save the raw data as Parquet and upload to GCS folder "output"
parquet_filename = 'raw_data.parquet'
parquet_blob_name = 'output/raw_data.parquet'  # Updated to include "output/" prefix
save_to_parquet(data, bucket_name, parquet_filename, parquet_blob_name)


print("Script completed successfully.")