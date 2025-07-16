from google.cloud import bigquery

def get_table_schema(table_name):
    """
    Get the BigQuery schema for a given table name.
    
    Args:
        table_name: Name of the table (orders, inventory, user_activity)
        
    Returns:
        List of SchemaField objects
    """
    schemas = {
        'orders': get_orders_schema(),
        'inventory': get_inventory_schema(), 
        'user_activity': get_user_activity_schema()
    }
    
    schema = schemas.get(table_name)
    if not schema:
        raise ValueError(f"No schema defined for table: {table_name}")
    
    return schema

def get_orders_schema():
    """Schema for orders table - matching assessment requirements"""
    return [
        bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("order_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("customer_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("order_date", "TIMESTAMP", mode="REQUIRED"),
        bigquery.SchemaField("status", "STRING", mode="REQUIRED"),  # pending, processing, shipped, delivered
        bigquery.SchemaField("items", "RECORD", mode="REPEATED", fields=[
            bigquery.SchemaField("product_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("product_name", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("quantity", "INTEGER", mode="REQUIRED"),
            bigquery.SchemaField("price", "FLOAT", mode="REQUIRED")
        ]),
        bigquery.SchemaField("shipping_address", "RECORD", mode="REQUIRED", fields=[
            bigquery.SchemaField("street", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("city", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("country", "STRING", mode="REQUIRED")
        ]),
        bigquery.SchemaField("total_amount", "FLOAT", mode="REQUIRED"),
        # Additional fields for processing
        bigquery.SchemaField("processed_timestamp", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("event_date", "DATE", mode="NULLABLE")
    ]

def get_inventory_schema():
    """Schema for inventory table - matching assessment requirements"""
    return [
        bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("inventory_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("product_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("warehouse_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("quantity_change", "INTEGER", mode="REQUIRED"),  # -100 to 100
        bigquery.SchemaField("reason", "STRING", mode="REQUIRED"),  # restock, sale, return, damage
        bigquery.SchemaField("timestamp", "TIMESTAMP", mode="REQUIRED"),
        # Additional fields for processing
        bigquery.SchemaField("processed_timestamp", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("event_date", "DATE", mode="NULLABLE")
    ]

def get_user_activity_schema():
    """Schema for user_activity table - matching assessment requirements"""
    return [
        bigquery.SchemaField("event_type", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("user_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("activity_type", "STRING", mode="REQUIRED"),  # login, logout, view_product, add_to_cart, remove_from_cart
        bigquery.SchemaField("ip_address", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("user_agent", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("timestamp", "TIMESTAMP", mode="REQUIRED"),
        bigquery.SchemaField("metadata", "RECORD", mode="REQUIRED", fields=[
            bigquery.SchemaField("session_id", "STRING", mode="REQUIRED"),
            bigquery.SchemaField("platform", "STRING", mode="REQUIRED")  # web, mobile, tablet
        ]),
        # Additional fields for processing
        bigquery.SchemaField("processed_timestamp", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("event_date", "DATE", mode="NULLABLE")
    ] 