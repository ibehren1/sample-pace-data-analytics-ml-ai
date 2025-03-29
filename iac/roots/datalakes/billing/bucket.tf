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

module "billing_data_bucket" {

  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-billing-data"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "billing"
}

data "aws_iam_policy_document" "billing_policy_document" {

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy"
    ]
    resources = [module.billing_data_bucket.primary_bucket_arn]
  }

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = ["${module.billing_data_bucket.primary_bucket_arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "billing_policy" {

  bucket = module.billing_data_bucket.primary_bucket_id
  policy = data.aws_iam_policy_document.billing_policy_document.json
}

resource "aws_s3_bucket_notification" "billing_s3_notification" {

  bucket = module.billing_data_bucket.primary_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.billing_workflow_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "billing/"
    filter_suffix       = ".gz"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

module "billing_iceberg_bucket" {

  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-billing-iceberg"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "billing"
}

module "billing_hive_bucket" {

  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-billing-hive"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "billing"
}

resource "aws_s3_object" "billing_data_files" {

  for_each = fileset("${path.module}/../../../../data/billing/static/", "*.gz")
  bucket   = module.billing_data_bucket.primary_bucket_id
  key = each.value
  source = "${path.module}/../../../../data/billing/static/${each.value}"
  content_type = "gz"
  kms_key_id = data.aws_kms_key.s3_primary_key.arn
}
