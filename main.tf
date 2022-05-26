terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.27"
        }
    }

    required_version = ">= 1.1.0"
}

provider "aws" {
    profile = "default"
    region  = "us-east-1"
}

resource "aws_instance" "my_app" {
    ami = var.ami
    instance_type = "t2.micro"

    tags = {
        Curso = "${var.curso}"
        Periodo = "${var.periodo}o Periodo"
        Aluno = "${var.nome}"
    }
}
