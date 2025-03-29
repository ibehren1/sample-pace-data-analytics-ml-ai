// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.4.2"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  tags = {
    "App" = var.APP
    "Env" = var.ENV
  }

  converted_data_source = {
    table_name = "${var.APP}_${var.ENV}_billing_hive"
    database_name = "${var.APP}_${var.ENV}_billing"
  }

  // Only the tables that are registered with LakeFormation will include here
  tables = [
    {
      name = "${var.APP}_${var.ENV}_inventory_hive"
      database = "${var.APP}_${var.ENV}_inventory"
    },
    {
      name = "${var.APP}_${var.ENV}_billing_hive"
      database = "${var.APP}_${var.ENV}_billing"
    },
    {
      name = "${var.APP}_${var.ENV}_billing_iceberg_static"
      database = "${var.APP}_${var.ENV}_billing"
    },
    {
      name = "${var.APP}_${var.ENV}_inventory_iceberg_static"
      database = "${var.APP}_${var.ENV}_inventory"
    },
    {
      name = "${var.APP}_${var.ENV}_splunk_iceberg"
      database = "${var.APP}_${var.ENV}_splunk"
    }
  ]

  inventory_columns = {
    "bucket"                        = "STRING"
    "key"                           = "STRING"
    "size"                          = "STRING"
    "last_modified_date"            = "STRING"
    "etag"                          = "STRING"
    "storage_class"                 = "STRING"
    "is_multipart_uploaded"         = "STRING"
    "replication_status"            = "STRING"
    "encryption_status"             = "STRING"
    "is_latest"                     = "STRING"
    "object_lock_mode"              = "STRING"
    "object_lock_legal_hold_status" = "STRING"
    "bucket_key_status"             = "STRING"
    "object_lock_retain_until_date" = "STRING"
    "checksum_algorithm"            = "STRING"
    "object_access_control_list"    = "STRING"
    "object_owner"                  = "STRING"
  }

  billing_columns = {
    # Identity columns
    "identity_line_item_id"             = "STRING"
    "identity_time_interval"            = "STRING"

    # Bill columns
    "bill_invoice_id"                   = "STRING"
    "bill_invoicing_entity"             = "STRING"
    "bill_billing_entity"               = "STRING"
    "bill_bill_type"                    = "STRING"
    "bill_payer_account_id"             = "STRING"
    "bill_billing_period_start_date"    = "STRING"
    "bill_billing_period_end_date"      = "STRING"

    # Line item columns
    "line_item_usage_account_id"        = "STRING"
    "line_item_line_item_type"          = "STRING"
    "line_item_usage_start_date"        = "STRING"
    "line_item_usage_end_date"          = "STRING"
    "line_item_product_code"            = "STRING"
    "line_item_usage_type"              = "STRING"
    "line_item_operation"               = "STRING"
    "line_item_availability_zone"       = "STRING"
    "line_item_resource_id"             = "STRING"
    "line_item_usage_amount"            = "STRING"
    "line_item_normalization_factor"    = "STRING"
    "line_item_normalized_usage_amount" = "STRING"
    "line_item_currency_code"           = "STRING"
    "line_item_unblended_rate"         = "STRING"
    "line_item_unblended_cost"         = "STRING"
    "line_item_blended_rate"           = "STRING"
    "line_item_blended_cost"           = "STRING"
    "line_item_line_item_description"  = "STRING"
    "line_item_tax_type"               = "STRING"
    "line_item_legal_entity"           = "STRING"

    # Product columns
    "product_product_name"                      = "STRING"
    "product_availability"                      = "STRING"
    "product_category"                          = "STRING"
    "product_ci_type"                           = "STRING"
    "product_cloud_formation_resource_provider" = "STRING"
    "product_description"                       = "STRING"
    "product_durability"                        = "STRING"
    "product_endpoint_type"                     = "STRING"
    "product_event_type"                        = "STRING"
    "product_fee_code"                          = "STRING"
    "product_fee_description"                   = "STRING"
    "product_free_query_types"                  = "STRING"
    "product_from_location"                     = "STRING"
    "product_from_location_type"                = "STRING"
    "product_from_region_code"                  = "STRING"
    "product_group"                             = "STRING"
    "product_group_description"                 = "STRING"
    "product_location"                          = "STRING"
    "product_location_type"                     = "STRING"
    "product_logs_destination"                  = "STRING"
    "product_message_delivery_frequency"        = "STRING"
    "product_message_delivery_order"            = "STRING"
    "product_operation"                         = "STRING"
    "product_plato_pricing_type"                = "STRING"
    "product_product_family"                    = "STRING"
    "product_queue_type"                        = "STRING"
    "product_region"                            = "STRING"
    "product_region_code"                       = "STRING"
    "product_request_type"                      = "STRING"
    "product_service_code"                      = "STRING"
    "product_service_name"                      = "STRING"
    "product_sku"                               = "STRING"
    "product_storage_class"                     = "STRING"
    "product_storage_media"                     = "STRING"
    "product_to_location"                       = "STRING"
    "product_to_location_type"                  = "STRING"
    "product_to_region_code"                    = "STRING"
    "product_transfer_type"                     = "STRING"
    "product_usage_type"                        = "STRING"
    "product_version"                           = "STRING"
    "product_volume_type"                       = "STRING"

    # Pricing columns
    "pricing_rate_code"                         = "STRING"
    "pricing_rate_id"                           = "STRING"
    "pricing_currency"                          = "STRING"
    "pricing_public_on_demand_cost"             = "STRING"
    "pricing_public_on_demand_rate"             = "STRING"
    "pricing_term"                              = "STRING"
    "pricing_unit"                              = "STRING"

    # Reservation columns
    "reservation_amortized_upfront_cost_for_usage"                = "STRING"
    "reservation_amortized_upfront_fee_for_billing_period"        = "STRING"
    "reservation_effective_cost"                                  = "STRING"
    "reservation_end_time"                                        = "STRING"
    "reservation_modification_status"                             = "STRING"
    "reservation_normalized_units_per_reservation"                = "STRING"
    "reservation_number_of_reservations"                          = "STRING"
    "reservation_recurring_fee_for_usage"                         = "STRING"
    "reservation_start_time"                                      = "STRING"
    "reservation_subscription_id"                                 = "STRING"
    "reservation_total_reserved_normalized_units"                 = "STRING"
    "reservation_total_reserved_units"                            = "STRING"
    "reservation_units_per_reservation"                           = "STRING"
    "reservation_unused_amortized_upfront_fee_for_billing_period" = "STRING"
    "reservation_unused_normalized_unit_quantity"                 = "STRING"
    "reservation_unused_quantity"                                 = "STRING"
    "reservation_unused_recurring_fee"                            = "STRING"
    "reservation_upfront_value"                                   = "STRING"

    # Savings Plan columns
    "savings_plan_total_commitment_to_date"                         = "STRING"
    "savings_plan_savings_plan_arn"                                 = "STRING"
    "savings_plan_savings_plan_rate"                                = "STRING"
    "savings_plan_used_commitment"                                  = "STRING"
    "savings_plan_savings_plan_effective_cost"                      = "STRING"
    "savings_plan_amortized_upfront_commitment_for_billing_period"  = "STRING"
    "savings_plan_recurring_commitment_for_billing_period"          = "STRING"

    # Resource Tags columns
    "resource_tags_user_application"                           = "STRING"
    "resource_tags_user_environment"                           = "STRING"
    "resource_tags_user_usage"                                 = "STRING"
  }

  billing_converted_columns = {
    # Identity columns
    "identity_line_item_id"             = "STRING"
    "identity_time_interval"            = "STRING"

    # Bill columns
    "bill_invoice_id"                   = "STRING"
    "bill_invoicing_entity"             = "STRING"
    "bill_billing_entity"               = "STRING"
    "bill_bill_type"                    = "STRING"
    "bill_payer_account_id"             = "STRING"
    "bill_billing_period_start_date"    = "STRING"
    "bill_billing_period_end_date"      = "STRING"

    # Line item columns
    "line_item_usage_account_id"        = "STRING"
    "line_item_line_item_type"          = "STRING"
    "line_item_usage_start_date"        = "DATETIME"
    "line_item_usage_end_date"          = "DATETIME"
    "line_item_product_code"            = "STRING"
    "line_item_usage_type"              = "STRING"
    "line_item_operation"               = "STRING"
    "line_item_availability_zone"       = "STRING"
    "line_item_resource_id"             = "STRING"
    "line_item_usage_amount"            = "DECIMAL"
    "line_item_normalization_factor"    = "STRING"
    "line_item_normalized_usage_amount" = "STRING"
    "line_item_currency_code"           = "STRING"
    "line_item_unblended_rate"         = "DECIMAL"
    "line_item_unblended_cost"         = "DECIMAL"
    "line_item_blended_rate"           = "DECIMAL"
    "line_item_blended_cost"           = "DECIMAL"
    "line_item_line_item_description"  = "STRING"
    "line_item_tax_type"               = "STRING"
    "line_item_legal_entity"           = "STRING"

    # Product columns
    "product_product_name"                      = "STRING"
    "product_availability"                      = "STRING"
    "product_category"                          = "STRING"
    "product_ci_type"                           = "STRING"
    "product_cloud_formation_resource_provider" = "STRING"
    "product_description"                       = "STRING"
    "product_durability"                        = "STRING"
    "product_endpoint_type"                     = "STRING"
    "product_event_type"                        = "STRING"
    "product_fee_code"                          = "STRING"
    "product_fee_description"                   = "STRING"
    "product_free_query_types"                  = "STRING"
    "product_from_location"                     = "STRING"
    "product_from_location_type"                = "STRING"
    "product_from_region_code"                  = "STRING"
    "product_group"                             = "STRING"
    "product_group_description"                 = "STRING"
    "product_location"                          = "STRING"
    "product_location_type"                     = "STRING"
    "product_logs_destination"                  = "STRING"
    "product_message_delivery_frequency"        = "STRING"
    "product_message_delivery_order"            = "STRING"
    "product_operation"                         = "STRING"
    "product_plato_pricing_type"                = "STRING"
    "product_product_family"                    = "STRING"
    "product_queue_type"                        = "STRING"
    "product_region"                            = "STRING"
    "product_region_code"                       = "STRING"
    "product_request_type"                      = "STRING"
    "product_service_code"                      = "STRING"
    "product_service_name"                      = "STRING"
    "product_sku"                               = "STRING"
    "product_storage_class"                     = "STRING"
    "product_storage_media"                     = "STRING"
    "product_to_location"                       = "STRING"
    "product_to_location_type"                  = "STRING"
    "product_to_region_code"                    = "STRING"
    "product_transfer_type"                     = "STRING"
    "product_usage_type"                        = "STRING"
    "product_version"                           = "STRING"
    "product_volume_type"                       = "STRING"

    # Pricing columns
    "pricing_rate_code"                         = "STRING"
    "pricing_rate_id"                           = "STRING"
    "pricing_currency"                          = "STRING"
    "pricing_public_on_demand_cost"             = "DECIMAL"
    "pricing_public_on_demand_rate"             = "DECIMAL"
    "pricing_term"                              = "STRING"
    "pricing_unit"                              = "STRING"

    # Reservation columns
    "reservation_amortized_upfront_cost_for_usage"                = "DECIMAL"
    "reservation_amortized_upfront_fee_for_billing_period"        = "DECIMAL"
    "reservation_effective_cost"                                  = "DECIMAL"
    "reservation_end_time"                                        = "DATETIME"
    "reservation_modification_status"                             = "STRING"
    "reservation_normalized_units_per_reservation"                = "STRING"
    "reservation_number_of_reservations"                          = "INTEGER"
    "reservation_recurring_fee_for_usage"                         = "STRING"
    "reservation_start_time"                                      = "DATETIME"
    "reservation_subscription_id"                                 = "STRING"
    "reservation_total_reserved_normalized_units"                 = "STRING"
    "reservation_total_reserved_units"                            = "STRING"
    "reservation_units_per_reservation"                           = "STRING"
    "reservation_unused_amortized_upfront_fee_for_billing_period" = "DECIMAL"
    "reservation_unused_normalized_unit_quantity"                 = "STRING"
    "reservation_unused_quantity"                                 = "INTEGER"
    "reservation_unused_recurring_fee"                            = "DECIMAL"
    "reservation_upfront_value"                                   = "DECIMAL"

    # Savings Plan columns
    "savings_plan_total_commitment_to_date"                         = "INTEGER"
    "savings_plan_savings_plan_arn"                                 = "STRING"
    "savings_plan_savings_plan_rate"                                = "DECIMAL"
    "savings_plan_used_commitment"                                  = "STRING"
    "savings_plan_savings_plan_effective_cost"                      = "DECIMAL"
    "savings_plan_amortized_upfront_commitment_for_billing_period"  = "STRING"
    "savings_plan_recurring_commitment_for_billing_period"          = "STRING"

    # Resource Tags columns
    "resource_tags_user_application"                           = "STRING"
    "resource_tags_user_environment"                           = "STRING"
    "resource_tags_user_usage"                                 = "STRING"
  }

  splunk_columns = {
    "_time"      = "DATETIME"
    "host"       = "STRING"
    "source"     = "STRING"
    "sourcetype" = "STRING"
  }

  // Query used by QuickSight
  billing_custom_query = <<EOF
SELECT
    CAST(NULLIF(line_item_usage_amount, '') AS DOUBLE) as line_item_usage_amount,
    CAST(CAST(NULLIF(line_item_usage_start_date, '') AS TIMESTAMP) AS DATE) as line_item_usage_start_date,
    CAST(CAST(NULLIF(line_item_usage_end_date, '') AS TIMESTAMP) AS DATE) as line_item_usage_end_date,
    CAST(NULLIF(line_item_unblended_rate, '') AS DOUBLE) as line_item_unblended_rate,
    CAST(NULLIF(line_item_unblended_cost, '') AS DOUBLE) as line_item_unblended_cost,
    CAST(NULLIF(line_item_blended_rate, '') AS DOUBLE) as line_item_blended_rate,
    CAST(NULLIF(line_item_blended_cost, '') AS DOUBLE) as line_item_blended_cost,
    CAST(NULLIF(pricing_public_on_demand_cost, '') AS DOUBLE) as pricing_public_on_demand_cost,
    CAST(NULLIF(pricing_public_on_demand_rate, '') AS DOUBLE) as pricing_public_on_demand_rate,
    CAST(NULLIF(reservation_amortized_upfront_cost_for_usage, '') AS DOUBLE) as reservation_amortized_upfront_cost_for_usage,
    CAST(NULLIF(reservation_amortized_upfront_fee_for_billing_period, '') AS DOUBLE) as reservation_amortized_upfront_fee_for_billing_period,
    CAST(NULLIF(reservation_effective_cost, '') AS DOUBLE) as reservation_effective_cost,
    CAST(CAST(NULLIF(reservation_end_time, '') AS TIMESTAMP) AS DATE) as reservation_end_time,
    CAST(NULLIF(reservation_number_of_reservations, '') AS INT) as reservation_number_of_reservations,
    CAST(CAST(NULLIF(reservation_start_time, '') AS TIMESTAMP) AS DATE) as reservation_start_time,
    CAST(NULLIF(reservation_unused_amortized_upfront_fee_for_billing_period, '') AS DOUBLE) as reservation_unused_amortized_upfront_fee_for_billing_period,
    CAST(NULLIF(reservation_unused_quantity, '') AS INT) as reservation_unused_quantity,
    CAST(NULLIF(reservation_unused_recurring_fee, '') AS DOUBLE) as reservation_unused_recurring_fee,
    CAST(NULLIF(reservation_upfront_value, '') AS DOUBLE) as reservation_upfront_value,
    CAST(NULLIF(savings_plan_total_commitment_to_date, '') AS INT) as savings_plan_total_commitment_to_date,
    CAST(NULLIF(savings_plan_savings_plan_rate, '') AS DOUBLE) as savings_plan_savings_plan_rate,
    CAST(NULLIF(savings_plan_savings_plan_effective_cost, '') AS DOUBLE) as savings_plan_savings_plan_effective_cost,
    identity_line_item_id,
    identity_time_interval,
    bill_payer_account_id,
    bill_invoice_id,
    bill_invoicing_entity,
    bill_billing_entity,
    bill_bill_type,
    bill_billing_period_start_date,
    bill_billing_period_end_date,
    line_item_usage_account_id,
    line_item_line_item_type,
    line_item_product_code,
    line_item_usage_type,
    line_item_operation,
    line_item_availability_zone,
    line_item_resource_id,
    line_item_normalization_factor,
    line_item_normalized_usage_amount,
    line_item_currency_code,
    line_item_line_item_description,
    line_item_tax_type,
    line_item_legal_entity,
    product_product_name,
    product_availability,
    product_category,
    product_ci_type,
    product_cloud_formation_resource_provider,
    product_description,
    product_durability,
    product_endpoint_type,
    product_event_type,
    product_fee_code,
    product_fee_description,
    product_free_query_types,
    product_from_location,
    product_from_location_type,
    product_from_region_code,
    product_group,
    product_group_description,
    product_location,
    product_location_type,
    product_logs_destination,
    product_message_delivery_frequency,
    product_message_delivery_order,
    product_operation,
    product_plato_pricing_type,
    product_product_family,
    product_queue_type,
    product_region,
    product_region_code,
    product_request_type,
    product_service_code,
    product_service_name,
    product_sku,
    product_storage_class,
    product_storage_media,
    product_to_location,
    product_to_location_type,
    product_to_region_code,
    product_transfer_type,
    product_usage_type,
    product_version,
    product_volume_type,
    pricing_rate_code,
    pricing_rate_id,
    pricing_currency,
    pricing_term,
    pricing_unit,
    reservation_modification_status,
    reservation_normalized_units_per_reservation,
    reservation_recurring_fee_for_usage,
    reservation_subscription_id,
    reservation_total_reserved_normalized_units,
    reservation_total_reserved_units,
    reservation_units_per_reservation,
    reservation_unused_normalized_unit_quantity,
    savings_plan_savings_plan_arn,
    savings_plan_used_commitment,
    savings_plan_amortized_upfront_commitment_for_billing_period,
    savings_plan_recurring_commitment_for_billing_period
FROM AwsDataCatalog.${local.converted_data_source.database_name}.${local.converted_data_source.table_name}
EOF

  inventory_columns_formatted = [
    for name, type in local.inventory_columns : {
      name = name
      type = type
    }
  ]

  billing_columns_formatted = [
    for name, type in local.billing_columns : {
      name = name
      type = type
    }
  ]

  splunk_columns_formatted = [
    for name, type in local.splunk_columns : {
      name = name
      type = type
    }
  ]

  custom_query_table = {
    id        = "billing-converted"
    name      = "billing-converted"
    sql_query = local.billing_custom_query
  }

  // Include all Athena tables and views that QuickSight use for analytics
  all_tables = [
    {
      id        = "inventory-hive"
      name      = "inventory-hive"
      sql_query = "SELECT * FROM \"AwsDataCatalog\".\"${var.APP}_${var.ENV}_inventory\".\"${var.APP}_${var.ENV}_inventory_hive\""
      columns   = local.inventory_columns_formatted
    },
    {
      id        = "billing-hive"
      name      = "billing-hive"
      sql_query = "SELECT * FROM \"AwsDataCatalog\".\"${var.APP}_${var.ENV}_billing\".\"${var.APP}_${var.ENV}_billing_hive\""
      columns   = local.billing_columns_formatted
    },
    {
      id        = "inventory-iceberg-static"
      name      = "inventory-iceberg-static"
      sql_query = "SELECT * FROM \"AwsDataCatalog\".\"${var.APP}_${var.ENV}_inventory\".\"${var.APP}_${var.ENV}_inventory_iceberg_static\""
      columns   = local.inventory_columns_formatted
    },
    {
      id        = "billing-iceberg"
      name      = "billing-iceberg"
      sql_query = "SELECT * FROM \"AwsDataCatalog\".\"${var.APP}_${var.ENV}_billing\".\"${var.APP}_${var.ENV}_billing_iceberg_static\""
      columns   = local.billing_columns_formatted
    },
    {
      id        = "splunk-iceberg"
      name      = "splunk-iceberg"
      sql_query = "SELECT * FROM \"AwsDataCatalog\".\"${var.APP}_${var.ENV}_splunk\".\"${var.APP}_${var.ENV}_splunk_iceberg\""
      columns   = local.splunk_columns_formatted
    }
  ]
}


