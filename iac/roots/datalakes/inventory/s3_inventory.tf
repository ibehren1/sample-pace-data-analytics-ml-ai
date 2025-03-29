// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_kms_key" "s3_primary_key" {

  provider = aws.primary
  key_id   = "alias/${var.S3_PRIMARY_KMS_KEY_ALIAS}"
}

data "aws_kms_key" "s3_secondary_key" {

  provider = aws.secondary
  key_id   = "alias/${var.S3_SECONDARY_KMS_KEY_ALIAS}"
}

data "aws_iam_policy_document" "inventory_policy" {

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]

    resources = ["${module.inventory_data_destination_bucket.primary_bucket_arn}/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        module.inventory_data_source_bucket.primary_bucket_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values = [
        "bucket-owner-full-control"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.AWS_ACCOUNT_ID]
    }
  }
}

resource "aws_s3_bucket_policy" "inventory_policy" {

  bucket = module.inventory_data_destination_bucket.primary_bucket_id
  policy = data.aws_iam_policy_document.inventory_policy.json
}

resource "aws_s3_bucket_inventory" "source_inventory" {

  bucket = var.INVENTORY_DATA_SOURCE_BUCKET_NAME
  name   = "InventoryConfig"

  included_object_versions = "All"

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = module.inventory_data_destination_bucket.primary_bucket_arn
      account_id = var.AWS_ACCOUNT_ID
      encryption {
        sse_kms {
          key_id = data.aws_kms_key.s3_primary_key.arn
        }
      }
    }
  }

  optional_fields = [
    "Size",
    "LastModifiedDate",
    "StorageClass",
    "ETag",
    "IsMultipartUploaded",
    "ReplicationStatus",
    "EncryptionStatus",
    "ObjectLockRetainUntilDate",
    "ObjectLockMode",
    "ObjectLockLegalHoldStatus",
    "IntelligentTieringAccessTier",
    "BucketKeyStatus",
    "ChecksumAlgorithm",
    "ObjectOwner"
  ]
} 
