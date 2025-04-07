// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "APP" {

  type = string
}

variable "ENV" {

  type = string
}

variable "AWS_PRIMARY_REGION" {

  type = string
}

variable "AWS_SECONDARY_REGION" {

  type = string
}

variable "DOMAIN_NAME" {

  type = string
}


variable "SSM_KMS_KEY_ALIAS" {

  type = string
}


variable "PROJECT_PRODUCER_NAME" {

  type = string
}

variable "PROJECT_PRODUCER_DESCRIPTION" {

  type = string
}

variable "PROJECT_GLOSSARY" {

  type = list(string)
}

variable "PRODUCER_PROFILE_NAME" {

  type = string
}

variable "PRODUCER_PROFILE_DESCRIPTION" {

  type = string
}

variable "PRODUCER_ENV_NAME" {

  type = string
}


variable "DATASOURCE_NAME" {

  type = string
}

variable "DATASOURCE_TYPE" {

  type = string
}

variable "GLUE_DATASOURCE_CONFIGURATION" {
  type = any
  
}

