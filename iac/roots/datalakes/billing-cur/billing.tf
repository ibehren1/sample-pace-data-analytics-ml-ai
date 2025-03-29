// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_cur_report_definition" "cost_usage_report" {

  report_name                = "${var.APP}-${var.ENV}-cost-and-usage-report"
  time_unit                  = "HOURLY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  s3_bucket                  = var.BILLING_DATA_BUCKET
  s3_prefix                  = "billing"
  s3_region                  = "us-east-1"
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT"]
  refresh_closed_reports     = true
  report_versioning          = "OVERWRITE_REPORT"
}
