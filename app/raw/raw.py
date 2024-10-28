import yfinance as yf
import pandas as pd
from google.cloud import storage
from google.oauth2 import service_account
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

bucket_name = 'ml-pipeline-ms'
today_date = datetime.today().strftime('%Y-%m-%d')
parquet_filename = 'raw_data.parquet'
parquet_blob_name = f'data/{today_date}/raw/raw_data.parquet'

# Extract historical data for well-known IT and car companies
tickers = ['AAPL', 'MSFT', 'GOOGL', 'TSLA', 'GM', 'META']
data = yf.download(tickers, start='2020-01-01', end=today_date)
data.reset_index(inplace=True)
logger.info("Data extraction complete.")

def save_to_parquet(df: pd.DataFrame, bucket_name: str, filename: str, destination_blob_name: str) -> None:
    """
    Save a DataFrame as a Parquet file and upload it to Google Cloud Storage.

    Args:
        df (pd.DataFrame): The DataFrame to save.
        bucket_name (str): The name of the GCS bucket.
        filename (str): The local filename to save the Parquet file.
        destination_blob_name (str): The name of the blob in the GCS bucket.

    Returns:
        None
    """
    try:
        # Save DataFrame as a Parquet file
        df.to_parquet(filename, index=False)
        logger.info(f"Data saved to {filename} as Parquet format.")
        
        # Upload to Google Cloud Storage
        upload_to_gcs(bucket_name, filename, destination_blob_name)
        logger.info(f"Parquet file {filename} uploaded successfully to GCS bucket.")
    except Exception as e:
        logger.error(f"Error saving and uploading Parquet file: {e}")

def upload_to_gcs(bucket_name: str, source_file_name: str, destination_blob_name: str) -> None:
    """
    Upload a file to Google Cloud Storage.

    Args:
        bucket_name (str): The name of the GCS bucket.
        source_file_name (str): The local filename of the file to upload.
        destination_blob_name (str): The name of the blob in the GCS bucket.

    Returns:
        None
    """
    logger.info(f"Uploading {source_file_name} to {bucket_name}/{destination_blob_name}...")
    try:
        # Load credentials from the mounted secret
        credentials = service_account.Credentials.from_service_account_file('/var/secrets/google/key.json')
        storage_client = storage.Client(credentials=credentials)

        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_file_name)
        logger.info(f"Upload of {source_file_name} complete.")
    except Exception as e:
        logger.error(f"Error uploading file: {e}")

# Save the raw data as Parquet and upload to GCS folder "output"
save_to_parquet(data, bucket_name, parquet_filename, parquet_blob_name)

logger.info("Script completed successfully.")