// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_s3tables_table_bucket" "splunk" {

  name = "${var.APP}-${var.ENV}-splunk"
}

data "aws_iam_policy_document" "splunk_bucket_policy_document" {

  statement {
    sid    = "AllowAthenaAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["athena.amazonaws.com"]
    }

    actions = [
      "s3tables:*"
    ]

    resources = [
      "${aws_s3tables_table_bucket.splunk.arn}/*",
      aws_s3tables_table_bucket.splunk.arn
    ]
  }

  statement {
    sid    = "AllowGlueAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }

    actions = [
      "s3tables:*"
    ]

    resources = [
      "${aws_s3tables_table_bucket.splunk.arn}/*",
      aws_s3tables_table_bucket.splunk.arn
    ]
  }
}

resource "aws_s3tables_table_bucket_policy" "splunk_policy" {

  resource_policy  = data.aws_iam_policy_document.splunk_bucket_policy_document.json
  table_bucket_arn = aws_s3tables_table_bucket.splunk.arn
}
