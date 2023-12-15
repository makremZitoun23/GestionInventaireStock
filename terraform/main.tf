variable "data" {

    type = string
    default = "Testing Terraform"
}

output "returnCode" {
  value = var.data
}