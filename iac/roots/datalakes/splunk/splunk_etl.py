# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql import functions as F
import boto3
import json
import requests
from datetime import datetime
import urllib3
import time

# Disable SSL warnings
urllib3.disable_warnings()

# Initialize contexts and job
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'SPLUNK_HOST',
    'TARGET_DATABASE_NAME',
    'TARGET_TABLE_NAME',
    'SPLUNK_SECRET_NAME',
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
spark.conf.set("spark.sql.iceberg.handle-timestamp-without-timezone", "true")
job = Job(glueContext)
job.init(args['JOB_NAME'], args)


try:
    # Get Splunk credentials from Secrets Manager
    secrets_client = boto3.client('secretsmanager')
    secret_response = secrets_client.get_secret_value(
        SecretId=args['SPLUNK_SECRET_NAME']
    )
    credentials = json.loads(secret_response['SecretString'])

    # Create search job
    search_url = f"https://{args['SPLUNK_HOST']}:8089/services/search/jobs"
    search_params = {
        "search": "search index=_internal | table _time host source sourcetype",
        "output_mode": "json"
    }
    
    # Start search job
    response = requests.post(
        search_url,
        auth=(credentials['username'], credentials['password']),
        data=search_params,
        verify=False
    )
    search_job = response.json()
    sid = search_job['sid']
    
    print(f"Search job created with SID: {sid}")

    # Wait for search to complete
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
    
    print("Search completed, getting results...")

    # Get results using GET request with parameters in URL
    results_url = f"https://{args['SPLUNK_HOST']}:8089/services/search/jobs/{sid}/results"
    results_response = requests.get(
        results_url,
        auth=(credentials['username'], credentials['password']),
        params={"output_mode": "json"},
        verify=False
    )
    
    results = results_response.json()
    
    if results['results']:
        # Convert results to DynamicFrame
        formatted_results = []
        for result in results['results']:
            formatted_result = {
                '_time': result['_time'],
                'host': result['host'],
                'source': result['source'],
                'sourcetype': result['sourcetype']
            }
            formatted_results.append(formatted_result)
        
        # Create DataFrame and convert to DynamicFrame
        df = spark.createDataFrame(formatted_results)
        
        # Add this line to convert _time from string to timestamp
        df = df.withColumn("_time", F.to_timestamp("_time"))

        # Write directly using DataFrame writer for Iceberg
        df.write \
            .format("iceberg") \
            .mode("append") \
            .saveAsTable(f"aws_glue.{args['TARGET_DATABASE_NAME']}.{args['TARGET_TABLE_NAME']}")

        print(f"Successfully processed {df.count()} records")
    else:
        print("No results found in Splunk logs")

except Exception as e:
    print(f"Error: {str(e)}")
    raise e

finally:
    job.commit()
