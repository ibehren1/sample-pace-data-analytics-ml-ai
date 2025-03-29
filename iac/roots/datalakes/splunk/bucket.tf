// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "s3_primary_key" {

  provider = aws.primary
  key_id   = "alias/${var.S3_PRIMARY_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "s3_secondary_key" {

  provider = aws.secondary
  key_id   = "alias/${var.S3_SECONDARY_KMS_KEY_ALIAS}"
}

module "iceberg_splunk_bucket" {

  source = "../../../templates/modules/bucket"
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-splunk-iceberg"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "splunk"
}





