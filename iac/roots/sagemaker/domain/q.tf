// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_ssm_parameter" "q_enabled" {

  name        = "/${var.APP}/${var.ENV}/datazone/q/${local.domain_id}/q-enabled"
  type        = "SecureString"
  value       = "true"
  description = "Whether to enable Amazon Q for this domain"
  key_id      = data.aws_kms_key.ssm_kms_key.key_id
}

# Set auth-mode as IAM
resource "aws_ssm_parameter" "q_auth_mode" {

  name        = "/${var.APP}/${var.ENV}/datazone/q/${local.domain_id}/auth-mode"
  type        = "SecureString"
  value       = "IAM"
  description = "Authentication mode for Amazon Q"
  key_id      = data.aws_kms_key.ssm_kms_key.key_id
}
