"""
Real-time Data Pipeline using Apache Beam
Processes events from Pub/Sub and writes to BigQuery and GCS
"""

import argparse
import json
import logging
from datetime import datetime
from typing import Dict, Any

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions
from apache_beam.io import ReadFromPubSub
from apache_beam.io.gcp.bigquery import WriteToBigQuery
from apache_beam.io.textio import WriteToText


class EventProcessor(beam.DoFn):
    """Process and transform events for BigQuery and GCS output"""
    
    def process(self, element):
        """
        Process a single event from Pub/Sub
        
        Args:
            element: Raw message from Pub/Sub
            
        Yields:
            Tuple of (event_type, processed_event)
        """
        try:
            # Parse JSON message
            event_data = json.loads(element.decode('utf-8'))
            event_type = event_data.get('event_type')
            
            if not event_type:
                logging.warning(f"No event_type found in message: {element}")
                return
            
            # Add processing timestamp and event_date
            now = datetime.utcnow()
            event_data['processed_timestamp'] = now.isoformat() + 'Z'
            
            # Extract or create event_date for partitioning
            if event_type == 'order':
                # Use order_date for partitioning
                order_date = event_data.get('order_date')
                if order_date:
                    event_date = datetime.fromisoformat(order_date.replace('Z', '+00:00')).date()
                else:
                    event_date = now.date()
            elif event_type in ['inventory', 'user_activity']:
                # Use timestamp field
                timestamp = event_data.get('timestamp')
                if timestamp:
                    event_date = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).date()
                else:
                    event_date = now.date()
            else:
                event_date = now.date()
            
            event_data['event_date'] = event_date.isoformat()
            
            # Yield tuple for downstream processing
            yield (event_type, event_data)
            
        except Exception as e:
            logging.error(f"Error processing event: {e}, Element: {element}")


class FormatForBigQuery(beam.DoFn):
    """Format events for BigQuery insertion"""
    
    def process(self, element):
        """
        Format event for BigQuery
        
        Args:
            element: Tuple of (event_type, event_data)
            
        Yields:
            Dict formatted for BigQuery
        """
        event_type, event_data = element
        
        # Map event types to table names
        table_mapping = {
            'order': 'orders',
            'inventory': 'inventory',
            'user_activity': 'user_activity'
        }
        
        table_name = table_mapping.get(event_type)
        if table_name:
            # Add table destination info
            event_data['_table_name'] = table_name
            yield event_data


class FormatForGCS(beam.DoFn):
    """Format events for GCS output with specific folder structure"""
    
    def process(self, element):
        """
        Format event for GCS with folder structure
        
        Args:
            element: Tuple of (event_type, event_data)
            
        Yields:
            Tuple of (file_path, json_content)
        """
        event_type, event_data = element
        
        try:
            # Get timestamp for folder structure
            if event_type == 'order':
                timestamp_str = event_data.get('order_date')
            elif event_type in ['inventory', 'user_activity']:
                timestamp_str = event_data.get('timestamp')
            else:
                timestamp_str = datetime.utcnow().isoformat() + 'Z'
            
            # Parse timestamp to create folder structure
            if timestamp_str:
                dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            else:
                dt = datetime.utcnow()
            
            # Create folder structure: output/event_type/YYYY/MM/DD/HH/MM/
            folder_path = f"output/{event_type}/{dt.year:04d}/{dt.month:02d}/{dt.day:02d}/{dt.hour:02d}/{dt.minute:02d}"
            
            # Create filename with timestamp and unique identifier
            filename = f"{event_type}_{dt.strftime('%Y%m%d%H%M')}{dt.second:02d}{dt.microsecond//1000:03d}.json"
            
            file_path = f"{folder_path}/{filename}"
            json_content = json.dumps(event_data, ensure_ascii=False)
            
            yield (file_path, json_content)
            
        except Exception as e:
            logging.error(f"Error formatting for GCS: {e}, Event: {event_data}")


def run_pipeline(argv=None):
    """Main pipeline execution function"""
    
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--input_subscription',
        dest='input_subscription',
        required=True,
        help='Pub/Sub subscription to read from')
    parser.add_argument(
        '--output_dataset',
        dest='output_dataset', 
        required=True,
        help='BigQuery dataset to write to')
    parser.add_argument(
        '--output_gcs_prefix',
        dest='output_gcs_prefix',
        required=True,
        help='GCS prefix for output files')
    parser.add_argument(
        '--project',
        dest='project',
        required=True,
        help='GCP project ID')
    parser.add_argument(
        '--region',
        dest='region',
        default='us-central1',
        help='GCP region')
    parser.add_argument(
        '--environment',
        dest='environment',
        default='dev',
        help='Environment (dev, staging, prod)')
    
    known_args, pipeline_args = parser.parse_known_args(argv)
    
    # Pipeline options
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(StandardOptions).streaming = True
    
    # BigQuery table specifications
    table_specs = {
        'orders': f"{known_args.project}:{known_args.output_dataset}.orders",
        'inventory': f"{known_args.project}:{known_args.output_dataset}.inventory", 
        'user_activity': f"{known_args.project}:{known_args.output_dataset}.user_activity"
    }
    
    with beam.Pipeline(options=pipeline_options) as pipeline:
        
        # Read from Pub/Sub
        raw_events = (
            pipeline
            | 'ReadFromPubSub' >> ReadFromPubSub(subscription=known_args.input_subscription)
        )
        
        # Process events
        processed_events = (
            raw_events
            | 'ProcessEvents' >> beam.ParDo(EventProcessor())
        )
        
        # Branch 1: Write to BigQuery
        bigquery_events = (
            processed_events
            | 'FormatForBigQuery' >> beam.ParDo(FormatForBigQuery())
        )
        
        # Write orders to BigQuery
        orders = (
            bigquery_events
            | 'FilterOrders' >> beam.Filter(lambda x: x.get('_table_name') == 'orders')
            | 'RemoveTableName_Orders' >> beam.Map(lambda x: {k: v for k, v in x.items() if k != '_table_name'})
            | 'WriteToBigQuery_Orders' >> WriteToBigQuery(
                table_specs['orders'],
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER
            )
        )
        
        # Write inventory to BigQuery
        inventory = (
            bigquery_events
            | 'FilterInventory' >> beam.Filter(lambda x: x.get('_table_name') == 'inventory')
            | 'RemoveTableName_Inventory' >> beam.Map(lambda x: {k: v for k, v in x.items() if k != '_table_name'})
            | 'WriteToBigQuery_Inventory' >> WriteToBigQuery(
                table_specs['inventory'],
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER
            )
        )
        
        # Write user_activity to BigQuery
        user_activity = (
            bigquery_events
            | 'FilterUserActivity' >> beam.Filter(lambda x: x.get('_table_name') == 'user_activity')
            | 'RemoveTableName_UserActivity' >> beam.Map(lambda x: {k: v for k, v in x.items() if k != '_table_name'})
            | 'WriteToBigQuery_UserActivity' >> WriteToBigQuery(
                table_specs['user_activity'],
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER
            )
        )
        
        # Branch 2: Write to GCS
        gcs_events = (
            processed_events
            | 'FormatForGCS' >> beam.ParDo(FormatForGCS())
            | 'FormatJSONForGCS' >> beam.Map(lambda x: x[1])  # Extract JSON content
        )
        
        # Write to GCS with windowing for streaming
        windowed_gcs_events = (
            gcs_events
            | 'WindowIntoFixedIntervals' >> beam.WindowInto(beam.window.FixedWindows(60))  # 1-minute windows
        )
        
        # Write to GCS
        gcs_output = (
            windowed_gcs_events
            | 'WriteToGCS' >> WriteToText(
                f"{known_args.output_gcs_prefix}/output",
                file_name_suffix='.json',
                num_shards=1
            )
        )


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run_pipeline() 