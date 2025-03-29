// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_iam_role" "lambda_trigger_role" {

  name = "${var.APP}-${var.ENV}-lambda-inventory-trigger-role"
}

resource "aws_sns_topic" "lambda_sns_topic" {

  name              = "${var.APP}-${var.ENV}-inventory-lambda-topic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_lambda_function" "inventory_workflow_trigger" {

  function_name    = "${var.APP}-${var.ENV}-inventory-workflow-trigger"
  filename         = data.archive_file.inventory_workflow_trigger.output_path
  source_code_hash = data.archive_file.inventory_workflow_trigger.output_base64sha256
  handler          = "inventory_workflow_trigger.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128
  role             = data.aws_iam_role.lambda_trigger_role.arn

  reserved_concurrent_executions = 10

  kms_key_arn = data.aws_kms_key.glue_kms_key.arn

  environment {
    variables = {
      GLUE_WORKFLOW_NAME = aws_glue_workflow.inventory_workflow.name
      CRAWLER_NAME       = aws_glue_crawler.inventory_crawler.name
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sns_topic.lambda_sns_topic.arn
  }

  tags = {
    Application = var.APP
    Environment = var.ENV
    Usage       = "inventory"
  }

  depends_on = [data.archive_file.inventory_workflow_trigger]

  #checkov:skip=CKV_AWS_117: "Ensure that AWS Lambda function is configured inside a VPC": "It is not configured inside VPC as it is not using VPC resources."
  #checkov:skip=CKV_AWS_272: "Ensure AWS Lambda function is configured to validate code-signing": "As lambda uses code artifacts containing code that is part of the project, this check is skipped."
}

data "archive_file" "inventory_workflow_trigger" {

  type        = "zip"
  source_file = "${path.module}/inventory_workflow_trigger.py"
  output_path = "${path.module}/lambda_inventory_workflow_trigger.zip"
}

resource "aws_lambda_permission" "allow_s3_invoke" {

  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_workflow_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.INVENTORY_DATA_DESTINATION_BUCKET_NAME}"
}

