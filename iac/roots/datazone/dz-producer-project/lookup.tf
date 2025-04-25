// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_ssm_parameter" "datazone_domain_id" {

  name = "/${var.APP}/${var.ENV}/${var.DOMAIN_NAME}/domain_id"
}

data "aws_ssm_parameter" "user_mappings" {
  name = "/${var.APP}/${var.ENV}/identity-center/users"
}

data "aws_ssm_parameter" "datalake_profile_id" {
  name = "/${var.APP}/${var.ENV}/${data.aws_ssm_parameter.datazone_domain_id.value}/datalake_blueprint_id"
}

   
