// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "null_resource" "create_domain_output" {

  depends_on = [null_resource.create_smus_domain]

  provisioner "local-exec" {
    command = <<-EOT
      aws datazone get-domain \
        --identifier "${local.domain_id}" \
        --output json > get_domain_output.json.out
    EOT
  }
}

# Read the get domain output file
data "local_file" "get_domain_output" {
  
  depends_on = [null_resource.create_domain_output]
  filename   = "get_domain_output.json.out"
}

locals {
  root_domain_unit_id = jsondecode(data.local_file.get_domain_output.content).rootDomainUnitId
}
