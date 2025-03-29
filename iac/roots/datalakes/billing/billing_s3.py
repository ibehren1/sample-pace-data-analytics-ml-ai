# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.conf import SparkConf  

from pyspark.sql import DataFrame, Row
import datetime
from awsglue import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'SOURCE_DATABASE_NAME', 'NAMESPACE', 'SOURCE_TABLE_NAME', 'TABLE_BUCKET_ARN'])

SOURCE_DATABASE_NAME = args.get("SOURCE_DATABASE_NAME")
SOURCE_TABLE_NAME = args.get("SOURCE_TABLE_NAME")
NAMESPACE = args.get("NAMESPACE")
TABLE_BUCKET_ARN = args.get("TABLE_BUCKET_ARN")

# Spark configuration for S3 Tables
conf = SparkConf()
conf.set("spark.sql.catalog.s3tablescatalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog")
# conf.set("spark.sql.catalog.s3tablescatalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
conf.set("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

conf.set("spark.sql.defaultCatalog", "s3tablescatalog")

sc = SparkContext(conf=conf)
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node1738074093225 = glueContext.create_dynamic_frame.from_catalog(database=SOURCE_DATABASE_NAME, table_name=SOURCE_TABLE_NAME, transformation_ctx="AWSGlueDataCatalog_node1738074093225")

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node1738074158972_df = AWSGlueDataCatalog_node1738074093225.toDF()
    
AWSGlueDataCatalog_node1738074158972_df.createOrReplaceTempView("temp_billing")

spark.sql(f"""
        INSERT INTO s3tablescatalog.{NAMESPACE}.billing
        SELECT * FROM temp_billing
        """)

job.commit()



