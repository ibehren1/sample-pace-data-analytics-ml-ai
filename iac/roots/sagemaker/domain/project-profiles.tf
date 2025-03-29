// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  # For each profile object in var.project_profiles, get the environmentConfigurations attribute which is a list. Iterate through the environmentConfigurations, and override the awsAccountId and regionName attributes
  project_profiles = [
    for profile in var.project_profiles : {
      name = profile.name
      description = profile.description
      status = profile.status

      environmentConfigurations = [
        for environmentConfig in profile.environmentConfigurations : merge(
        {
          deploymentMode = environmentConfig.deploymentMode
          name = environmentConfig.name
          description = environmentConfig.description
          environmentBlueprintId = environmentConfig.environmentBlueprintId
          awsAccount = {
            awsAccountId = local.account_id
          }
          awsRegion = {
            regionName = local.region
          }
          configurationParameters = merge({
            resolvedParameters = [
              for param in environmentConfig.configurationParameters.resolvedParameters: merge({
                isEditable = param.isEditable
                name = param.name
              }, param.value != null ? { value = param.value } : {})
            ]
          }, environmentConfig.configurationParameters.parameterOverrides != null ? {
              parameterOverrides = [
                for param in environmentConfig.configurationParameters.parameterOverrides: merge({
                  isEditable = param.isEditable
                  name = param.name
                }, param.value != null ? { value = param.value } : {})
              ]
            } : {}
          )
          description = environmentConfig.description
        },
        environmentConfig.deploymentOrder != null && can(tonumber(environmentConfig.deploymentOrder)) ? {
          deploymentOrder = environmentConfig.deploymentOrder
        } : {}
      )
    ]
  }]
}

# Create Project Profiles
resource "null_resource" "create_project_profile" {

  for_each = { for idx, profile in local.project_profiles : idx => profile }

  triggers = {
    domain_id = local.domain_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws datazone create-project-profile \
        --domain-identifier ${local.domain_id} \
        --name "${each.value.name}" \
        --description "${each.value.description}" \
        --environment-configurations '${jsonencode(each.value.environmentConfigurations)}' \
        --status "${each.value.status}" \
        --region "${local.region}" \
        --output json \
        --query '{id:id, name:name}' > create_project_profile_output_${each.key}.txt.out
    EOT
  } 
}

# Collect the output from each 'create_project-profile' call
data "local_file" "create_project_profile_results" {

  count       = length(local.project_profiles)
  depends_on  = [ null_resource.create_project_profile ]

  filename = "create_project_profile_output_${count.index}.txt.out"
}

# Each file contains output in this format
# {
#    "id": "3t63mukn4n5dev",
#    "name": "SQL analytics"
# }
#
locals {

  profile_names = [
    for result in data.local_file.create_project_profile_results : jsondecode(result.content).name
  ]

  # Create an array of profile IDs
  profile_ids = [
    for result in data.local_file.create_project_profile_results : jsondecode(result.content).id
  ]
}

# Save each profile_name -> profile_id mapping to SSM parameter store
resource "aws_ssm_parameter" "smus_project_profile_ids" {

  count       = length(local.profile_names)
  name 		    = "/${var.APP}/${var.ENV}/project_profile_${count.index + 1}"
  value       = "${local.profile_ids[count.index]}:${local.profile_names[count.index]}"  
  type        = "SecureString"
  key_id      = data.aws_kms_key.ssm_kms_key.key_id

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage = "SMUS Domain"
  }
}

# Grant access to all the Identity Center users on all the newly created project profiles
resource "null_resource" "project_profile_policy_grants" {
  
  depends_on = [ null_resource.create_project_profile ]

  provisioner "local-exec" {
    command = <<-EOT
      aws datazone add-policy-grant \
        --domain-identifier "${local.domain_id}" \
        --entity-identifier "${local.root_domain_unit_id}" \
        --entity-type "DOMAIN_UNIT" \
        --policy-type "CREATE_PROJECT_FROM_PROJECT_PROFILE" \
        --principal '${jsonencode({
          "user": {
            "allUsersGrantFilter": {}
          }
        })}' \
        --detail '${jsonencode({
          "createProjectFromProjectProfile": {
            "projectProfiles": local.profile_ids,
          }
        })}'
    EOT
  }

  triggers = {
    domain_id = local.domain_id
  }
}
