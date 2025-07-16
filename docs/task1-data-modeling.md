# Task 1: Data Modeling and Architecture

## Overview

This document outlines the BigQuery data model designed for the real-time data pipeline that processes three types of events: orders, inventory, and user activity. The design focuses on performance, scalability, and analytical capabilities.

## Data Model Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Pub/Sub       │    │   Dataflow       │    │   BigQuery      │
│   Topic         │───▶│   Pipeline       │───▶│   Tables        │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Cloud Storage │
                       │   (Raw Files)   │
                       └─────────────────┘
```

### BigQuery Dataset Structure

```
dev_events_dataset/
├── orders/                 # Order events table
├── inventory/             # Inventory changes table
└── user_activity/         # User activity events table
```

## Table Schemas

### 1. Orders Table

**Purpose**: Store order lifecycle events (creation, updates, status changes)

**Schema Design**:
- **Partitioning**: Daily partitioning by `event_date` for cost optimization
- **Clustering**: By `customer_id`, `status` for fast customer queries and status analysis
- **Nested Records**: Items array for order line items, shipping address record

### 2. Inventory Table

**Purpose**: Track inventory changes across warehouses

**Schema Design**:
- **Partitioning**: Daily partitioning by `event_date`
- **Clustering**: By `product_id`, `warehouse_id` for product and location analysis
- **Change Tracking**: Quantity changes with reason codes

### 3. User Activity Table

**Purpose**: Capture user interactions and behavior

**Schema Design**:
- **Partitioning**: Daily partitioning by `event_date`
- **Clustering**: By `user_id`, `activity_type` for user journey analysis
- **Session Tracking**: Metadata includes session and platform information

## DDL Statements

### Dataset Creation

```sql
-- Create main dataset
CREATE SCHEMA IF NOT EXISTS `fabled-web-172810.dev_events_dataset`
OPTIONS (
  description = "Real-time events dataset for data engineering assessment",
  location = "us-central1",
  default_table_expiration_ms = 7776000000  -- 90 days
);
```

### Orders Table

```sql
CREATE TABLE IF NOT EXISTS `fabled-web-172810.dev_events_dataset.orders` (
  event_type STRING NOT NULL,
  order_id STRING NOT NULL,
  customer_id STRING NOT NULL,
  order_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,  -- pending, processing, shipped, delivered
  items ARRAY<STRUCT<
    product_id STRING NOT NULL,
    product_name STRING NOT NULL,
    quantity INT64 NOT NULL,
    price FLOAT64 NOT NULL
  >> NOT NULL,
  shipping_address STRUCT<
    street STRING NOT NULL,
    city STRING NOT NULL,
    country STRING NOT NULL
  > NOT NULL,
  total_amount FLOAT64 NOT NULL,
  processed_timestamp TIMESTAMP,
  event_date DATE
)
PARTITION BY event_date
CLUSTER BY customer_id, status
OPTIONS (
  description = "Order events table with daily partitioning and customer clustering",
  labels = [
    ("environment", "dev"),
    ("managed_by", "cloud_function"),
    ("table_type", "orders"),
    ("assessment", "data_engineering")
  ]
);
```

### Inventory Table

```sql
CREATE TABLE IF NOT EXISTS `fabled-web-172810.dev_events_dataset.inventory` (
  event_type STRING NOT NULL,
  inventory_id STRING NOT NULL,
  product_id STRING NOT NULL,
  warehouse_id STRING NOT NULL,
  quantity_change INT64 NOT NULL,  -- Range: -100 to 100
  reason STRING NOT NULL,  -- restock, sale, return, damage
  timestamp TIMESTAMP NOT NULL,
  processed_timestamp TIMESTAMP,
  event_date DATE
)
PARTITION BY event_date
CLUSTER BY product_id, warehouse_id
OPTIONS (
  description = "Inventory changes table with product and warehouse clustering",
  labels = [
    ("environment", "dev"),
    ("managed_by", "cloud_function"),
    ("table_type", "inventory"),
    ("assessment", "data_engineering")
  ]
);
```

### User Activity Table

```sql
CREATE TABLE IF NOT EXISTS `fabled-web-172810.dev_events_dataset.user_activity` (
  event_type STRING NOT NULL,
  user_id STRING NOT NULL,
  activity_type STRING NOT NULL,  -- login, logout, view_product, add_to_cart, remove_from_cart
  ip_address STRING NOT NULL,
  user_agent STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  metadata STRUCT<
    session_id STRING NOT NULL,
    platform STRING NOT NULL  -- web, mobile, tablet
  > NOT NULL,
  processed_timestamp TIMESTAMP,
  event_date DATE
)
PARTITION BY event_date
CLUSTER BY user_id, activity_type
OPTIONS (
  description = "User activity events with session and platform tracking",
  labels = [
    ("environment", "dev"),
    ("managed_by", "cloud_function"),
    ("table_type", "user_activity"),
    ("assessment", "data_engineering")
  ]
);
```

## Design Decisions & Rationale

### 1. Partitioning Strategy

**Decision**: Daily partitioning by `event_date` for all tables

**Rationale**:
- **Cost Optimization**: Queries typically filter by recent dates, reducing scanned data
- **Performance**: Partition pruning eliminates unnecessary data scanning
- **Maintenance**: Automatic partition management with lifecycle policies
- **Time Travel**: Easy to query historical data by date ranges

**Example Query Benefit**:
```sql
-- This query only scans 1 day of data instead of entire table
SELECT COUNT(*) FROM orders 
WHERE event_date = '2024-01-15'
```

### 2. Clustering Strategy

**Orders Table**: `customer_id`, `status`
- Most queries filter by customer or analyze order status distribution
- Enables fast customer journey analysis and status reporting

**Inventory Table**: `product_id`, `warehouse_id`
- Inventory queries typically focus on specific products or warehouses
- Supports real-time stock level monitoring and warehouse analytics

**User Activity Table**: `user_id`, `activity_type`
- User behavior analysis requires filtering by user and activity patterns
- Enables efficient funnel analysis and user segmentation

### 3. Schema Design Principles

#### Nested vs. Flattened Data

**Nested Approach (Used)**:
- `items` array in orders table
- `shipping_address` struct in orders table
- `metadata` struct in user_activity table

**Benefits**:
- **Atomic Transactions**: Keep related data together
- **Query Simplicity**: Single table queries for complete order info
- **Storage Efficiency**: No data duplication
- **JSON Compatibility**: Direct mapping from source events

#### Data Types & Constraints

**String Fields**: Used for IDs and enum-like values for flexibility
**TIMESTAMP**: UTC timestamps for consistent time zone handling
**FLOAT64**: For monetary values (note: DECIMAL may be considered for production)
**INT64**: For quantities and counts

### 4. Performance Optimizations

#### Query Performance
```sql
-- Optimized query using partitioning and clustering
SELECT 
  customer_id,
  COUNT(*) as order_count,
  SUM(total_amount) as total_value
FROM orders 
WHERE event_date >= '2024-01-01'  -- Partition pruning
  AND status = 'delivered'         -- Clustering benefit
GROUP BY customer_id
```

#### Storage Optimization
- **Partition Expiration**: 90-day retention for cost management
- **Compression**: Automatic BigQuery compression for nested data
- **Column Store**: Efficient for analytical queries

### 5. Historical Data & Time Travel

#### Time Travel Capabilities
- BigQuery automatically maintains 7-day time travel
- `processed_timestamp` enables audit trails
- Partition-based archival for long-term retention

#### Historical Data Integration
```sql
-- Query to combine real-time and historical data
SELECT * FROM orders 
WHERE event_date >= '2023-01-01'  -- Includes historical data
UNION ALL
SELECT * FROM `project.historical_dataset.orders`
WHERE event_date < '2023-01-01'
```

### 6. Monitoring & Observability

#### Table Labels
- Environment identification (`environment=dev`)
- Management source (`managed_by=cloud_function`)
- Purpose classification (`assessment=data_engineering`)

#### Query Performance Monitoring
```sql
-- Monitor table usage and query patterns
SELECT
  table_name,
  creation_time,
  row_count,
  size_bytes
FROM `dev_events_dataset.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE_TABLE'
```

### 7. Scalability Considerations

#### Future Growth
- **Horizontal Scaling**: Partitioning supports unlimited growth
- **Query Scaling**: Clustering maintains performance as data grows
- **Cost Scaling**: Partition expiration controls storage costs

#### Schema Evolution
- **Backward Compatibility**: New fields added as NULLABLE
- **Forward Compatibility**: Flexible JSON-like structures
- **Version Management**: Event schema versioning capability

## Analytical Use Cases

### 1. Customer Analytics
```sql
-- Customer lifetime value analysis
SELECT 
  customer_id,
  COUNT(DISTINCT order_id) as order_count,
  SUM(total_amount) as lifetime_value,
  AVG(total_amount) as avg_order_value
FROM orders 
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY customer_id
ORDER BY lifetime_value DESC
```

### 2. Inventory Management
```sql
-- Real-time inventory levels
SELECT 
  product_id,
  warehouse_id,
  SUM(quantity_change) as current_stock
FROM inventory
WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY product_id, warehouse_id
HAVING current_stock < 10  -- Low stock alert
```

### 3. User Behavior Analysis
```sql
-- User funnel analysis
SELECT 
  activity_type,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(*) as total_events
FROM user_activity
WHERE event_date = CURRENT_DATE()
GROUP BY activity_type
ORDER BY total_events DESC
```

## Security & Compliance

### Data Access Control
- **IAM Roles**: Dataflow service account with minimal permissions
- **Column-Level Security**: Possible with BigQuery column-level ACLs
- **Row-Level Security**: Can be implemented for multi-tenant scenarios

### Data Privacy
- **PII Handling**: IP addresses and user agents stored (consider hashing for production)
- **Retention Policies**: 90-day automatic expiration
- **Audit Logs**: BigQuery audit logs capture all access

## Cost Optimization

### Storage Costs
- **Partitioning**: Reduces query costs by scanning only relevant partitions
- **Clustering**: Improves query performance, reducing slot usage
- **Expiration**: Automatic deletion after 90 days

### Query Costs
- **Partition Pruning**: Dramatically reduces bytes scanned
- **Clustering**: Reduces data shuffling in queries
- **Materialized Views**: Can be added for frequent analytical queries

### Example Cost Analysis
```sql
-- Query cost estimation
SELECT 
  ROUND(5.0 * (1024*1024*1024*1024) / POW(2,40), 2) as cost_per_TB,
  ROUND(estimated_bytes_processed / POW(2,40), 6) as TB_processed,
  ROUND(5.0 * estimated_bytes_processed / POW(2,40), 2) as estimated_cost_usd
FROM INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE job_id = 'your_job_id'
```

## Next Steps & Recommendations

### Production Readiness
1. **Data Validation**: Implement schema validation in Dataflow pipeline
2. **Error Handling**: Dead letter queues for malformed events
3. **Monitoring**: Set up BigQuery monitoring and alerting
4. **Backup Strategy**: Cross-region backup for disaster recovery

### Performance Enhancements
1. **Materialized Views**: For frequently accessed aggregations
2. **Streaming Inserts**: Consider streaming buffer optimization
3. **Query Optimization**: Regular query performance reviews

### Compliance & Security
1. **Data Lineage**: Implement data lineage tracking
2. **Access Controls**: Implement fine-grained access controls
3. **Encryption**: Ensure encryption at rest and in transit 