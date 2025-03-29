resource "aws_quicksight_account_subscription" "quicksight" {
  account_name          = var.ACCOUNT_NAME
  authentication_method = "IAM_AND_QUICKSIGHT"
  edition               = "ENTERPRISE"
  notification_email    = var.EMAIL
}