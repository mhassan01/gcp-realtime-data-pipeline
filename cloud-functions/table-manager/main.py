import json
import os
import base64
import logging
from google.cloud import bigquery
from google.cloud.exceptions import NotFound, Conflict
from table_schemas import get_table_schema

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize BigQuery client
client = bigquery.Client()

def create_table(cloud_event):
    """
    Cloud Function triggered by Pub/Sub messages to create BigQuery tables dynamically.
    
    Args:
        cloud_event: CloudEvent containing the Pub/Sub message
    """
    try:
        # Decode the Pub/Sub message
        pubsub_message = base64.b64decode(cloud_event.data["message"]["data"]).decode('utf-8')
        event_data = json.loads(pubsub_message)
        
        logger.info(f"Processing event: {event_data}")
        
        # Extract event type and determine table name
        event_type = event_data.get('event_type')
        if not event_type:
            logger.warning("No event_type found in message")
            return
        
        # Map event types to table names - simplified for assessment
        table_mapping = {
            'order': 'orders',
            'inventory': 'inventory', 
            'user_activity': 'user_activity'
        }
        
        table_name = table_mapping.get(event_type)
        if not table_name:
            logger.info(f"No table mapping found for event_type: {event_type}")
            return
        
        # Get environment variables
        project_id = os.environ.get('PROJECT_ID')
        dataset_id = os.environ.get('DATASET_ID')
        environment = os.environ.get('ENVIRONMENT', 'dev')
        
        if not project_id or not dataset_id:
            raise ValueError("PROJECT_ID and DATASET_ID environment variables are required")
        
        # Create table if it doesn't exist
        table_id = f"{project_id}.{dataset_id}.{table_name}"
        
        if not table_exists(table_id):
            create_bigquery_table(project_id, dataset_id, table_name, environment)
            logger.info(f"Created table: {table_id}")
        else:
            logger.info(f"Table already exists: {table_id}")
            
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        raise

def table_exists(table_id):
    """
    Check if a BigQuery table exists.
    
    Args:
        table_id: Full table ID (project.dataset.table)
        
    Returns:
        bool: True if table exists, False otherwise
    """
    try:
        client.get_table(table_id)
        return True
    except NotFound:
        return False

def create_bigquery_table(project_id, dataset_id, table_name, environment):
    """
    Create a BigQuery table with the appropriate schema.
    
    Args:
        project_id: GCP project ID
        dataset_id: BigQuery dataset ID
        table_name: Name of the table to create
        environment: Environment (dev, staging, prod)
    """
    try:
        # Get the schema for this table type
        schema = get_table_schema(table_name)
        
        # Create table reference
        table_ref = client.dataset(dataset_id, project=project_id).table(table_name)
        
        # Create table object
        table = bigquery.Table(table_ref, schema=schema)
        
        # Set table properties for all tables
        # Add time partitioning by event_date
        table.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="event_date"
        )
        
        # Add clustering based on table type for query optimization
        if table_name == 'orders':
            table.clustering_fields = ["customer_id", "status"]
        elif table_name == 'inventory':
            table.clustering_fields = ["product_id", "warehouse_id"]
        elif table_name == 'user_activity':
            table.clustering_fields = ["user_id", "activity_type"]
        
        # Set table expiration to use dataset default (90 days)
        table.expires = None
        
        # Set labels for management
        table.labels = {
            'environment': environment,
            'managed_by': 'cloud_function',
            'table_type': table_name,
            'auto_created': 'true',
            'assessment': 'data_engineering'
        }
        
        # Set description
        table.description = f"Auto-created table for {table_name} events in {environment} environment (Data Engineering Assessment)"
        
        # Create the table
        table = client.create_table(table)
        logger.info(f"Successfully created table {table.table_id} with partitioning and clustering")
        
    except Conflict:
        logger.info(f"Table {table_name} already exists")
    except Exception as e:
        logger.error(f"Error creating table {table_name}: {str(e)}")
        raise 