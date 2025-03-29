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
NAMESPACE = args.get("NAMESPACE")
TABLE_BUCKET_ARN = args.get("TABLE_BUCKET_ARN")

# Spark configuration for S3 Tables
conf = SparkConf()
conf.set("spark.sql.catalog.s3tablescatalog", "org.apache.iceberg.spark.SparkCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.catalog-impl", "software.amazon.s3tables.iceberg.S3TablesCatalog")
conf.set("spark.sql.catalog.s3tablescatalog.warehouse", TABLE_BUCKET_ARN)
conf.set("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")

sparkContext = SparkContext(conf=conf)

glueContext = GlueContext(sparkContext)

spark = glueContext.spark_session

spark.sql(f"CREATE NAMESPACE IF NOT EXISTS s3tablescatalog.{NAMESPACE}")           

spark.sql(f"CREATE TABLE s3tablescatalog.{NAMESPACE}.billing (identity_line_item_id string, identity_time_interval string, bill_invoice_id string, bill_invoicing_entity string, bill_billing_entity string, bill_bill_type string, bill_payer_account_id string, bill_billing_period_start_date string, bill_billing_period_end_date string, line_item_usage_account_id string, line_item_line_item_type string, line_item_usage_start_date string, line_item_usage_end_date string, line_item_product_code string, line_item_usage_type string, line_item_operation string, line_item_availability_zone string, line_item_resource_id string, line_item_usage_amount string, line_item_normalization_factor string, line_item_normalized_usage_amount string, line_item_currency_code string, line_item_unblended_rate string, line_item_unblended_cost string, line_item_blended_rate string, line_item_blended_cost string, line_item_line_item_description string, line_item_tax_type string, line_item_legal_entity string, product_product_name string, product_availability string, product_category string, product_ci_type string, product_cloud_formation_resource_provider string, product_description string, product_durability string, product_endpoint_type string, product_event_type string, product_fee_code string, product_fee_description string, product_free_query_types string, product_from_location string, product_from_location_type string, product_from_region_code string, product_group string, product_group_description string, product_location string, product_location_type string, product_logs_destination string, product_message_delivery_frequency string, product_message_delivery_order string, product_operation string, product_plato_pricing_type string, product_product_family string, product_queue_type string, product_region string, product_region_code string, product_request_type string, product_service_code string, product_service_name string, product_sku string, product_storage_class string, product_storage_media string, product_to_location string, product_to_location_type string, product_to_region_code string, product_transfer_type string, product_usage_type string, product_version string, product_volume_type string, pricing_rate_code string, pricing_rate_id string, pricing_currency string, pricing_public_on_demand_cost string, pricing_public_on_demand_rate string, pricing_term string, pricing_unit string, reservation_amortized_upfront_cost_for_usage string, reservation_amortized_upfront_fee_for_billing_period string, reservation_effective_cost string, reservation_end_time string, reservation_modification_status string, reservation_normalized_units_per_reservation string, reservation_number_of_reservations string, reservation_recurring_fee_for_usage string, reservation_start_time string, reservation_subscription_id string, reservation_total_reserved_normalized_units string, reservation_total_reserved_units string, reservation_units_per_reservation string, reservation_unused_amortized_upfront_fee_for_billing_period string, reservation_unused_normalized_unit_quantity string, reservation_unused_quantity string, reservation_unused_recurring_fee string, reservation_upfront_value string, savings_plan_total_commitment_to_date string, savings_plan_savings_plan_arn string, savings_plan_savings_plan_rate string, savings_plan_used_commitment string, savings_plan_savings_plan_effective_cost string, savings_plan_amortized_upfront_commitment_for_billing_period string, savings_plan_recurring_commitment_for_billing_period string, resource_tags_user_application string, resource_tags_user_environment string, resource_tags_user_usage string) USING iceberg")

