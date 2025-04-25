// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "null_resource" "create_smus_domain" {

  provisioner "local-exec" {
    command = <<-EOT
      aws datazone create-domain \
        --name "Corporate" \
        --description "SageMaker Unified Studio Domain" \
        --domain-execution-role "${local.SMUS_DOMAIN_EXECUTION_ROLE_ARN}" \
        --service-role "${local.SMUS_DOMAIN_SERVICE_ROLE_ARN}" \
        --domain-version "V2" \
        --single-sign-on '{"type": "IAM_IDC", "userAssignment": "MANUAL"}' \
        --region ${local.region} \
        --kms-key-identifier "${data.aws_kms_key.domain_kms_key.arn}" \
        --output json > create_domain_output.json.out
    EOT
  }

}

# Read the domain output file
data "local_file" "create_domain_output" {

  depends_on = [null_resource.create_smus_domain]
  filename   = "${path.module}/create_domain_output.json.out"
}

locals {
  domain_id = jsondecode(data.local_file.create_domain_output.content).id
}

# Also, save the domain id in SSM Parameter Store
resource "aws_ssm_parameter" "smus_domain_id" {

  name   = "/${var.APP}/${var.ENV}/smus_domain_id"
  type   = "SecureString"
  value  = local.domain_id
  key_id = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "SMUS Domain"
  }
}

##================= Delete Domain when destroy is invoked ===========##
resource "null_resource" "delete_smus_domain" {

  depends_on = [null_resource.create_smus_domain]

  triggers = {
    domain_id = local.domain_id
    region    = local.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      set -e
      
      delete_domain() {
        local domain_id="$1"
        local region="$2"
        
        echo "Attempting to delete DataZone domain $domain_id in region $region"
        
        # Check if domain exists before attempting deletion
        if ! aws datazone get-domain \
          --identifier "$domain_id" \
          --region "$region" >/dev/null 2>&1; then
          echo "Domain $domain_id does not exist or is already deleted"
          return 0
        fi
        
        # Attempt domain deletion
        if aws datazone delete-domain \
          --identifier "$domain_id" \
          --region "$region" 2>/dev/null; then
          echo "Delete command issued successfully for domain $domain_id"
        else
          echo "Failed to issue delete command for domain $domain_id"
          return 1
        fi
        
        # Wait for deletion to complete
        local max_retries=30
        local retry_interval=10
        local retry_count=0
        
        while [ $retry_count -lt $max_retries ]; do
          if ! aws datazone get-domain \
            --identifier "$domain_id" \
            --region "$region" >/dev/null 2>&1; then
            echo "Domain $domain_id deleted successfully"
            return 0
          fi
          
          echo "Waiting for domain deletion to complete... (Attempt $((retry_count + 1))/$max_retries)"
          sleep $retry_interval
          retry_count=$((retry_count + 1))
        done
        
        echo "Error: Timeout waiting for domain $domain_id deletion"
        return 1
      }
      
      # Main execution
      if ! delete_domain "${self.triggers.domain_id}" "${self.triggers.region}"; then
        echo "Failed to delete domain ${self.triggers.domain_id}"
        exit 1
      fi
    EOT
  }
}
