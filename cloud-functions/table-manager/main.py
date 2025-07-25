import json
import os
import base64
import logging
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
from google.cloud import bigquery
from google.cloud.exceptions import NotFound, Conflict
from table_schemas import get_table_schema

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="BigQuery Table Manager")

# Initialize BigQuery client
try:
    client = bigquery.Client()
    logger.info("BigQuery client initialized successfully.")
except Exception as e:
    logger.error(f"Failed to initialize BigQuery client: {e}")
    client = None

# Pydantic models for request validation
class PubSubMessage(BaseModel):
    data: str
    attributes: dict | None = None

class PubSubRequest(BaseModel):
    message: PubSubMessage
    subscription: str

@app.on_event("startup")
async def startup_event():
    if client is None:
        logger.error("BigQuery client is not available. The function will not work.")
    else:
        logger.info("Service is ready to process requests.")

@app.get("/health")
async def health_check():
    """Health check endpoint for Cloud Run"""
    return {"status": "healthy", "bigquery_client_initialized": client is not None}

@app.post("/")
async def handle_pubsub_message(request: Request):
    """
    Main endpoint to receive Pub/Sub messages via HTTP POST from Eventarc.
    """
    # Verify the request is from Pub/Sub
    if not request.headers.get("ce-specversion"):
        raise HTTPException(status_code=400, detail="Not a valid CloudEvent")

    try:
        body = await request.json()
        envelope = PubSubRequest(**body)

        # Decode the Pub/Sub message data
        message_data = base64.b64decode(envelope.message.data).decode('utf-8')
        event_data = json.loads(message_data)

        logger.info(f"Processing event: {event_data}")
        process_event(event_data)

        return {"status": "success"}, 200

    except json.JSONDecodeError as e:
        logger.error(f"Failed to decode JSON from Pub/Sub message: {e}")
        raise HTTPException(status_code=400, detail="Invalid JSON in Pub/Sub message")
    except Exception as e:
        logger.error(f"Error processing event: {e}")
        # Return a 200-level status to prevent Pub/Sub from retrying a bad message
        return {"status": "error", "detail": str(e)}, 200

def process_event(event_data: dict):
    """
    Core logic to process the event data and create a BigQuery table.
    """
    if client is None:
        logger.error("BigQuery client not initialized. Cannot process event.")
        raise RuntimeError("BigQuery client is not available")

    # Extract event type and determine table name
    event_type = event_data.get('event_type')
    if not event_type:
        logger.warning("No event_type found in message")
        return

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
    environment = os.environ.get('ENVIRONMENT', 'dev')
    dataset_id = f"{environment}_events_dataset"

    if not project_id:
        raise ValueError("PROJECT_ID environment variable is required")

    # Create table if it doesn't exist
    table_id = f"{project_id}.{dataset_id}.{table_name}"

    if not table_exists(table_id):
        create_bigquery_table(project_id, dataset_id, table_name, environment)
    else:
        logger.info(f"Table {table_id} already exists.")

def table_exists(table_id: str) -> bool:
    """Check if a BigQuery table exists."""
    try:
        client.get_table(table_id)
        return True
    except NotFound:
        return False

def create_bigquery_table(project_id: str, dataset_id: str, table_name: str, environment: str):
    """Create a BigQuery table with the appropriate schema."""
    try:
        schema = get_table_schema(table_name)
        table_ref = client.dataset(dataset_id, project=project_id).table(table_name)
        table = bigquery.Table(table_ref, schema=schema)

        # Add partitioning and clustering
        if "event_date" in [field.name for field in schema]:
             table.time_partitioning = bigquery.TimePartitioning(
                type_=bigquery.TimePartitioningType.DAY,
                field="event_date"
             )

        if table_name == 'orders':
            table.clustering_fields = ["customer_id", "status"]
        elif table_name == 'inventory':
            table.clustering_fields = ["product_id", "warehouse_id"]
        elif table_name == 'user_activity':
            table.clustering_fields = ["user_id", "activity_type"]

        table.labels = {
            'environment': environment,
            'managed_by': 'cloud_function',
            'table_type': table_name
        }
        table.description = f"Auto-created table for {table_name} events in {environment}."

        client.create_table(table)
        logger.info(f"Successfully created table {table.table_id}")

    except Conflict:
        logger.info(f"Table {table_name} already exists (race condition).")
    except Exception as e:
        logger.error(f"Error creating table {table_name}: {e}")
        raise

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port) 