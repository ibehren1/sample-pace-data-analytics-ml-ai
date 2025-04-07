// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

APP                             = "###APP_NAME###"
ENV                             = "###ENV_NAME###"
AWS_PRIMARY_REGION              = "###AWS_PRIMARY_REGION###"
AWS_SECONDARY_REGION            = "###AWS_SECONDARY_REGION###"
SSM_KMS_KEY_ALIAS               = "###APP_NAME###-###ENV_NAME###-systems-manager-secret-key"
DOMAIN_NAME                     = "Exchange"

PROJECT_PRODUCER_NAME           = "Producer"
PROJECT_PRODUCER_DESCRIPTION    = "Data Producer Project"

PROJECT_CONSUMER_NAME           = "Consumer"
PROJECT_CONSUMER_DESCRIPTION    = "Data Consumer Project"

PRODUCER_PROFILE_NAME           = "producer_datalake_profile"
CONSUMER_PROFILE_NAME           = "consumer_datalake_profile"

PROJECT_GLOSSARY                = ["term1", "term2"]
PROJECT_BLUEPRINT               = "DefaultDataLake"
PROFILE_DSCRIPTION              = "Datalake profile"
PRODUCER_ENV_NAME               = "producer_env"
CONSUMER_ENV_NAME               = "consumer_env"

CUSTOM_PROJECT_NAME             = "Custom"
CUSTOM_PROJECT_DESCRIPTION      = "Custom project"
CUSTOM_ENV_NAME                 = "custom_env"

CUSTOM_RESOURCE_LINKS            = {
    s3_resource = {
        description = "S3 Resource"
        link = "https://us-east-1.console.aws.amazon.com/s3/buckets/###APP_NAME###-###ENV_NAME###-data-billing-primary"
    }
    glue_resource = {
        description = "Glue Resource"
        link = "https://us-east-1.console.aws.amazon.com/glue/home?region=us-east-1#/v2/data-catalog/tables"
    }
}


DATASOURCE_NAME = "custom_glue_data"
DATASOURCE_TYPE = "GLUE"

CUSTOM_DS_NAME  = "custom_glue_data"

GLUE_DATASOURCE_CONFIGURATION = {
    glue_run_configuration = {
        auto_import_data_quality_result = true
        relational_filter_configurations = [{
            database_name = "###APP_NAME###_###ENV_NAME###_billing"
            filter_expression = [{
                expression = "*"
                type = "INCLUDE"
            }]
        }]
    }
}



