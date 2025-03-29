# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.conf import SparkConf  

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'NAMESPACE', 'TABLE_BUCKET_ARN'])
TABLE_BUCKET_ARN = args.get("TABLE_BUCKET_ARN")
NAMESPACE = args.get("NAMESPACE")

# Spark configuration for S3 Tables
conf = SparkConf()
conf.set("spark.sql.catalog.s3tablescatalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

sparkContext = SparkContext(conf=conf)

glueContext = GlueContext(sparkContext)

spark = glueContext.spark_session        

spark.sql(f"DROP TABLE s3tablescatalog.{NAMESPACE}.splunk PURGE")

