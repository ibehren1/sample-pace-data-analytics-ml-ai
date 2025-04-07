// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "ssm_kms_key" {

  key_id   = "alias/${var.SSM_KMS_KEY_ALIAS}"
}


locals {
  datalake  = "s3://${var.APP}-${var.ENV}-glue-temp-primary"
  domain_id = data.aws_ssm_parameter.datazone_domain_id.value
  json_data = jsondecode(data.aws_ssm_parameter.user_mappings.value)


  # Extract only Domain Owner ID
  domain_owner_ids = flatten([
    for domain, groups in local.json_data : [
      for user in groups["Project Owner"] : [
        for email, id in user : email
      ]
    ]
  ])  # Taking all the Domain Owner IDs
}


# Create Datazone Project for Consumer
module "consumer_project" {

  source = "../../../templates/modules/datazone-project/project"

  APP                       = var.APP
  ENV                       = var.ENV
  KMS_KEY                   = data.aws_kms_key.ssm_kms_key.arn
  USAGE                     = "Datazone"
  domain_id                 = local.domain_id
  project_name              = var.PROJECT_CONSUMER_NAME
  project_owner             = local.domain_owner_ids[0]
  project_description       = var.PROJECT_CONSUMER_DESCRIPTION
  glossary_terms            = var.PROJECT_GLOSSARY

}

# Create Datazone Environment for Consumer Project
module "consumer_project_env" {

  source = "../../../templates/modules/datazone-project/environment"

  APP                       = var.APP
  ENV                       = var.ENV
  KMS_KEY                   = data.aws_kms_key.ssm_kms_key.arn
  USAGE                     = "Datazone"
  domain_id                 = local.domain_id
  project_id                = module.consumer_project.project_id
  region                    = data.aws_region.current.name
  profile_name              = var.CONSUMER_PROFILE_NAME
  env_name                  = var.CONSUMER_ENV_NAME
  profile_description       = var.CONSUMER_PROFILE_DESCRIPTION
  account_id                = data.aws_caller_identity.current.account_id
  environment_blueprint_id  = data.aws_ssm_parameter.datalake_profile_id.value
  depends_on                = [ module.consumer_project ]
}

