# DevOps Final Project

## Project Overview

This project implements a cloud-based, event-driven architecture on AWS using Kubernetes, Kafka, and Elasticsearch.

## Architecture
```
API Gateway → Kafka ← Lambda (triggered by S3)
                ↓
        Kafka Consumers (Kubernetes)
                ↓
        Elasticsearch + Kibana
```

### Components

1. **AWS Infrastructure**
   - VPC with public subnets across 2 availability zones
   - 3 EC2 instances (1 master, 2 workers) for Kubernetes
   - S3 bucket for file uploads
   - Lambda function triggered by S3 uploads
   - API Gateway for HTTP event ingestion
   - IAM roles and security groups

2. **Kubernetes Cluster**
   - 1 master node, 2 worker nodes
   - Flannel CNI for pod networking
   - Deployed Kafka consumer applications

3. **Apache Kafka**
   - Running on master node
   - Topics: `api-events`, `s3-events`
   - Consumer group: `consumer-group-1`

4. **Logging Stack**
   - Elasticsearch for log storage
   - Kibana for visualization
   - Index: `kafka-events`

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0
- kubectl
- SSH key pair in AWS

## Deployment Instructions

### 1. Clone and Setup
```bash
git clone <your-repo>
cd devops-final-project
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Note:** This creates:
- VPC and networking components
- 3 EC2 instances
- S3 bucket
- Lambda function
- API Gateway
- IAM roles

### 3. Configure Kubernetes

SSH into the master node:
```bash
ssh -i devops-key.pem ec2-user@<MASTER_PUBLIC_IP>
```

Run installation scripts (see scripts/ directory):
- `install-kubernetes.sh` - Installs K8s on all nodes
- `install-kafka.sh` - Installs Kafka
- `setup-logging.sh` - Installs Elasticsearch and Kibana

Initialize the cluster:
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Join worker nodes using the `kubeadm join` command from the init output.

### 4. Deploy Kafka Consumers
```bash
kubectl apply -f kubernetes/consumer-deployment.yaml
kubectl apply -f kubernetes/kafka-deployment.yaml
```

Verify deployment:
```bash
kubectl get pods
kubectl logs -l app=kafka-consumer
```

### 5. Configure Kafka Topics
```bash
sudo /opt/kafka/bin/kafka-topics.sh --create --topic api-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
sudo /opt/kafka/bin/kafka-topics.sh --create --topic s3-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

### 6. Access Kibana

Open browser: `http://<MASTER_PUBLIC_IP>:5601`

Create index pattern: `kafka-events*`

## Testing

### Test 1: Direct Kafka Message
```bash
echo '{"event":"test","message":"Hello"}' | sudo /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic api-events
```

### Test 2: S3 Upload
```bash
aws s3 cp test-file.txt s3://<BUCKET_NAME>/
```

Check Lambda logs:
```bash
aws logs tail /aws/lambda/devops-final-s3-processor --follow
```

### Test 3: API Gateway
```bash
curl -X POST <API_GATEWAY_URL> -H "Content-Type: application/json" -d '{"event":"api_test"}'
```

## Verification

1. **Kubernetes Pods**: `kubectl get pods` - all should be Running
2. **Kafka Topics**: `sudo /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092`
3. **Elasticsearch**: `curl localhost:9200/_cat/indices`
4. **Kibana Logs**: View in Discover tab with `kafka-events*` index

## Architecture Decisions

### Why Kafka on EC2 instead of MSK?
- Cost optimization for educational project
- More hands-on experience with Kafka administration
- Easier integration with Kubernetes on same instances

### Why Single-Node Elasticsearch?
- Sufficient for project scope
- Reduces resource requirements
- Simplifies deployment

### Why Flannel CNI?
- Lightweight and reliable
- Easy setup for small clusters
- Good performance for our use case

## Assumptions

1. All resources deployed in us-east-1 region
2. Using Amazon Linux 2 for EC2 instances
3. Public subnets used for simplified access (demo environment)
4. Security groups allow necessary traffic
5. Elasticsearch security disabled for simplicity

## Resource Cleanup

To destroy all resources:
```bash
cd terraform
terraform destroy
```

**Warning:** This will delete ALL resources including data in S3 and logs.

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod <POD_NAME>
kubectl logs <POD_NAME>
```

### Kafka Connection Issues
```bash
# Check Kafka is running
sudo systemctl status kafka
# Check Kafka logs
sudo tail -f /opt/kafka/logs/server.log
```

### Elasticsearch Not Accessible
```bash
sudo systemctl status elasticsearch
curl localhost:9200
```

## Project Structure
```
devops-final-project/
├── terraform/          # Infrastructure as Code
├── kubernetes/         # K8s manifests
├── lambda/            # Lambda function code
├── scripts/           # Installation scripts
├── screenshots/       # Project screenshots
└── README.md          # This file
```

## Technologies Used

- **Cloud Provider**: AWS (EC2, VPC, S3, Lambda, API Gateway, IAM)
- **Container Orchestration**: Kubernetes 1.28
- **Message Broker**: Apache Kafka 3.5.1
- **Infrastructure as Code**: Terraform 1.x
- **Logging**: Elasticsearch 8.x + Kibana 8.x
- **Runtime**: Python 3.11 for Lambda and consumers

## Author

Loay Egbaria

DevOps Course Final Project

1/1/2026

## License

This project is for educational purposes only.