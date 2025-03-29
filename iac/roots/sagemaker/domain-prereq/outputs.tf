// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

output "vpc_id" {

  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {

  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {

  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {

  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {

  description = "The CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "nat_gateway_id" {

  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_eip" {

  description = "The Elastic IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "internet_gateway_id" {
  
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# output "smus_domain_execution_role_arn" {
#   description = "ARN of the SMUS domain execution role"
#   value       = aws_iam_role.smus_domain_execution_role.arn
# }

# output "smus_domain_service_role_arn" {
#   description = "ARN of the SMUS domain service role"
#   value       = aws_iam_role.smus_domain_service_role.arn
# }

# output "smus_domain_provisioning_role_arn" {
#   description = "ARN of the SMUS domain provisioning role"
#   value       = aws_iam_role.smus_sm_provisioning_role.arn
# }

# output "availability_zone_names" {
#   description = "The names of the availability zones"
#   value       = aws_subnet.private[*].availability_zone
# }

# output "project_bucket_s3_url" {
#   description = "The S3 URL of the project bucket"
#   value       = "s3://${aws_s3_bucket.projects_bucket.bucket}"
# }
