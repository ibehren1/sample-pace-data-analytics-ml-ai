// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  az_name = data.aws_availability_zones.available.names[0]
}

# Public subnet
resource "aws_subnet" "public" {

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.38.224.0/21"
  availability_zone = local.az_name

  map_public_ip_on_launch = true

  tags = {
    Name                                     = "sagemaker-unified-studio-public-subnet"
    CreatedForUseWithSageMakerUnifiedStudio  = true
    for-use-with-amazon-emr-managed-policies = true
    Application                              = var.APP
    Environment                              = var.ENV
  }
  #checkov:skip=CKV_AWS_130: "Ensure VPC subnets do not assign public IP by default":"Skipping this finding as this subnet is intended to be a public one with an IGW attached to it"
}

# Internet Gateway
resource "aws_internet_gateway" "main" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "sagemaker-unified-studio-igw"
    Application = var.APP
    Environment = var.ENV
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "sagemaker-unified-studio-public-rt"
    Application = var.APP
    Environment = var.ENV
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {

  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
