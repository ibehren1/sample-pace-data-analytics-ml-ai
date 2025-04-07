// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  # Parse the JSON string from SSM Parameter Store
  json_data = jsondecode(local.SMUS_DOMAIN_USER_MAPPINGS)
  
  # Extract user IDs using nested for expressions
  user_ids = flatten([
    for domain, groups in local.json_data : [
      for group, users in groups : [
        for user in users : [
          for email, id in user : id
        ]
      ]
    ]
  ])

  # Extract only Domain Owner ID
  domain_owner_ids = flatten([
    for domain, groups in local.json_data : [
      for user in groups["Domain Owner"] : [
        for email, id in user : id
      ]
    ]
  ])  # Taking all the Domain Owner IDs
}  

# Add existing Identity Center users to Datazone domain as users
resource "awscc_datazone_user_profile" "domain_user" {

    for_each = toset(nonsensitive(local.user_ids))

    depends_on = [ null_resource.create_smus_domain ]
    domain_identifier = local.domain_id
    user_identifier   = each.value
    user_type = "SSO_USER"
    status = "ASSIGNED"
    
}

# Add 10 second delay before triggering "null_resource.add_root_owners"
resource "time_sleep" "wait_10_seconds" {
  depends_on = [ awscc_datazone_user_profile.domain_user ]
  create_duration = "10s"
}

resource "null_resource" "add_root_owners" {
  depends_on = [ time_sleep.wait_10_seconds ]
  for_each = toset(nonsensitive(local.domain_owner_ids))

  triggers = {
    domain_id = local.domain_id
    user_id   = each.value
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws datazone add-entity-owner \
        --domain-identifier ${local.domain_id} \
        --entity-type DOMAIN_UNIT \
        --entity-identifier ${local.root_domain_unit_id} \
        --owner '{"user": {"userIdentifier": "${each.value}"}}'
    EOF
  }
}