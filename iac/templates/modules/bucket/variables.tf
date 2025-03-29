// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "RESOURCE_PREFIX" {

  type = string
}

variable "BUCKET_NAME_PRIMARY_REGION" {

  type = string
}

variable "BUCKET_NAME_SECONDARY_REGION" {

  type = string
}

variable "PRIMARY_CMK_ARN" {

  type = string
}

variable "SECONDARY_CMK_ARN" {

  type = string
}

variable "APP" {

  type = string
}

variable "ENV" {

  type = string
}

variable "USAGE" {

  type = string
}
