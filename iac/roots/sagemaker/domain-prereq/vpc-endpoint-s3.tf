// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

# VPC Endpoint for S3 
resource "aws_vpc_endpoint" "s3" {

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private.*.id
  
  tags = {
    Name = "sagemaker-unified-studio-s3-endpoint"
  }
}
