#--------------------------------------------------------------
#   Backend TF State, Specific Locals
#--------------------------------------------------------------
# terraform {
#   backend azurerm {
#     subscription_id      = ""
#     resource_group_name  = ""
#     storage_account_name = ""
#     container_name       = "tfstates-demo-hub"
#     key                  = "1-terraform"
#   }
# }

locals {
  tf_values = "/subscriptions/demo/1-hub/1-terraform"
  tf_state  = "tfstates-demo-hub/1-terraform"
}