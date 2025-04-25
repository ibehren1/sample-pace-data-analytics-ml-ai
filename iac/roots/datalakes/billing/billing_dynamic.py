# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
import json
import boto3
import time
import datetime
from datetime import timezone
import logging
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.types import StructType
import pyspark.sql.types as T

# Configure logging
logging.basicConfig(
    format='%(asctime)s [%(levelname)s] %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Initialize the Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
spark.conf.set("spark.sql.legacy.allowNonEmptyLocationInCTAS", "true")

job = Job(glueContext)

# Get required arguments for workflow mode
try:
    args = getResolvedOptions(sys.argv, [
        'JOB_NAME',
        'TARGET_DATABASE_NAME',
        'CRAWLER_NAME',
        'ICEBERG_BUCKET',
        'WORKFLOW_NAME',
        'WORKFLOW_RUN_ID'
    ])
except Exception as e:
    logger.error(f"Error getting required arguments: {str(e)}")
    raise Exception("This script requires workflow arguments. Use the standard billing.py script for direct processing.")

TARGET_DATABASE_NAME = args.get("TARGET_DATABASE_NAME")
CRAWLER_NAME = args.get("CRAWLER_NAME")
BASE_ICEBERG_BUCKET = args.get("ICEBERG_BUCKET")

# Set table name for the Iceberg crawler table
APP_ENV = TARGET_DATABASE_NAME.split('_')[0:2]
ICEBERG_TABLE_NAME = f"{APP_ENV[0]}_{APP_ENV[1]}_billing_iceberg_dynamic"
logger.info(f"Using custom Iceberg table: {ICEBERG_TABLE_NAME}")

# Define the specific subfolder path for this crawler table
# Make sure the path ends with a trailing slash
if BASE_ICEBERG_BUCKET.endswith('/'):
    ICEBERG_S3_PATH = f"{BASE_ICEBERG_BUCKET}{ICEBERG_TABLE_NAME}"
else:
    ICEBERG_S3_PATH = f"{BASE_ICEBERG_BUCKET}/{ICEBERG_TABLE_NAME}"
    
logger.info(f"Setting Iceberg table location to: {ICEBERG_S3_PATH}")

# Helper function for data type conversion
def get_sql_type(spark_type):
    """Convert Spark data type to SQL data type for ALTER TABLE"""
    
    type_mapping = {
        T.StringType: "STRING",
        T.IntegerType: "INT",
        T.LongType: "BIGINT",
        T.DoubleType: "DOUBLE",
        T.FloatType: "FLOAT",
        T.BooleanType: "BOOLEAN",
        T.TimestampType: "TIMESTAMP",
        T.DateType: "DATE",
        T.DecimalType: "DECIMAL",
        T.BinaryType: "BINARY"
    }
    
    # Handle decimal type specifically as it has precision and scale
    if isinstance(spark_type, T.DecimalType):
        return f"DECIMAL({spark_type.precision},{spark_type.scale})"
    
    # Get the standard type mapping or default to STRING
    for spark_class, sql_type in type_mapping.items():
        if isinstance(spark_type, spark_class):
            return sql_type
    
    # Default to STRING for types we don't explicitly handle
    return "STRING"

# Extract source file path from workflow events
logger.info("=== Getting source file path from workflow properties ===")
file_to_process = None  # Initialize to None, will be set from properties

try:
    # Create Glue client and get workflow properties
    glue_client = boto3.client('glue')
    workflow_run = glue_client.get_workflow_run_properties(
        Name=args['WORKFLOW_NAME'],
        RunId=args['WORKFLOW_RUN_ID']
    )
    logger.debug(f"Extracted workflow_run properties: {workflow_run}")
    
    if workflow_run and 'RunProperties' in workflow_run:
        # Log all available properties for debugging
        logger.info(f"Available RunProperties: {json.dumps(workflow_run['RunProperties'], default=str)}")
        
        # First check for s3_path directly from Lambda
        s3_path = workflow_run['RunProperties'].get('s3_path')
        if s3_path:
            logger.info(f"Found S3 path: {s3_path}")
            file_to_process = s3_path
        else:
            logger.warning("No direct S3 path found in workflow properties")
        
except Exception as e:
    logger.error(f"Exception during workflow properties lookup: {str(e)}")
    raise Exception("Could not determine file to process from workflow properties")

# Check if we successfully found a file to process
if not file_to_process:
    logger.error("No file path found in workflow properties")
    raise Exception("No file path could be determined from workflow properties")

logger.info(f"Processing file: {file_to_process}")

# Check if file has .gz extension - exit gracefully if not
if not file_to_process.lower().endswith('.gz') and '.gz.' not in file_to_process.lower():
    logger.info(f"File {file_to_process} is not a .gz file, skipping processing")
    # Clean exit - no error
    job.commit()
    logger.info("Job completed - skipped non-gz file")
    sys.exit(0)
else:
    logger.info(f"Processing .gz file: {file_to_process}")

job.init(args['JOB_NAME'], args)

# Helper functions
def check_table_exists(database_name, table_name):
    """
    Check if a table exists in the database
    """
    try:
        glue_client = boto3.client('glue')
        glue_client.get_table(
            DatabaseName=database_name,
            Name=table_name
        )
        return True
    except Exception:
        return False
        
def find_crawler_created_table(database_name, file_path=None):
    """
    Find the table created by the crawler by looking for the most recently created table
    or one that matches the file path pattern
    """
    glue_client = boto3.client('glue')
    logger.info(f"Searching for crawler-created table in database {database_name}")
    
    # First get all tables
    try:
        tables = glue_client.get_tables(DatabaseName=database_name)['TableList']
    except Exception as e:
        logger.error(f"Error listing tables: {str(e)}")
        return None
    
    if not tables:
        logger.warning("No tables found in database")
        return None
    
    # Show all tables for debugging
    logger.info("Tables found in database:")
    for t in tables:
        created_time = t.get('CreateTime', 'unknown')
        logger.info(f" - {t['Name']} (created: {created_time})")
    
    # First try to identify by file path
    if file_path:
        # Extract key components from file path to match against table names
        path_parts = file_path.split('/')
        # Get the last few parts that might be in the table name
        key_parts = [p.lower() for p in path_parts[-3:] if p]
        
        logger.info(f"Looking for tables matching path components: {key_parts}")
        
        # Find tables containing any of these path components
        matching_tables = []
        for table in tables:
            table_name = table['Name'].lower()
            if any(part in table_name for part in key_parts):
                matching_tables.append(table)
        
        if matching_tables:
            # Sort by creation time, most recent first
            matching_tables.sort(key=lambda t: t.get('CreateTime', 0) if t.get('CreateTime') else 0, 
                                reverse=True)
            logger.info(f"Found {len(matching_tables)} tables matching the file path")
            most_likely = matching_tables[0]
            logger.info(f"Using most recently created matching table: {most_likely['Name']}")
            return most_likely
    
    # If no match by path, return most recently created table
    tables_with_time = [t for t in tables if t.get('CreateTime')]
    if tables_with_time:
        most_recent = None
        most_recent_time = None
        
        for table in tables_with_time:
            create_time = table.get('CreateTime')
            if most_recent_time is None or create_time > most_recent_time:
                most_recent_time = create_time
                most_recent = table
        
        logger.info(f"Using most recently created table: {most_recent['Name']}")
        return most_recent
    elif tables:
        # If no creation times, just return the first table
        logger.info(f"No creation times available, using first table: {tables[0]['Name']}")
        return tables[0]
    
    return None

def load_data_from_crawler_table(glueContext, database_name, table_name):
    """
    Load data from a table using the DynamicFrame approach
    """
    logger.info(f"Loading data from {database_name}.{table_name} using DynamicFrame")
    
    try:
        # Try DynamicFrame approach first
        dynamic_frame = glueContext.create_dynamic_frame.from_catalog(
            database=database_name,
            table_name=table_name
        )
        
        # Convert to DataFrame for easier handling
        df = dynamic_frame.toDF()
        logger.info(f"Successfully loaded data with {df.count()} rows using DynamicFrame")
        return df
        
    except Exception as e:
        logger.warning(f"DynamicFrame approach failed: {str(e)}")
        
        try:
            # Fall back to direct reading from the source file
            logger.info(f"Loading data directly from the source file: {file_to_process}")
            if file_to_process.lower().endswith('.csv') or '.csv.' in file_to_process.lower():
                df = spark.read.format("csv") \
                    .option("header", "true") \
                    .option("inferSchema", "true") \
                    .load(file_to_process)
            else:
                # Default to parquet
                df = spark.read.format("parquet").load(file_to_process)
                
            logger.info(f"Successfully loaded {df.count()} rows directly from source file")
            return df
                
        except Exception as src_e:
            logger.error(f"Error loading data from source file: {str(src_e)}")
            raise Exception(f"Cannot load data from table or source file")

def delete_crawler_created_table(database_name, table_name):
    """
    Delete a table from the database using Glue API (not SQL)
    """
    if table_name.startswith('temp_'):
        logger.info(f"Table {table_name} is temporary, no need to delete")
        return True
        
    try:
        glue_client = boto3.client('glue')
        glue_client.delete_table(
            DatabaseName=database_name,
            Name=table_name
        )
        logger.info(f"Successfully deleted table {database_name}.{table_name}")
        return True
    except Exception as e:
        logger.error(f"Error deleting table: {str(e)}")
        return False

# First check if the table already exists, and drop it if we need a fresh start
def reset_iceberg_table_if_needed(database_name, table_name, drop_existing=False):
    """
    Check if an Iceberg table exists and optionally drop it to resolve metadata issues
    """
    try:
        table_exists = check_table_exists(database_name, table_name)
        
        if table_exists and drop_existing:
            logger.info(f"Table {database_name}.{table_name} exists and drop_existing=True. Dropping it.")
            try:
                # Try dropping via Spark SQL first
                spark.sql(f"DROP TABLE IF EXISTS {database_name}.{table_name}")
                logger.info(f"Successfully dropped table via Spark SQL")
            except Exception as e:
                logger.warning(f"Could not drop table via Spark SQL: {str(e)}")
                try:
                    # Try dropping via Glue API as backup
                    glue_client = boto3.client('glue')
                    glue_client.delete_table(DatabaseName=database_name, Name=table_name)
                    logger.info(f"Successfully dropped table via Glue API")
                except Exception as e2:
                    logger.error(f"Could not drop table via Glue API either: {str(e2)}")
                    return False
            return True
        
        return table_exists
    except Exception as e:
        logger.error(f"Error checking/dropping table: {str(e)}")
        return False

# Find the table created by the crawler - we don't need to start the crawler anymore
# as it's handled by the workflow
logger.info("===== Finding crawler-created table =====")
crawler_table = find_crawler_created_table(TARGET_DATABASE_NAME, file_to_process)
if not crawler_table:
    logger.error("No crawler-created table found")
    raise Exception("Could not find any table created by the crawler")

crawler_table_name = crawler_table['Name']
logger.info(f"Found crawler-created table: {crawler_table_name}")

# Load data from the crawler-created table
logger.info("===== Loading data from crawler table =====")
try:
    # Get the source DataFrame
    source_df = load_data_from_crawler_table(glueContext, TARGET_DATABASE_NAME, crawler_table_name)
    
    # Cache it to improve performance
    source_df.cache()
    row_count = source_df.count()
    column_count = len(source_df.columns)
    logger.info(f"Successfully loaded source data with {row_count} rows and {column_count} columns")
    
    # Print the schema for debugging
    logger.info("Source schema:")
    for field in source_df.schema.fields:
        logger.info(f"  - {field.name}: {field.dataType}")
except Exception as e:
    logger.error(f"Error loading data from crawler table: {str(e)}")
    raise Exception("Cannot load data from crawler table. Please check the Glue Data Catalog.")

# Check for existing table and potentially drop it if it has metadata issues
logger.info("===== Preparing custom Iceberg table =====")
# Usually we want to append, but if there are metadata issues, set this to True
drop_if_exists = False  # Change to True if you need to recreate the table due to metadata issues
iceberg_exists = reset_iceberg_table_if_needed(TARGET_DATABASE_NAME, ICEBERG_TABLE_NAME, drop_if_exists)

# If the Iceberg table exists, get its schema to check for missing columns
target_schema = None
missing_columns = []
new_columns = []
columns_added = []

if iceberg_exists:
    try:
        # Get the target schema
        logger.info(f"Reading schema from existing table {TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME}")
        target_df = spark.sql(f"SELECT * FROM {TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME} LIMIT 0")
        target_schema = target_df.schema
        
        # Check for missing columns
        source_columns = set([field.name.lower() for field in source_df.schema.fields])
        target_columns = set([field.name.lower() for field in target_schema.fields])
        
        # Find columns in target that are missing from source
        missing_columns = [col for col in target_columns if col not in source_columns]
        
        if missing_columns:
            logger.warning(f"Missing columns in source data: {missing_columns}")
            
            # Fix missing columns by adding them with null values
            for col in missing_columns:
                # Get the column's datatype from target schema
                col_type = next((field.dataType for field in target_schema.fields if field.name.lower() == col), None)
                logger.info(f"Adding missing column {col} with type {col_type}")
                
                # Add the column with null values
                source_df = source_df.withColumn(col, lit(None).cast(col_type))
            
            # Verify all columns are now present
            logger.info("Updated source schema after adding missing columns:")
            for field in source_df.schema.fields:
                logger.info(f"  - {field.name}: {field.dataType}")
        
        # Now check if source has NEW columns that don't exist in target
        new_columns = [col for col in source_columns if col not in target_columns]
        
        if new_columns:
            logger.info(f"Found {len(new_columns)} NEW columns in source data: {new_columns}")
            
            # Use ALTER TABLE to add the new columns before inserting data
            try:
                # For each new column, determine its data type from the source dataframe
                for col_name in new_columns:
                    # Find the column in the source schema
                    source_field = next((field for field in source_df.schema.fields if field.name.lower() == col_name.lower()), None)
                    if source_field:
                        # Convert Spark data type to SQL data type
                        spark_type = source_field.dataType
                        sql_type = get_sql_type(spark_type)
                        
                        # Execute ALTER TABLE statement
                        alter_sql = f"ALTER TABLE {TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME} ADD COLUMN `{source_field.name}` {sql_type}"
                        logger.info(f"Adding new column with: {alter_sql}")
                        spark.sql(alter_sql)
                        columns_added.append(source_field.name)
                        
                logger.info(f"Successfully added {len(columns_added)} new columns to table schema")
            except Exception as e:
                logger.warning(f"Error adding columns with ALTER TABLE: {str(e)}")
                logger.warning("Falling back to dropping new columns")
                source_df = source_df.select([col for col in source_df.columns if col.lower() in target_columns])
        else:
            logger.info("No new columns found in source data")
            
    except Exception as e:
        logger.warning(f"Error getting target schema: {str(e)}")

# Create or update the custom Iceberg table for workflow
logger.info("===== Working with custom Iceberg table =====")

# Save as custom Iceberg table with schema evolution
try:
    if iceberg_exists and not drop_if_exists:
        logger.info(f"Iceberg table {ICEBERG_TABLE_NAME} already exists, appending data")
        
        # For existing table, use append mode with schema merging enabled
        source_df.write \
            .format("iceberg") \
            .option("write-format", "parquet") \
            .option("merge-schema", "true") \
            .mode("append") \
            .option("path", ICEBERG_S3_PATH) \
            .saveAsTable(f"{TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME}")
        
        logger.info(f"Successfully appended {row_count} rows to Iceberg table {ICEBERG_TABLE_NAME}")
    else:
        logger.info(f"Creating new Iceberg table {ICEBERG_TABLE_NAME}")
        
        # Create new table with overwrite mode to initialize properly
        source_df.write \
            .format("iceberg") \
            .option("write-format", "parquet") \
            .mode("overwrite") \
            .option("path", ICEBERG_S3_PATH) \
            .saveAsTable(f"{TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME}")
        
        logger.info(f"Successfully created Iceberg table {ICEBERG_TABLE_NAME} with {row_count} rows")
    
    # Clean up crawler table
    logger.info("===== Cleaning up =====")
    delete_success = delete_crawler_created_table(TARGET_DATABASE_NAME, crawler_table_name)
    if delete_success:
        logger.info(f"Successfully deleted crawler-created table {crawler_table_name}")
    else:
        logger.warning(f"Could not delete crawler-created table {crawler_table_name}")
        
except Exception as e:
    logger.error(f"Error creating/updating Iceberg table: {str(e)}")
    
    # If it's a metadata-related error, try recreating the table
    if ("metadata" in str(e).lower() or "incompatible" in str(e).lower()) and not drop_if_exists:
        logger.warning(f"Detected issue: {str(e)}. Attempting to recreate the table...")
        try:
            # Drop the table to clear metadata
            reset_iceberg_table_if_needed(TARGET_DATABASE_NAME, ICEBERG_TABLE_NAME, True)
            
            # Create new table with clean slate
            source_df.write \
                .format("iceberg") \
                .option("write-format", "parquet") \
                .mode("overwrite") \
                .option("path", ICEBERG_S3_PATH) \
                .saveAsTable(f"{TARGET_DATABASE_NAME}.{ICEBERG_TABLE_NAME}")
                
            logger.info(f"Successfully recreated table after schema/metadata issue")
        except Exception as retry_error:
            logger.error(f"Failed to recreate table: {str(retry_error)}")
            raise Exception(f"Failed to create or update Iceberg table: {str(e)}")
    else:
        raise Exception(f"Failed to create or update Iceberg table: {str(e)}")

# Display job summary
logger.info("\n===== Job Summary =====")
logger.info(f"- Data source: {file_to_process}")
logger.info(f"- Crawler-created table: {crawler_table_name}")
logger.info(f"- Created/updated Iceberg table: {ICEBERG_TABLE_NAME} at {ICEBERG_S3_PATH}")
logger.info(f"- Processed {row_count} rows with {column_count} columns")
if missing_columns:
    logger.info(f"- Added missing columns: {', '.join(missing_columns)}")
if columns_added:
    logger.info(f"- Added new columns via ALTER TABLE: {', '.join(columns_added)}")
logger.info("=======================\n")

# Commit the job
job.commit()
logger.info("Job completed successfully")
