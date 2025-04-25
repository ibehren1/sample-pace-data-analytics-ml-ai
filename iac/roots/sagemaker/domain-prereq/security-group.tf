// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_security_group" "sagemaker" {

  name        = "sagemaker-unified-studio-vpc-endpoint"
  description = "Security group for SageMaker Unified Studio VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allows outbound HTTPS access to any IPv4 address"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allows inbound HTTPS access for traffic from VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name                                    = "sagemaker-unified-studio-vpc-endpoint"
    CreatedForUseWithSageMakerUnifiedStudio = true
    Application                             = var.APP
    Environment                             = var.ENV
  }
  #checkov:skip=CKV2_AWS_5: "Ensure that Security Groups are attached to another resource": "Skipping this the security group is already attached to the VPC"
}
