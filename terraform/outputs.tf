output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "k8s_master_public_ip" {
  description = "Public IP of Kubernetes master node"
  value       = aws_instance.k8s_master.public_ip
}

output "k8s_master_private_ip" {
  description = "Private IP of Kubernetes master node"
  value       = aws_instance.k8s_master.private_ip
}

output "k8s_worker_public_ips" {
  description = "Public IPs of Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.s3_processor.function_name
}

output "api_gateway_url" {
  description = "URL of the API Gateway endpoint"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/events"
}

output "elasticsearch_url" {
  description = "URL for Elasticsearch (after installation)"
  value       = "http://${aws_instance.k8s_master.public_ip}:9200"
}

output "kibana_url" {
  description = "URL for Kibana (after installation)"
  value       = "http://${aws_instance.k8s_master.public_ip}:5601"
}

output "ssh_command_master" {
  description = "SSH command to connect to master node"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.k8s_master.public_ip}"
}

output "ssh_command_worker1" {
  description = "SSH command to connect to worker node 1"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.k8s_workers[0].public_ip}"
}

output "ssh_command_worker2" {
  description = "SSH command to connect to worker node 2"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.k8s_workers[1].public_ip}"
}