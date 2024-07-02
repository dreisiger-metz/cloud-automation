# ============================================================================
# This code-snippet is provided without warranty, as an example of how to per-
# form certain maintenance tasks or operations.
# 
# While every effort has been made to ensure that the information and/or code
# contained herein is current and works as intended, it has not been through 
# any formal or rigorous testing process, and therefore should be used at your
# own discretion. For definitive information and documentation, please refer
# to docs.ionos.com/cloud
#
# Author: Peter Metz
#
#
# A far-from-elegant example of how one might call the CloudAPI directly
# from within a TF file to ensure that a 'VDC + contained resources' prov-
# isioning can either be provisioned 'atomically', or will fail quickly
#
# To specify a target location, you would run something like:
#
#   terraform apply -var='PROVISIONING_LOCATION=fr/par'
#
# Also there are many other things which would need to be 'fleshed out' before
# this minimal snippet could be used in production --- aside from the points
# mentioned at the end of this file, you would also need to make sure that
# data.http.create_datacenter gets 're-evaluated' each time this file is
# reapplied, plus you'd also need to decide how best this example project 
# could be called from another script / TF project (e.g. to cycle through
# different regions), only continuing if this project could be successfully
# provisioned, etc., etc.
# ============================================================================
terraform {
    required_providers {
        ionoscloud = {
            source = "ionos-cloud/ionoscloud"
            version = ">= 6.4.17"
        }
    }
}



# Declarations for a couple of 'imported' input variables that would either
# be specified via, e.g., the TF_VAR_IONOS_TOKEN environment variable, or via
# using the terraform apply -var="var-value" convention
variable "IONOS_TOKEN" {
}


variable "PROVISIONING_LOCATION" {
    default = "de/txl"
}




# ============================================================================
# Define some basic configuration and template variables
variable "general_config" {
    default = {
        server_count     = 2
    }
}


variable "server_template" {
    default = {
        cpuFamily   = "INTEL_SKYLAKE"
        cores       = 1
        ram         = 1024
        name_prefix = "Example VM"
    }
}


resource "random_string" "default_password" {
  length  = 16
  special = false
}




# ============================================================================
# Create 'local' config variables, possibly also using list comprehensions...
locals {
    vdc_config = {
        name        = "Atomic Provisioning Example"
        location    = var.PROVISIONING_LOCATION
        description = "Example showing how a VDC plus an arbitrary number of VMs can be provisioned either atomically or not at all..."
    }


    # un-JSON?
    lans_config = [
        {
            "properties": {
                "name": "uplink",
                "public": true
            }
        }
    ]

    servers_config = [ for i in range(var.general_config.server_count) : {
            properties = {
                name             = format("%s %d", var.server_template.name_prefix, i)
                cores            = var.server_template.cores
                cpuFamily        = var.server_template.cpuFamily
                ram              = var.server_template.ram
                type             = "ENTERPRISE"
                availabilityZone = "AUTO"
            }
            entities = {
                volumes = {
                    items = [
                        {
                            properties = {
                                name          = "vda"
                                type          = "HDD"
                                size          = 10
                                imageAlias    = "debian:11"
                                imagePassword = random_string.default_password.result
                                licenceType   = "LINUX"
                            }                
                        }
                    ]
                }
                nics = {
                    items = [
                        {
                            # note that if there's more than one LAN, the ID mappings will likely _not_
                            # be consistent, and might need to be 'cleaned up', afterwards, using 
                            # 'actual' Terraform code
                            properties = {
                                name           = "eth0"
                                lan            = 1
                                ips            = []
                                dhcp           = true
                                firewallActive = false
                                firewallType   = "INGRESS"
                            }                
                        }
                    ]
                }
            }
        }
    ]
}




# ============================================================================
# Generate the 'data' / request body for the composite request based upon the
# above and our template file, and then write it out to a local file 'for 
# inspection', but also send it to the appropriate CloudAPI endpoint
resource "local_file" "vdc_definition" {
    filename = "vdc-definition-data.json"
    content  = templatefile("atomic-provisioning.tpl", {
                            vdc_config = jsonencode(local.vdc_config),
                            lans_config = jsonencode(local.lans_config),
                            servers_config = jsonencode(local.servers_config) })
}


# For local testing, you can run the following on localhost:
# # while true; do { echo -e 'HTTP/1.1 200 OK\r\n'; } | nc -l 80; done
# and change 'https://api.ionos.com' below to 'http://localhost'
data "http" "create_datacenter" {
    url = "https://api.ionos.com/cloudapi/v6/datacenters"
    method = "POST"
    request_headers = {
        accept = "application/json"
        Authorization = "Bearer ${var.IONOS_TOKEN}"
        Content-Type = "application/json"
    }
    request_body = templatefile("atomic-provisioning.tpl", {
                                vdc_config = jsonencode(local.vdc_config),
                                lans_config = jsonencode(local.lans_config),
                                servers_config = jsonencode(local.servers_config) })
}




# ============================================================================
# Next, we need to query data.http.create_datacenter.response_headers.Location
# and wait until metadata.status of its response is DONE. E.g.,
#
# The example local-exec below shows how one might do this in a _one-off_
# way, but the correct bzw. only 'robust' way to do this is to make use of the
# https://api.ionos.com/docs/cloud/v6/#tag/Requests/operation/requestsStatusGet
# endpoint, together with enough minimal code to wait (potentially with some
# kind of 'progressive back-off') until metadata.status either returns DONE
# or failed.
#
# While it'd probably be just as easy to adapt the code, e.g., from 
# https://github.com/ionos-cloud/sdk-python/blob/master/ionoscloud/api_client.py#L773
# another way of doing this could be https://github.com/magodo/terraform-provider-restful/issues/24
# / https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/resource
resource "terraform_data" "create_datacenter_status" {
  provisioner "local-exec" {
    command = "sleep 15 && curl -s -X GET -H 'accept: application/json' -H 'Authorization: Bearer ${var.IONOS_TOKEN}' ${data.http.create_datacenter.response_headers.Location}"
  }
}





# ============================================================================
# Finaly, we need to instantiate one datasource for the VDC, and per resource
# defined in our locals block above (left as an exercise for the reader)
