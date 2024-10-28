import pytest
import pandas as pd
from unittest import mock
from datetime import datetime
import logging

# Import the functions from the etl.py script
from app.etl.etl import download_from_gcs, upload_to_gcs

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

bucket_name = 'ml-pipeline-ms'
today_date = datetime.today().strftime('%Y-%m-%d')
parquet_blob_name = f'data/{today_date}/raw/raw_data.parquet'
downloaded_parquet_filename = 'downloaded_raw_data.parquet'
transformed_parquet_filename = 'transformed_data.parquet'
transformed_blob_name = f'data/{today_date}/transformed/transformed_data.parquet'

# Update mock paths to include the correct package path
@pytest.fixture
def mock_storage_client():
    # Corrected path to match the import as used in the etl.py script
    with mock.patch('app.etl.etl.storage.Client') as mock_client:
        yield mock_client

@pytest.fixture
def mock_service_account():
    # Corrected path to match the import as used in the etl.py script
    with mock.patch('app.etl.etl.service_account.Credentials.from_service_account_file') as mock_creds:
        yield mock_creds

def test_download_from_gcs(mock_storage_client, mock_service_account):
    with mock.patch('app.etl.etl.logger') as mock_logger:
        download_from_gcs(bucket_name, parquet_blob_name, downloaded_parquet_filename)
        
        # Ensure the storage client and service account credentials were used
        mock_storage_client.assert_called_once()
        mock_service_account.assert_called_once()
        
        # Ensure that GCS blob was properly downloaded
        mock_storage_client().bucket().blob().download_to_filename.assert_called_once_with(downloaded_parquet_filename)

        # Check if logger statements were called
        mock_logger.info.assert_any_call(f"Downloading {parquet_blob_name} from {bucket_name} to {downloaded_parquet_filename}...")
        mock_logger.info.assert_any_call(f"Download of {parquet_blob_name} complete.")

def test_upload_to_gcs(mock_storage_client, mock_service_account):
    with mock.patch('app.etl.etl.logger') as mock_logger:
        upload_to_gcs(bucket_name, transformed_parquet_filename, transformed_blob_name)
        
        # Ensure the storage client and service account credentials were used
        mock_storage_client.assert_called_once()
        mock_service_account.assert_called_once()
        
        # Ensure that GCS blob was properly uploaded
        mock_storage_client().bucket().blob().upload_from_filename.assert_called_once_with(transformed_parquet_filename)

        # Check if logger statements were called
        mock_logger.info.assert_any_call(f"Uploading {transformed_parquet_filename} to {bucket_name}/{transformed_blob_name}...")
        mock_logger.info.assert_any_call(f"Upload of {transformed_parquet_filename} complete.")
