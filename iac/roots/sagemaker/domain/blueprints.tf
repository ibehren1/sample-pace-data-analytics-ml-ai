// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_datazone_environment_blueprint_configuration" "blueprint_configs" {

  for_each = toset(var.blueprint_ids)

  domain_id                = "${local.domain_id}"
  environment_blueprint_id = each.value
  enabled_regions          = ["${local.region}"]
  regional_parameters = {
    "${local.region}": {
      "AZs": local.SMUS_DOMAIN_AVAILABILITY_ZONE_NAMES
      "S3Location": local.SMUS_PROJECTS_BUCKET_S3_URL
      "VpcId": local.SMUS_DOMAIN_VPC_ID
      "Subnets": local.SMUS_DOMAIN_PRIVATE_SUBNET_IDS
    }
  }

  manage_access_role_arn = aws_iam_role.smus_domain_manage_access_role.arn
  provisioning_role_arn = local.SMUS_DOMAIN_PROVISIONING_ROLE_ARN
}

# Grant access to the root domain unit on all the blueprints

resource "null_resource" "blueprint_policy_grants" {
  
  depends_on = [ aws_datazone_environment_blueprint_configuration.blueprint_configs ]
  for_each = toset(var.blueprint_ids)

  provisioner "local-exec" {
    command = <<-EOT
      aws datazone add-policy-grant \
        --domain-identifier "${local.domain_id}" \
        --entity-identifier "${local.account_id}:${each.value}" \
        --entity-type "ENVIRONMENT_BLUEPRINT_CONFIGURATION" \
        --policy-type "CREATE_ENVIRONMENT_FROM_BLUEPRINT" \
        --principal '${jsonencode({
          "project": {
            "projectGrantFilter": {
              "domainUnitFilter": {
                "domainUnit": "${local.root_domain_unit_id}",
                "includeChildDomainUnits": true
              }
            },
            "projectDesignation": "CONTRIBUTOR"
          }
        })}' \
        --detail '${jsonencode({
          "createEnvironmentFromBlueprint": {}
        })}'
    EOT
  }

  triggers = {
    domain_id = local.domain_id
  }
}
