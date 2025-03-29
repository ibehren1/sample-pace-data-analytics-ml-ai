# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.conf import SparkConf  

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'NAMESPACE', 'TABLE_BUCKET_ARN'])

# Spark configuration for S3 Tables
NAMESPACE = args.get("NAMESPACE")
TABLE_BUCKET_ARN = args.get("TABLE_BUCKET_ARN")
conf = SparkConf()
conf.set("spark.sql.catalog.s3tablescatalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

sparkContext = SparkContext(conf=conf)

glueContext = GlueContext(sparkContext)

spark = glueContext.spark_session

spark.sql(f"CREATE NAMESPACE IF NOT EXISTS s3tablescatalog.{NAMESPACE}")           

spark.sql(f"CREATE TABLE s3tablescatalog.{NAMESPACE}.inventory (bucket string, key string, size string, last_modified_date string, etag string, storage_class string, is_multipart_uploaded string, replication_status string, encryption_status string, is_latest string, object_lock_mode string, object_lock_legal_hold_status string, bucket_key_status string, object_lock_retain_until_date string, checksum_algorithm string, object_access_control_list string, object_owner string) USING iceberg")

