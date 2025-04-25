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
    raise Exception("This script requires workflow arguments. Use the standard inventory.py script for direct processing.")

TARGET_DATABASE_NAME = args.get("TARGET_DATABASE_NAME")
CRAWLER_NAME = args.get("CRAWLER_NAME")
BASE_ICEBERG_BUCKET = args.get("ICEBERG_BUCKET")

# Set table name for the Iceberg crawler table
APP_ENV = TARGET_DATABASE_NAME.split('_')[0:2]
ICEBERG_TABLE_NAME = f"{APP_ENV[0]}_{APP_ENV[1]}_inventory_iceberg_dynamic"
logger.info(f"Using custom Iceberg table: {ICEBERG_TABLE_NAME}")

# Define the specific subfolder path for this crawler table using the table name
if BASE_ICEBERG_BUCKET.endswith('/'):
    ICEBERG_S3_PATH = f"{BASE_ICEBERG_BUCKET}{ICEBERG_TABLE_NAME}"
else:
    ICEBERG_S3_PATH = f"{BASE_ICEBERG_BUCKET}/{ICEBERG_TABLE_NAME}"

logger.info(f"Using Iceberg location: {ICEBERG_S3_PATH}")

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
            logger.info(f"Found S3 path directly from Lambda: {s3_path}")
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
    Find the table created by the crawler
    """
    glue_client = boto3.client('glue')
    try:
        response = glue_client.get_tables(DatabaseName=database_name)
        tables = response['TableList']
        logger.info(f"Found {len(tables)} tables in database {database_name}")
        
        if not tables:
            logger.warning("No tables found in database")
            return None
        
        # Filter out the Iceberg table first - we never want to select that one
        non_iceberg_tables = [t for t in tables if t['Name'].lower() != ICEBERG_TABLE_NAME.lower()]
        logger.info(f"Found {len(non_iceberg_tables)} non-Iceberg tables")
        
        if not non_iceberg_tables:
            logger.warning("No non-Iceberg tables found")
            return None
        
        # Try to find tables created by crawler by looking for table names that contain UUID patterns
        # Typical crawler-created tables have UUIDs in the name
        import re
        uuid_pattern = re.compile(r'[a-f0-9]{8}[_-][a-f0-9]{4}[_-][a-f0-9]{4}[_-][a-f0-9]{4}[_-][a-f0-9]{12}')
        
        crawler_tables = []
        for table in non_iceberg_tables:
            table_name = table['Name'].lower()
            if uuid_pattern.search(table_name):
                crawler_tables.append(table)
                logger.info(f"Found crawler-created table with UUID: {table_name}")
                
        if crawler_tables:
            # Sort by creation time, most recent first
            crawler_tables.sort(key=lambda t: t.get('CreateTime', 0) if t.get('CreateTime') else 0, 
                                reverse=True)
            most_recent = crawler_tables[0]
            logger.info(f"Using most recently created crawler table: {most_recent['Name']}")
            return most_recent
        
        # If no UUID-pattern tables found, try to extract UUID from file path and match
        if file_path:
            uuid_match = re.search(r'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})', file_path)
            if uuid_match:
                uuid_part = uuid_match.group(1)
                logger.info(f"Extracted UUID from file path: {uuid_part}")
                
                # Format to match how Glue might format it in a table name
                formatted_uuid = uuid_part.replace('-', '_')
                
                for table in non_iceberg_tables:
                    table_name = table['Name'].lower()
                    if formatted_uuid.lower() in table_name.lower():
                        logger.info(f"Found table matching file UUID: {table['Name']}")
                        return table
        
        # If still nothing, fall back to most recently created table
        tables_with_time = [t for t in non_iceberg_tables if t.get('CreateTime')]
        if tables_with_time:
            # Sort by creation time, most recent first
            tables_with_time.sort(key=lambda t: t['CreateTime'], reverse=True)
            most_recent = tables_with_time[0]
            logger.info(f"Using most recently created table by timestamp: {most_recent['Name']}")
            return most_recent
        
        # Last resort: just return the first non-Iceberg table
        logger.info(f"Using first available table: {non_iceberg_tables[0]['Name']}")
        return non_iceberg_tables[0]
        
    except Exception as e:
        logger.error(f"Error finding crawler-created table: {str(e)}")
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
    Delete a table from the Glue Data Catalog
    """
    try:
        if table_name.lower() == ICEBERG_TABLE_NAME.lower():
            logger.warning(f"Refusing to delete {table_name} as it matches our Iceberg table name")
            return False
            
        glue_client = boto3.client('glue')
        glue_client.delete_table(
            DatabaseName=database_name,
            Name=table_name
        )
        logger.info(f"Successfully deleted table {database_name}.{table_name}")
        return True
    except Exception as e:
        logger.error(f"Error deleting table {table_name}: {str(e)}")
        return False

# First check if the table already exists, and drop it if we need a fresh start
def reset_iceberg_table_if_needed(database_name, table_name, drop_existing=False):
    """
    Check if the Iceberg table exists, and drop it if needed
    """
    try:
        table_exists = check_table_exists(database_name, table_name)
        
        if table_exists and drop_existing:
            logger.info(f"Table {table_name} exists and drop_existing=True, dropping the table")
            try:
                # Try to drop via SQL first
                spark.sql(f"DROP TABLE IF EXISTS {database_name}.{table_name}")
                logger.info(f"Successfully dropped table {database_name}.{table_name}")
                table_exists = False
            except Exception as e:
                logger.warning(f"Could not drop table via SQL: {str(e)}")
                try:
                    # Try Glue API as backup method
                    glue_client = boto3.client('glue')
                    glue_client.delete_table(
                        DatabaseName=database_name,
                        Name=table_name
                    )
                    logger.info(f"Successfully dropped table via Glue API: {database_name}.{table_name}")
                    table_exists = False
                except Exception as e2:
                    logger.error(f"Could not drop table via Glue API either: {str(e2)}")
                    return False
            return True
        
        return table_exists
    except Exception as e:
        logger.error(f"Error checking/dropping table: {str(e)}")
        return False

# Helper function for data type conversion
def get_sql_type(spark_type):
    """Convert Spark data type to SQL data type for ALTER TABLE"""
    type_str = str(spark_type).lower()
    
    if 'string' in type_str:
        return "STRING"
    elif 'int' in type_str:
        return "INT"
    elif 'long' in type_str or 'bigint' in type_str:
        return "BIGINT"
    elif 'double' in type_str:
        return "DOUBLE"
    elif 'decimal' in type_str:
        # Extract precision and scale if available
        import re
        match = re.search(r'decimal\((\d+),(\d+)\)', type_str)
        if match:
            precision = match.group(1)
            scale = match.group(2)
            return f"DECIMAL({precision},{scale})"
        else:
            return "DECIMAL(10,2)"
    elif 'float' in type_str:
        return "FLOAT"
    elif 'boolean' in type_str:
        return "BOOLEAN"
    elif 'timestamp' in type_str:
        return "TIMESTAMP"
    elif 'date' in type_str:
        return "DATE"
    elif 'binary' in type_str:
        return "BINARY"
    else:
        return "STRING"  # Default to string for unknown types

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

# Check for generic columns
if source_df.columns and any(col.lower().startswith('col') for col in source_df.columns):
    logger.info("Detected generic column names, applying inventory schema...")
    expected_columns = [
        "bucket", 
        "key", 
        "versionid", 
        "islatest", 
        "isdeletemaker", 
        "size", 
        "lastmodifieddate", 
        "etag", 
        "storageclass", 
        "ismultipartuploaded", 
        "replicationstatus", 
        "encryptionstatus", 
        "objectlockretainuntildate", 
        "objectlockmode", 
        "objectlocklegalholdstatus", 
        "intelligenttieringaccesstier", 
        "bucketkeystatus", 
        "checksumalgorithm", 
        "objectowner"
    ]
    
    if len(source_df.columns) == len(expected_columns):
        column_mapping = {}
        for i, name in enumerate(expected_columns):
            column_mapping[f"col{i}"] = name
        for old_name, new_name in column_mapping.items():
            if old_name in source_df.columns:
                logger.info(f"Renaming column {old_name} to {new_name}")
                source_df = source_df.withColumnRenamed(old_name, new_name)
        
        logger.info("Successfully renamed generic columns to proper schema")
        logger.info("Updated schema after renaming:")
        for field in source_df.schema.fields:
            logger.info(f"  - {field.name}: {field.dataType}")
    else:
        logger.warning(f"Column count mismatch: found {len(source_df.columns)} columns but expected {len(expected_columns)}")
        logger.warning("Will proceed with generic column names")
        logger.info("Generic column names found:")
        for i, col in enumerate(source_df.columns):
            logger.info(f"  - Index {i}: {col}")

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
