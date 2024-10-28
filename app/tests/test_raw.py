import pytest
import pandas as pd
from unittest import mock
from datetime import datetime
import logging

# Import the functions from the raw.py script
from app.raw.raw import save_to_parquet, upload_to_gcs

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Mock data
mock_data = pd.DataFrame({
    'Date': pd.date_range(start='1/1/2020', periods=5),
    'AAPL': [300, 310, 320, 330, 340],
    'MSFT': [200, 210, 220, 230, 240]
})

bucket_name = 'ml-pipeline-ms'
today_date = datetime.today().strftime('%Y-%m-%d')
parquet_filename = 'raw_data.parquet'
parquet_blob_name = f'data/{today_date}/raw/raw_data.parquet'

# Update mock paths to include the correct package path
@pytest.fixture
def mock_storage_client():
    # Corrected path to match the import as used in the raw.py script
    with mock.patch('app.raw.raw.storage.Client') as mock_client:
        yield mock_client

@pytest.fixture
def mock_service_account():
    # Corrected path to match the import as used in the raw.py script
    with mock.patch('app.raw.raw.service_account.Credentials.from_service_account_file') as mock_creds:
        yield mock_creds

def test_save_to_parquet(mock_storage_client, mock_service_account):
    with mock.patch('app.raw.raw.pd.DataFrame.to_parquet') as mock_to_parquet:
        save_to_parquet(mock_data, bucket_name, parquet_filename, parquet_blob_name)
        mock_to_parquet.assert_called_once_with(parquet_filename, index=False)
        mock_storage_client.assert_called_once()
        mock_service_account.assert_called_once()

def test_upload_to_gcs(mock_storage_client, mock_service_account):
    upload_to_gcs(bucket_name, parquet_filename, parquet_blob_name)
    mock_storage_client.assert_called_once()
    mock_service_account.assert_called_once()
    mock_storage_client().bucket().blob().upload_from_filename.assert_called_once_with(parquet_filename)
