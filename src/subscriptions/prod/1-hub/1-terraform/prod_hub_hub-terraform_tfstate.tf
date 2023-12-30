#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
# terraform {
#   backend azurerm {
#     subscription_id      = ""
#     resource_group_name  = ""
#     storage_account_name = ""
#     container_name       = "tfstates-prod-hub"
#     key                  = "1-terraform"
#   }
# }

locals {
  tf_values = "/subscriptions/prod/1-hub/1-terraform"
  tf_state  = "tfstates-prod-hub/1-terraform"
}