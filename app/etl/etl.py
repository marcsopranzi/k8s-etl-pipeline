import pandas as pd
from google.cloud import storage
from google.oauth2 import service_account
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

today_date = datetime.today().strftime('%Y-%m-%d')
bucket_name = 'ml-pipeline-ms'
parquet_blob_name = f'data/{today_date}/raw/raw_data.parquet'
downloaded_parquet_filename = 'downloaded_raw_data.parquet'

transformed_parquet_filename = 'transformed_data.parquet'
transformed_blob_name = f'data/{today_date}/transformed/transformed_data.parquet'

def download_from_gcs(bucket_name: str, source_blob_name: str, destination_file_name: str) -> None:
    logger.info(f"Downloading {source_blob_name} from {bucket_name} to {destination_file_name}...")
    try:
        credentials = service_account.Credentials.from_service_account_file('/var/secrets/google/key.json')
        storage_client = storage.Client(credentials=credentials)

        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(source_blob_name)
        blob.download_to_filename(destination_file_name)
        logger.info(f"Download of {source_blob_name} complete.")
    except Exception as e:
        logger.error(f"Error downloading file: {e}")

def upload_to_gcs(bucket_name: str, source_file_name: str, destination_blob_name: str) -> None:
    logger.info(f"Uploading {source_file_name} to {bucket_name}/{destination_blob_name}...")
    try:
        credentials = service_account.Credentials.from_service_account_file('/var/secrets/google/key.json')
        storage_client = storage.Client(credentials=credentials)

        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)
        blob.upload_from_filename(source_file_name)
        logger.info(f"Upload of {source_file_name} complete.")
    except Exception as e:
        logger.error(f"Error uploading file: {e}")

def main():
    # Download the raw data from GCS
    download_from_gcs(bucket_name, parquet_blob_name, downloaded_parquet_filename)

    # Load the Parquet file into a DataFrame
    data = pd.read_parquet(downloaded_parquet_filename)
    logger.info("Data loaded from Parquet file.")

    # Print the columns of the DataFrame to verify the structure
    logger.info(f"Columns in the DataFrame: {data.columns}")

    # Flatten the MultiIndex columns
    data.columns = ['_'.join(col).strip() for col in data.columns.values]

    # Print the flattened columns
    logger.info(f"Flattened columns in the DataFrame: {data.columns}")

    # Calculate daily returns for each stock
    tickers = ['AAPL', 'MSFT']
    for ticker in tickers:
        close_col = f'Close_{ticker}'
        high_col = f'High_{ticker}'
        low_col = f'Low_{ticker}'
        
        if close_col in data.columns:
            data[f'{ticker}_Close_Pct_Change'] = data[close_col].pct_change() * 100
        else:
            logger.warning(f"'{close_col}' column not found for {ticker}")
        
        if high_col in data.columns and low_col in data.columns:
            data[f'{ticker}_High_Low_Diff'] = data[high_col] - data[low_col]
        else:
            logger.warning(f"'{high_col}' or '{low_col}' column not found for {ticker}")

    # Calculate average closing price of all stocks on each day
    close_columns = [f'Close_{ticker}' for ticker in tickers if f'Close_{ticker}' in data.columns]
    if close_columns:
        data['Average_Closing_Price'] = data[close_columns].mean(axis=1)
    else:
        logger.warning("No closing price columns found for calculating average.")

    # Save transformed data locally as Parquet
    transformed_data = data
    transformed_data.to_parquet(transformed_parquet_filename, index=False)
    logger.info(f"Transformed data saved as {transformed_parquet_filename}.")

    # Upload the transformed data to GCS with a prefix of data and today's date
    upload_to_gcs(bucket_name, transformed_parquet_filename, transformed_blob_name)

if __name__ == "__main__":
    main()
