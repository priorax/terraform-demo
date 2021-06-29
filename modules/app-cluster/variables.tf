variable "env_number" {
  type = string
}

variable "private_subnet" { 
    type    = string
}

variable "target_group_arn" {
  type = string
}

variable "albSg" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "wait_conditions" {
  type = list(string)
}