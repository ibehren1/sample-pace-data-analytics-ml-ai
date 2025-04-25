// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  min_az_count_required = 3

  max_az_count     = min(4, length(data.aws_availability_zones.available.zone_ids))
  smus_domain_name = "sagemaker-unified-studio-domain"
}

resource "random_string" "suffix" {

  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = true

  keepers = {
    trigger = timestamp()
  }
}

# VPC
resource "aws_vpc" "main" {

  cidr_block           = "10.38.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                     = "sagemaker-unified-studio-vpc"
    CreatedForUseWithSageMakerUnifiedStudio  = true
    for-use-with-amazon-emr-managed-policies = true
    Application                              = var.APP
    Environment                              = var.ENV
  }

  # Before creating the VPC, first check if it supports the minimum # of required availability zones
  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available.zone_ids) >= local.min_az_count_required
      error_message = "Region must have at least ${local.min_az_count_required} availability zones."
    }
  }
}

# # Restrict all traffic in default security group
# resource "aws_default_security_group" "default" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "sagemaker-unified-studio-vpc-default-sg"
#     CreatedForUseWithSageMakerUnifiedStudio = true
#   }
# }

# resource "aws_iam_role" "vpc_flow_log_role" {
#   name = "sagemaker-unified-studio-vpc-flow-log-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "vpc-flow-logs.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = {
#     Name = "sagemaker-unified-studio-vpc-flow-log-role"
#     CreatedForUseWithSageMakerUnifiedStudio = true
#   }
# }

# resource "aws_flow_log" "vpc_flow_log" {
#   iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
#   log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.main.id

#   tags = {
#     Name = "sagemaker-unified-studio-vpc-flow-log"
#     CreatedForUseWithSageMakerUnifiedStudio = true
#   }
# }

# resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
#   name              = "/aws/vpc/flow-log/sagemaker-unified-studio-${random_string.suffix.result}"
#   retention_in_days = 365
#   kms_key_id = data.aws_kms_key.cloudwatch_kms_key.arn

#   tags = {
#     Name = "sagemaker-unified-studio-vpc-flow-log-group"
#     CreatedForUseWithSageMakerUnifiedStudio = true
#   }
# }

# resource "aws_iam_role_policy" "vpc_flow_log_policy" {
#   name = "sagemaker-unified-studio-vpc-flow-log-policy"
#   role = aws_iam_role.vpc_flow_log_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ]
#         Effect = "Allow"
#         Resource = "${aws_cloudwatch_log_group.vpc_flow_log_group.arn}:*"
#       },
#       {
#         Action = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:ReEncrypt*",
#           "kms:GenerateDataKey*",
#           "kms:DescribeKey"
#         ]
#         Effect = "Allow"
#         Resource = data.aws_kms_key.cloudwatch_kms_key.arn
#       }      
#     ]
#   })
# }

# Save the VPC Id in SSM Parameter Store
resource "aws_ssm_parameter" "vpc_id" {
  name   = "/${var.APP}/${var.ENV}/smus_domain_vpc_id"
  type   = "SecureString"
  value  = aws_vpc.main.id
  key_id = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "SMUS Domain Pre-req"
  }
}
