variable "cluster_name" {}
variable "cluster_version" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "environment" {}
variable "region" { default = "eu-north-1" }
