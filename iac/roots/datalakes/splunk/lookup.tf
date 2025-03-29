// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_ssm_parameter" "vpc_id" {

  name = "/${var.APP}/${var.ENV}/vpc"
}

data "aws_ssm_parameter" "private_subnet1_id" {

  name = "/${var.APP}/${var.ENV}/private-subnet-1"
}

data "aws_ssm_parameter" "glue_security_group" {

  name = "/${var.APP}/${var.ENV}/glue-sg"
}

locals {
  VPC_ID                = data.aws_ssm_parameter.vpc_id.value
  PRIVATE_SUBNET1_ID    = data.aws_ssm_parameter.private_subnet1_id.value
  GLUE_SECURITY_GROUP   = data.aws_ssm_parameter.glue_security_group.value
}
