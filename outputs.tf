output "instance_id" {
    value = aws_instance.my_app.id
}

output "instance_public_ip" {
    value = aws_instance.my_app.public_ip
}

output "rds_endpoint" {
    value = aws_db_instance.default.endpoint
}
