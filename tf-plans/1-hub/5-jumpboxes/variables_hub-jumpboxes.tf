#--------------------------------------------------------------
#   Terraform Variables Declarations
#--------------------------------------------------------------
#   / Hub Jumpboxes
#--------------------------------------------------------------
variable hub_vms_base_name            {}

# Windows VM settings
variable deploy_win_vm                    { type = bool }
variable win_vm_enable_publicip           { type = bool }
variable win_vm_allowed_internetip_to_rdp { default = null }

variable win_vm_size                  {}
variable win_vm_offer                 {}  #"WindowsServer",
variable win_vm_publisher             {}  #"MicrosoftWindowsServer",
variable win_vm_sku                   {}  #"2019-Datacenter",
variable win_vm_version               {}  #"latest"

# Linux VM settings