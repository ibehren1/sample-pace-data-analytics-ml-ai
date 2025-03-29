// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

terraform {
  required_version = ">= 1.8.0"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_kms_key" "ssm_kms_key" {

  provider = aws.primary
  key_id   = "alias/${var.SSM_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "domain_kms_key" {

  provider = aws.primary
  key_id   = "alias/${var.DOMAIN_KMS_KEY_ALIAS}"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

##========= Clean up *.json.out and *.txt.out files when destroy is invoked ===========##
resource "null_resource" "cleanup_files" {
  
  depends_on = [
    null_resource.create_smus_domain,
    # null_resource.create_project_profile
  ]

  triggers = {
    domain_id = local.domain_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      
      # Remove all .json.out files
      rm -f *.json.out
      
      # Remove all .txt.out files 
      rm -f *.txt.out
      
      echo "Cleaned up all .json.out and .txt.out files"
    EOT
  }
}

##============ End Clean up  ==========================================================##
