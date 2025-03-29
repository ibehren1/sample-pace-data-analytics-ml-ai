// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "secrets_manager_kms_key" {

  key_id   = "alias/${var.SECRETS_MANAGER_KMS_KEY_ALIAS}"
}

resource "random_password" "splunk_password" {

  length           = 8
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

resource "aws_secretsmanager_secret" "splunk_credentials" {

  name = "${var.APP}-${var.ENV}-splunk-credentials"
  recovery_window_in_days = 0
  kms_key_id = data.aws_kms_key.secrets_manager_kms_key.id

  tags = {
    Usage = "splunk"
  }

  #checkov:skip=CKV2_AWS_57: "Ensure Secrets Manager secrets should have automatic rotation enabled": "Skipping for simplicity"
}

resource "aws_secretsmanager_secret_version" "splunk_credentials" {
    
  secret_id = aws_secretsmanager_secret.splunk_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.splunk_password.result
  })
}
