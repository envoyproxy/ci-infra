variable "ami_prefix" { type = string }
variable "aws_account_id" { type = string }
variable "azp_pool_name" { type = string }
variable "azp_token" { type = string }
variable "disk_size_gb" {
  type = number
  default = 100
}
variable "disk_iops" {
  type = number
  default = 9000
}
variable "disk_throughput" {
  type = number
  default = 1000
}
variable "disk_volume_type" {
  type = string
  default = "gp3"
}
variable "on_demand_instances_count" {
  type    = number
  default = 0
}
variable "idle_instances_count" { type = number }
variable "instance_types" { type = list(string) }
