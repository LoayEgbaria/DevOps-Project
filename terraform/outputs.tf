output "vpc_id" {
  value = aws_vpc.main.id
}

output "k8s_master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}

output "k8s_master_private_ip" {
  value = aws_instance.k8s_master.private_ip
}

output "k8s_worker_public_ips" {
  value = aws_instance.k8s_workers[*].public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.main.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.s3_processor.function_name
}

output "api_gateway_url" {
  value = "${aws_api_gateway_stage.prod.invoke_url}/events"
}

output "ssh_command_master" {
  value = "ssh -i MyKey.pem ec2-user@${aws_instance.k8s_master.public_ip}"
}