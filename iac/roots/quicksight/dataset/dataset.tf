// Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "external" "quicksight_user" {
  program = ["bash", "-c", "aws quicksight list-users --aws-account-id ${data.aws_caller_identity.current.account_id} --namespace default --region ${var.AWS_PRIMARY_REGION} --query 'UserList[0].Arn' --output text | jq -R '{arn: .}'"]
}

resource "aws_lakeformation_permissions" "quicksight_service_role_permissions" {
  principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.QUICKSIGHT_ROLE}"

  for_each = { for idx, table in local.tables : idx => table }

  table {
    database_name = each.value.database
    name          = each.value.name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  permissions                   = ["ALL"]
  permissions_with_grant_option = ["ALL"]
}

resource "aws_lakeformation_permissions" "quicksight_user_permissions" {
  principal = data.external.quicksight_user.result.arn

  for_each = { for idx, table in local.tables : idx => table }

  table {
    database_name = each.value.database
    name          = each.value.name
    catalog_id    = data.aws_caller_identity.current.account_id
  }

  permissions                   = ["ALL"]
  permissions_with_grant_option = ["ALL"]

  depends_on = [
    aws_lakeformation_permissions.quicksight_service_role_permissions
  ]
}

resource "aws_quicksight_data_source" "athena_datasource" {
  aws_account_id  = data.aws_caller_identity.current.account_id
  data_source_id  = "athena-datasource"
  name            = "Athena DataSource"
  type            = "ATHENA"

  parameters {
    athena {
      work_group = var.WORKGROUP_NAME
    }
  }

  permission {
    actions    = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
    principal = data.external.quicksight_user.result.arn
  }
}

resource "aws_quicksight_data_set" "all_dataset" {
  for_each = { for table in local.all_tables : table.id => table }

  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "${var.APP}-${each.key}-dataset"
  name           = "${var.APP}-${each.key}-dataset"
  import_mode    = "DIRECT_QUERY"
  physical_table_map {
    physical_table_map_id = each.key
    custom_sql {
      data_source_arn = aws_quicksight_data_source.athena_datasource.arn
      name            = each.value.name
      sql_query       = each.value.sql_query

      dynamic "columns" {
        for_each = each.value.columns
        content {
          name = columns.value.name
          type = columns.value.type
        }
      }
    }
  }

  permissions {
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:ListIngestions",
      "quicksight:DescribeIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
    principal = data.external.quicksight_user.result.arn
  }
}

resource "aws_quicksight_data_set" "custom_query_dataset" {
  aws_account_id = data.aws_caller_identity.current.account_id
  data_set_id    = "${var.APP}-${local.custom_query_table.id}-dataset"
  name           = "${var.APP}-${local.custom_query_table.name}-dataset"
  import_mode    = "DIRECT_QUERY"
  physical_table_map {
    physical_table_map_id = local.custom_query_table.id
    custom_sql {
      data_source_arn = aws_quicksight_data_source.athena_datasource.arn
      name            = local.custom_query_table.name
      sql_query       = local.custom_query_table.sql_query

      dynamic "columns" {
        for_each = local.billing_converted_columns
        content {
          name = columns.key
          type = columns.value
        }
      }
    }
  }
  permissions {
    actions = [
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:PassDataSet",
      "quicksight:UpdateDataSet",
      "quicksight:DeleteDataSet",
      "quicksight:CreateIngestion",
      "quicksight:ListIngestions",
      "quicksight:DescribeIngestion",
      "quicksight:CancelIngestion",
      "quicksight:UpdateDataSetPermissions"
    ]
    principal = data.external.quicksight_user.result.arn
  }
}



# Dashboard using billing converted hive table
# NOTE: When re-deploying the dashboard with new change
# either deleted the previous one on QS console to avoid cache issue
# or change the name of the new dashboard before deployment
resource "aws_quicksight_dashboard" "billing_dashboard" {
  aws_account_id       = data.aws_caller_identity.current.account_id
  dashboard_id         = "${var.APP}_${var.ENV}_billing_dashboard"
  name                 = "${var.APP}_${var.ENV}_Billing_Dashboard"
  version_description  = "1.0"

  definition {
    data_set_identifiers_declarations {
      data_set_arn = aws_quicksight_data_set.custom_query_dataset.arn
      identifier   = "billing-custom-dashboard"
    }

    sheets {
      sheet_id = "Sheet1"
      name     = "Billing Overview"


      visuals {
        line_chart_visual {
          visual_id = "CostTrendLine"
          title {
            format_text {
              plain_text = "Cost Over Time by Service"
            }
          }
          chart_configuration {
            field_wells {
              line_chart_aggregated_field_wells {
                category {
                  date_dimension_field {
                    column {
                      column_name         = "line_item_usage_end_date"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_usage_end_date"
                  }
                }
                values {
                  numerical_measure_field {
                    column {
                      column_name         = "line_item_unblended_cost"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_unblended_cost"
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
                colors {
                  categorical_dimension_field {
                    column {
                      column_name         = "product_service_name"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "product_service_name"
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        pie_chart_visual {
          visual_id = "AccountDistribution"
          title {
            format_text {
              plain_text = "Cost Distribution by Account"
            }
          }
          chart_configuration {
            field_wells {
              pie_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    column {
                      column_name         = "line_item_usage_account_id"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_usage_account_id"
                  }
                }
                values {
                  numerical_measure_field {
                    column {
                      column_name         = "line_item_unblended_cost"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_unblended_cost"
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }
          }
        }
      }

      visuals {
        bar_chart_visual {
          visual_id = "TopUsageAmount"
          title {
            format_text {
              plain_text = "Top Usage Amount by Bill Buyer"
            }
          }
          chart_configuration {
            field_wells {
              bar_chart_aggregated_field_wells {
                category {
                  categorical_dimension_field {
                    column {
                      column_name         = "bill_payer_account_id"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "bill_payer_account_id"
                  }
                }
                values {
                  numerical_measure_field {
                    column {
                      column_name         = "line_item_usage_amount"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_usage_amount"
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }
            sort_configuration {
              category_sort {
                field_sort {
                  field_id  = "line_item_usage_amount"
                  direction = "DESC"
                }
              }
            }
          }
        }
      }

      visuals {
        table_visual {
          visual_id = "ResourceDetails"
          title {
            format_text {
              plain_text = "Resource Rate Details"
            }
          }
          chart_configuration {
            field_wells {
              table_aggregated_field_wells {
                group_by {
                  categorical_dimension_field {
                    column {
                      column_name         = "line_item_resource_id"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_resource_id"
                  }
                }
                values {
                  numerical_measure_field {
                    column {
                      column_name         = "line_item_unblended_rate"
                      data_set_identifier = "billing-custom-dashboard"
                    }
                    field_id = "line_item_unblended_rate"
                    aggregation_function {
                      simple_numerical_aggregation = "SUM"
                    }
                  }
                }
              }
            }
            sort_configuration {
              row_sort {
                field_sort {
                  field_id  = "line_item_unblended_rate"
                  direction = "DESC"
                }
              }
            }
          }
        }
      }
    }
  }

  permissions {
    actions = [
      "quicksight:DescribeDashboard",
      "quicksight:ListDashboardVersions",
      "quicksight:UpdateDashboardPermissions",
      "quicksight:QueryDashboard",
      "quicksight:UpdateDashboard",
      "quicksight:DeleteDashboard",
      "quicksight:DescribeDashboardPermissions",
      "quicksight:UpdateDashboardPublishedVersion"
    ]
    principal = data.external.quicksight_user.result.arn
  }

  dashboard_publish_options {
    ad_hoc_filtering_option {
      availability_status = "ENABLED"
    }
    export_to_csv_option {
      availability_status = "ENABLED"
    }
    sheet_controls_option {
      visibility_state = "EXPANDED"
    }
  }
}

