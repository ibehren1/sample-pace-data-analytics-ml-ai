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


variable "PROJECT_CONSUMER_NAME" {

  type = string
}

variable "PROJECT_CONSUMER_DESCRIPTION" {

  type = string
}


variable "PROJECT_GLOSSARY" {

  type = list(string)
}


variable "CONSUMER_PROFILE_NAME" {

  type = string
}


variable "CONSUMER_PROFILE_DESCRIPTION" {

  type = string
}

variable "CONSUMER_ENV_NAME" {

  type = string
}



