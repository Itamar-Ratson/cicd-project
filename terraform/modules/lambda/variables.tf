variable "function_name" {}
variable "ecr_uri" {}
variable "environment" {}
variable "environment_variables" {
  type    = map(string)
  default = {}
}
