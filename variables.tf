variable "ami" {
    type = string
    default = "ami-09d56f8956ab235b3"
}

variable "rds_password" {
    type = string
    description = "password for RDS"
}

variable "rds_username" {
    type = string
    description = "username for RDS"
}

variable "rds_database" {
    type = string
    description = "database name for RDS"
}

variable "pair_key" {
    type = string
    description = "you pair key NAME from AWS EC2"
}