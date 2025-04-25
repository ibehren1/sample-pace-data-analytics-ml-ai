# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.conf import SparkConf
from pyspark.sql import functions as F
import boto3
import json
import requests
import urllib3
import time

# Disable SSL warnings for Splunk API calls
urllib3.disable_warnings()

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'SPLUNK_HOST',
    'SPLUNK_SECRET_NAME',
    'TABLE_BUCKET_ARN',
    'NAMESPACE'
])
NAMESPACE = args.get("NAMESPACE")

# Spark configuration for S3 Tables
conf = SparkConf()
conf.set("spark.sql.catalog.s3tablescatalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.warehouse", args['TABLE_BUCKET_ARN'])
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
conf.set("spark.sql.defaultCatalog", "s3tablescatalog")
conf.set("spark.sql.iceberg.handle-timestamp-without-timezone", "true")

sc = SparkContext(conf=conf)
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

try:
    # Get Splunk credentials from Secrets Manager
    secrets_client = boto3.client('secretsmanager')
    secret_response = secrets_client.get_secret_value(
        SecretId=args['SPLUNK_SECRET_NAME']
    )
    credentials = json.loads(secret_response['SecretString'])

    # Create search job using Splunk REST API
    search_url = f"https://{args['SPLUNK_HOST']}:8089/services/search/jobs"
    search_params = {
        "search": "search index=_internal | table _time host source sourcetype",
        "output_mode": "json"
    }
    
    response = requests.post(
        search_url,
        auth=(credentials['username'], credentials['password']),
        data=search_params,
        verify=False
    )
    search_job = response.json()
    sid = search_job['sid']

    # Poll until search completes
    while True:
        status_url = f"https://{args['SPLUNK_HOST']}:8089/services/search/jobs/{sid}"
        status_response = requests.get(
            status_url,
            auth=(credentials['username'], credentials['password']),
            params={"output_mode": "json"},
            verify=False
        )
        
        if status_response.json()['entry'][0]['content']['isDone']:
            break
        time.sleep(1)

    # Get results
    results_url = f"https://{args['SPLUNK_HOST']}:8089/services/search/jobs/{sid}/results"
    results_response = requests.get(
        results_url,
        auth=(credentials['username'], credentials['password']),
        params={"output_mode": "json"},
        verify=False
    )
    
    results = results_response.json()
    
    if results['results']:
        # Format results
        formatted_results = []
        for result in results['results']:
            formatted_result = {
                '_time': result['_time'],
                'host': result['host'],
                'source': result['source'],
                'sourcetype': result['sourcetype']
            }
            formatted_results.append(formatted_result)

        # Create DataFrame and convert timestamp
        df = spark.createDataFrame(formatted_results)
        df = df.withColumn("_time", F.to_timestamp("_time"))

        # Write to Iceberg table
        df.createOrReplaceTempView("temp_splunk")
        spark.sql(f"""
            INSERT INTO s3tablescatalog.{NAMESPACE}.splunk
            SELECT * FROM temp_splunk
        """)

        print(f"Successfully processed {df.count()} records")
    else:
        print("No results found in Splunk logs")

except Exception as e:
    print(f"Error: {str(e)}")
    raise e

finally:
    job.commit()
