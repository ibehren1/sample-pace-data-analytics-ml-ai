# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import boto3
import os
import urllib.parse
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel("INFO")


def lambda_handler(event, context):
    """
    Lambda function triggered by S3 object creation in the billing folder.
    Updates the crawler target and starts a Glue workflow.
    """
    try:
        logger.info(f"Received S3 event: {json.dumps(event)}")

        # Extract S3 bucket and key information
        s3_event = event['Records'][0]['s3']
        bucket_name = s3_event['bucket']['name']
        object_key = urllib.parse.unquote_plus(s3_event['object']['key'])
        s3_path = f"s3://{bucket_name}/{object_key}"

        logger.info(f"File uploaded: {urllib.parse.quote(s3_path)}")
        # import urllib

        # Skip if not a .gz file
        if not object_key.lower().endswith('.gz') and '.gz.' not in object_key.lower():
            logger.info(
                f"File {urllib.parse.quote(s3_path)} is not a .gz file, skipping workflow trigger")
            return {
                'statusCode': 200,
                'body': json.dumps('Non-gz file detected, workflow not triggered')
            }

        # Check if this is in the right path pattern (billing folder)
        if not object_key.startswith('billing/'):
            logger.info(
                f"File {urllib.parse.quote(s3_path)} is not in the billing folder, skipping workflow trigger")
            return {
                'statusCode': 200,
                'body': json.dumps('File not in billing folder, workflow not triggered')
            }

        # Get environment variables
        workflow_name = os.environ.get('GLUE_WORKFLOW_NAME')
        crawler_name = os.environ.get('CRAWLER_NAME')

        if not workflow_name:
            raise ValueError("GLUE_WORKFLOW_NAME environment variable not set")

        if not crawler_name:
            raise ValueError("CRAWLER_NAME environment variable not set")

        # Initialize Glue client
        glue_client = boto3.client('glue')

        # 1. Update the crawler target with the S3 path first
        logger.info(
            f"Updating crawler {crawler_name} to target: {urllib.parse.quote(s3_path)}")
        try:
            response = glue_client.update_crawler(
                Name=crawler_name,
                Targets={
                    'S3Targets': [
                        {
                            'Path': s3_path
                        }
                    ]
                }
            )
            logger.info(
                f"Successfully updated crawler target to: {urllib.parse.quote(s3_path)}")
        except Exception as crawler_error:
            logger.error(
                f"Error updating crawler target: {str(crawler_error)}")
            raise crawler_error

        # 2. Start the Glue workflow with source file information
        response = glue_client.start_workflow_run(
            Name=workflow_name,
            RunProperties={
                's3_path': s3_path
            }
        )

        run_id = response.get('RunId')
        logger.info(f"Started workflow {workflow_name} with run ID {run_id}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"Successfully triggered workflow {workflow_name}",
                'workflow_run_id': run_id,
                's3_path': s3_path
            })
        }

    except Exception as e:
        logger.error(f"Error processing S3 event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {str(e)}")
        }
