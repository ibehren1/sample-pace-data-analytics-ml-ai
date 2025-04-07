// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "ssm_kms_key" {

  key_id   = "alias/${var.SSM_KMS_KEY_ALIAS}"
}

data "aws_ssm_parameter" "datazone_domain_id" {

  name = "/${var.APP}/${var.ENV}/${var.DOMAIN_NAME}/domain_id"
}

locals {
  datalake  = "s3://${var.APP}-${var.ENV}-glue-temp-primary"
  domain_id = data.aws_ssm_parameter.datazone_domain_id.value
}

# Create IAM roles for Datazone
module "project_prereq" {

  source = "../../../templates/modules/datazone-project/prereq"

  APP                       = var.APP
  ENV                       = var.ENV
  KMS_KEY                   = data.aws_kms_key.ssm_kms_key.arn
  USAGE                     = "Datazone"
  domain_id                 = local.domain_id
  region                    = data.aws_region.current.name
  blue_print                = var.PROJECT_BLUEPRINT
  DATALAKE_S3               = local.datalake
}
