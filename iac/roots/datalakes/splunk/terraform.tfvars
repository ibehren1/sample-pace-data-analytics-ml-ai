// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

AWS_ACCOUNT_ID                = "###AWS_ACCOUNT_ID###"
APP                           = "###APP_NAME###"
ENV                           = "###ENV_NAME###"
AWS_PRIMARY_REGION            = "###AWS_PRIMARY_REGION###"
AWS_SECONDARY_REGION          = "###AWS_SECONDARY_REGION###"
S3_PRIMARY_KMS_KEY_ALIAS      = "###APP_NAME###-###ENV_NAME###-s3-secret-key"
S3_SECONDARY_KMS_KEY_ALIAS    = "###APP_NAME###-###ENV_NAME###-s3-secret-key"
GLUE_ROLE_NAME                = "###APP_NAME###-###ENV_NAME###-glue-role"
SPLUNK_EC2_PROFILE_NAME       = "###APP_NAME###-###ENV_NAME###-splunk-profile"
SPLUNK_ICEBERG_BUCKET         = "s3://###APP_NAME###-###ENV_NAME###-splunk-iceberg-primary/"
GLUE_SPARK_LOGS_BUCKET        = "s3://###APP_NAME###-###ENV_NAME###-glue-spark-logs-primary/"
GLUE_TEMP_BUCKET              = "s3://###APP_NAME###-###ENV_NAME###-glue-temp-primary/"
GLUE_KMS_KEY_ALIAS            = "###APP_NAME###-###ENV_NAME###-glue-secret-key"
CLOUDWATCH_KMS_KEY_ALIAS      = "###APP_NAME###-###ENV_NAME###-cloudwatch-secret-key"
SECRETS_MANAGER_KMS_KEY_ALIAS = "###APP_NAME###-###ENV_NAME###-secrets-manager-secret-key"
GLUE_SCRIPTS_BUCKET_NAME      = "###APP_NAME###-###ENV_NAME###-glue-scripts-primary"
EBS_KMS_KEY_ALIAS             = "###APP_NAME###-###ENV_NAME###-ebs-secret-key"

