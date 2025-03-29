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

module "glue_scripts_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-glue-scripts"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "glue"
}

module "glue_jars_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-glue-jars"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "glue"
}

module "glue_spark_logs_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-glue-spark-logs"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "glue"
}

module "glue_temp_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-glue-temp"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "glue"
}

module "athena_output_bucket" {

  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-athena-output"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "athena"
}

locals {
  smus_projects_bucket_name = "${var.APP}-${var.ENV}-amazon-sagemaker-${local.account_id}"
}

module "smus_projects_bucket" {

  source = "../../../templates/modules/bucket"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = local.smus_projects_bucket_name
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "smus_projects"
}

module "smus_cfn_bucket" {

  source = "../../../templates/modules/bucket"
  
  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  RESOURCE_PREFIX              = "${var.APP}-${var.ENV}-smus-project-cfn-template"
  BUCKET_NAME_PRIMARY_REGION   = "primary"
  BUCKET_NAME_SECONDARY_REGION = "secondary"
  PRIMARY_CMK_ARN              = data.aws_kms_key.s3_primary_key.arn
  SECONDARY_CMK_ARN            = data.aws_kms_key.s3_secondary_key.arn
  APP                          = var.APP
  ENV                          = var.ENV
  USAGE                        = "smus_projects"
}
