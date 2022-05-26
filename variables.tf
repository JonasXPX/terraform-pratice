variable "curso" {
    type        = string
    description = "Nome do curso"
}

variable "nome" {
    type        = string
    description = "Nome do academico"
}

variable "periodo" {
    type        = number
    description = "Periodo do curso"
}

variable "ami" {
    type = string
    default = "ami-09d56f8956ab235b3"
}