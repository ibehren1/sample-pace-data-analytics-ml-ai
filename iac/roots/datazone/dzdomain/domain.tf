// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "ssm_kms_key" {

  key_id   = "alias/${var.SSM_KMS_KEY_ALIAS}"
}

data "aws_ssm_parameter" "smus_lambda_service_role_name" {

  name = "/${var.APP}/${var.ENV}/smus_lambda_service_role_name"
}

# Datazone Domain
module "domain" {

  source = "../../../templates/modules/datazone-domain"

  APP                       = var.APP
  ENV                       = var.ENV
  DOMAIN_NAME               = var.DOMAIN_NAME
  #DOMAIN_EXECUTION_ROLE_ARN = "arn:aws:iam::${local.account_id}:role/${var.DOMAIN_EXECUTION_ROLE_NAME}"
  DOMAIN_EXECUTION_ROLE_ARN = data.aws_ssm_parameter.smus_lambda_service_role_name.value
  KMS_KEY                   = data.aws_kms_key.ssm_kms_key.arn
  USAGE                     = "Datazone"
  IDC_ARN                   = var.IDC_ARN
}
