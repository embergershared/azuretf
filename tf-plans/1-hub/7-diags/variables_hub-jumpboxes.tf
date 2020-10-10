#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Hub Jumpboxes
#--------------------------------------------------------------
variable hub_vms_base_name            {}
variable internetip_allowed_toconnect { default = null }

# Windows VM settings
variable win_vm_size                  {}
variable win_vm_publisher             {}
variable win_vm_offer                 {}
variable win_vm_sku                   {}
variable win_vm_version               {}
variable win_admin_user               {}
variable win_admin_pwd                {}

# Linux VM settings