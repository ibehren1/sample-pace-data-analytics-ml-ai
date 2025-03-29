// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "ebs_kms_key" {

  key_id = "alias/${var.EBS_KMS_KEY_ALIAS}"
}

data "aws_iam_instance_profile" "splunk_profile" {

  name = var.SPLUNK_EC2_PROFILE_NAME
}

data "aws_ami" "amazon_linux_2" {

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group
resource "aws_security_group" "splunk" {

  name        = "${var.APP}-${var.ENV}-splunk"
  description = "Security group for Splunk instance"
  vpc_id      = local.VPC_ID

  # Allow Glue connection
  ingress {
    from_port       = 8089
    to_port         = 8089
    protocol        = "tcp"
    security_groups = [local.GLUE_SECURITY_GROUP]
    description     = "Splunk management port for Glue"
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All Egress"
  }

  #checkov:skip=CKV_AWS_382: "Ensure no security groups allow egress from 0.0.0.0:0 to port -1": "Skipping this for simplicity"
}

# EC2 Instance with Splunk
resource "aws_instance" "splunk" {

  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.INSTANCE_TYPE

  ebs_optimized = true
  monitoring    = true

  subnet_id                   = local.PRIVATE_SUBNET1_ID
  vpc_security_group_ids      = [aws_security_group.splunk.id]
  iam_instance_profile        = data.aws_iam_instance_profile.splunk_profile.name
  associate_public_ip_address = var.ASSOCIATE_PUBLIC_IP

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = var.ROOT_VOLUME_SIZE
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    splunk_version = var.SPLUNK_VERSION,
    splunk_build   = var.SPLUNK_BUILD,
    aws_region     = var.AWS_PRIMARY_REGION,
    app            = var.APP,
    env            = var.ENV
  })

  tags = {
    Application = var.APP
    Environment = var.ENV
    Name        = "${var.APP}-${var.ENV}-splunk-instance"
    Usage       = "splunk-application"
  }
}

# EBS Volume
resource "aws_ebs_volume" "splunk_data" {

  availability_zone = aws_instance.splunk.availability_zone
  size              = var.DATA_VOLUME_SIZE
  type              = "gp3"
  encrypted         = true

  kms_key_id = data.aws_kms_key.ebs_kms_key.arn

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "splunk-data"
  }
}

resource "aws_volume_attachment" "splunk_data_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.splunk_data.id
  instance_id = aws_instance.splunk.id
}
