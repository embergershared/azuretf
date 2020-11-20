# Description   : This Terraform module generates a short location code from azure location string.
#
# Folder/File   : /modules/shortloc/main.tf
# Variables     : none
# Terraform     : 0.13.+
# Providers     : none
# Plugins       : none
# Modules       : none
#
# Created on    : 2020-09-11
# Created by    : Emmanuel
# Last Modified :
# Last Modif by :
# Modif desc.   :

#--------------------------------------------------------------
#   Short location codes
#--------------------------------------------------------------
locals {
  name = lower(var.location)
  # Short Location codes
  short_location  = lookup({
    canadacentral   = "cac",
    canadaeast      = "cae",
    eastus          = "use",
    },
    local.name, "")
}