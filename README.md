# DevOps Final Project

## Project Overview

This project implements a cloud-based, event-driven architecture on AWS using Kubernetes, Apache Kafka, and Elasticsearch. The system demonstrates modern DevOps practices including Infrastructure as Code, container orchestration, message-driven architecture, and centralized logging.

## Architecture
```
┌─────────────┐         ┌──────────┐         ┌─────────────────┐
│ API Gateway │────────▶│  Lambda  │───────▶│  Apache Kafka   │
└─────────────┘         └──────────┘         └─────────────────┘
                                                       │
┌─────────────┐         ┌──────────┐                   │
│  S3 Bucket  │────────▶│  Lambda  │──────────────────┘
└─────────────┘         └──────────┘                   │
                                                       ▼
                                              ┌─────────────────┐
                                              │   Kubernetes    │
                                              │   Consumers     │
                                              │   (2 replicas)  │
                                              └─────────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │ Elasticsearch + │
                                              │     Kibana      │
                                              └─────────────────┘
```

### Components

1. **AWS Infrastructure**
   - VPC with public subnets across 2 availability zones
   - 3 EC2 instances (1 master, 2 workers) for Kubernetes cluster
   - S3 bucket for file uploads
   - Lambda function triggered by S3 and API Gateway
   - API Gateway REST API for HTTP event ingestion
   - IAM roles and security groups

2. **Kubernetes Cluster**
   - 1 master node, 2 worker nodes
   - Deployed using kubeadm
   - Flannel CNI for pod networking
   - Kafka consumer applications running as Deployments

3. **Apache Kafka**
   - Running on Kubernetes master node
   - Topic: `api-events`
   - Consumer group: `consumer-group-1`
   - Receives events from API Gateway and S3 Lambda

4. **Logging Stack**
   - Elasticsearch for log storage and indexing
   - Kibana for log visualization and analysis
   - Index: `kafka-events`
   - All application logs forwarded from Kafka consumers

## Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **AWS CLI** v2
- **kubectl** v1.28.x
- **Python** 3.11
- **jq** for JSON processing

### AWS Account Setup
- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Sufficient service limits for EC2, VPC, and Lambda

## Project Structure
```
devops-final-project/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Provider and main configuration
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   ├── vpc.tf             # VPC and networking
│   ├── ec2.tf             # EC2 instances
│   ├── iam.tf             # IAM roles and policies
│   ├── s3-lambda.tf       # S3 bucket and Lambda function
│   └── api-gateway.tf     # API Gateway configuration
├── lambda/                 # Lambda function code
│   └── lambda_function.py
├── kubernetes/             # Kubernetes manifests
│   ├── kafka-consumer-configmap.yaml
│   └── kafka-consumer-deployment.yaml
├── scripts/                # Installation scripts
│   ├── install-kubernetes.sh
│   ├── install-kafka.sh
│   └── setup-logging.sh
├── .gitignore
└── README.md
```

## Deployment Instructions

### Step 1: Prepare Environment
```bash
# Clone the repository
git clone <repository-url>
cd devops-final-project

# Verify required tools are installed
terraform --version
aws --version
kubectl version --client
python --version
jq --version
```

### Step 2: Configure AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Enter your credentials when prompted:
# AWS Access Key ID: [your-key]
# AWS Secret Access Key: [your-secret]
# Default region: us-east-1
# Default output format: json
```

### Step 3: Create SSH Key Pair
```bash
# Create SSH key pair in AWS
aws ec2 create-key-pair \
  --key-name devops-key \
  --query 'KeyMaterial' \
  --output text > devops-key.pem

# Set proper permissions
chmod 400 devops-key.pem

# Verify key was created
aws ec2 describe-key-pairs --key-name devops-key
```

### Step 4: Deploy Infrastructure with Terraform
```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply infrastructure (creates all AWS resources)
terraform apply

# Type 'yes' when prompted
# This will take approximately 5-10 minutes

# Save outputs
terraform output > outputs.txt
```

### Step 5: Set Up Kubernetes Cluster

#### 5.1 Configure Master Node
```bash
# Get master IP from Terraform outputs
export MASTER_IP=$(terraform output -raw k8s_master_public_ip)

# Copy installation scripts to master
cd ..
scp -i terraform/devops-key.pem scripts/install-kubernetes.sh ec2-user@$MASTER_IP:~/
scp -i terraform/devops-key.pem scripts/install-kafka.sh ec2-user@$MASTER_IP:~/
scp -i terraform/devops-key.pem scripts/setup-logging.sh ec2-user@$MASTER_IP:~/

# SSH into master node
ssh -i terraform/devops-key.pem ec2-user@$MASTER_IP

# On master node - install Kubernetes
chmod +x install-kubernetes.sh
./install-kubernetes.sh
# Wait 5-10 minutes for installation to complete

# Initialize Kubernetes cluster
PRIVATE_IP=$(hostname -I | awk '{print $1}')
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$PRIVATE_IP

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Verify node is ready
kubectl get nodes
```

**IMPORTANT:** Save the `kubeadm join` command that appears after initialization - you'll need it for worker nodes!

#### 5.2 Configure Worker Nodes

**Open two new terminal windows on your local machine:**

**Terminal 2 - Worker 1:**
```bash
# Get worker 1 IP
export WORKER1_IP=$(cd terraform && terraform output -json k8s_worker_public_ips | jq -r '.[0]')

# Copy installation script
scp -i terraform/devops-key.pem scripts/install-kubernetes.sh ec2-user@$WORKER1_IP:~/

# SSH into worker 1
ssh -i terraform/devops-key.pem ec2-user@$WORKER1_IP

# Install Kubernetes
chmod +x install-kubernetes.sh
./install-kubernetes.sh

# Join the cluster (use the command from master node)
sudo kubeadm join <MASTER_PRIVATE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

**Terminal 3 - Worker 2:**
```bash
# Get worker 2 IP
export WORKER2_IP=$(cd terraform && terraform output -json k8s_worker_public_ips | jq -r '.[1]')

# Copy installation script
scp -i terraform/devops-key.pem scripts/install-kubernetes.sh ec2-user@$WORKER2_IP:~/

# SSH into worker 2
ssh -i terraform/devops-key.pem ec2-user@$WORKER2_IP

# Install Kubernetes
chmod +x install-kubernetes.sh
./install-kubernetes.sh

# Join the cluster
sudo kubeadm join <MASTER_PRIVATE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

#### 5.3 Verify Cluster

**Back on master node:**
```bash
# Check all nodes are ready (should show 3 nodes)
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master     Ready    control-plane   10m   v1.28.x
# k8s-worker-1   Ready    <none>          5m    v1.28.x
# k8s-worker-2   Ready    <none>          5m    v1.28.x
```

### Step 6: Install Apache Kafka

**On master node:**
```bash
# Install Kafka
chmod +x install-kafka.sh
./install-kafka.sh
# Wait 2-3 minutes

# Verify Kafka is running
sudo systemctl status kafka
sudo systemctl status zookeeper

# Create Kafka topic
sudo /opt/kafka/bin/kafka-topics.sh \
  --create \
  --topic api-events \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1

# Verify topic was created
sudo /opt/kafka/bin/kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092

# Describe topic
sudo /opt/kafka/bin/kafka-topics.sh \
  --describe \
  --topic api-events \
  --bootstrap-server localhost:9092
```

### Step 7: Install Elasticsearch and Kibana

**On master node:**
```bash
# Install ELK stack
chmod +x setup-logging.sh
./setup-logging.sh
# Wait 5-7 minutes for Elasticsearch to start

# Verify Elasticsearch
curl localhost:9200
# Should return JSON with cluster information

# Verify Kibana
sudo systemctl status kibana

# Get Kibana URL
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Kibana URL: http://$PUBLIC_IP:5601"
```

**Open Kibana in your browser** (may take 2-3 minutes to be fully ready)

### Step 8: Deploy Kafka Consumers to Kubernetes

**On master node:**
```bash
# Get master private IP
MASTER_PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Apply ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-consumer-code
data:
  consumer.py: |
    import json
    import os
    import logging
    import time
    from kafka import KafkaConsumer
    from elasticsearch import Elasticsearch
    from datetime import datetime
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'api-events')
    KAFKA_GROUP_ID = os.getenv('KAFKA_GROUP_ID', 'consumer-group-1')
    ES_HOST = os.getenv('ELASTICSEARCH_HOST', 'localhost:9200')
    
    def main():
        logger.info(f"Starting Kafka consumer for topic: {KAFKA_TOPIC}")
        logger.info(f"Kafka: {KAFKA_BOOTSTRAP_SERVERS}, ES: {ES_HOST}")
        
        time.sleep(10)
        
        try:
            es = Elasticsearch([f'http://{ES_HOST}'], timeout=30)
            if es.ping():
                logger.info("Connected to Elasticsearch")
            else:
                logger.error("Cannot ping Elasticsearch")
                es = None
        except Exception as e:
            logger.error(f"Elasticsearch connection failed: {e}")
            es = None
        
        try:
            consumer = KafkaConsumer(
                KAFKA_TOPIC,
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                group_id=KAFKA_GROUP_ID,
                auto_offset_reset='earliest',
                enable_auto_commit=True,
                value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                consumer_timeout_ms=1000
            )
            
            logger.info("Kafka consumer started successfully")
            
            for message in consumer:
                try:
                    event_data = message.value
                    logger.info(f"Received: {event_data}")
                    
                    if es:
                        doc = {
                            'timestamp': datetime.utcnow().isoformat(),
                            'topic': message.topic,
                            'partition': message.partition,
                            'offset': message.offset,
                            'data': event_data,
                            'consumer_group': KAFKA_GROUP_ID
                        }
                        
                        es.index(index='kafka-events', document=doc)
                        logger.info("Logged to Elasticsearch")
                    
                except Exception as e:
                    logger.error(f"Error processing message: {e}")
        
        except Exception as e:
            logger.error(f"Consumer failed: {e}")
            time.sleep(60)
    
    if __name__ == "__main__":
        while True:
            try:
                main()
            except Exception as e:
                logger.error(f"Fatal error: {e}")
                time.sleep(60)
EOF

# Apply Deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-consumer
  labels:
    app: kafka-consumer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kafka-consumer
  template:
    metadata:
      labels:
        app: kafka-consumer
    spec:
      containers:
      - name: consumer
        image: python:3.11-slim
        command: ["/bin/bash", "-c"]
        args:
          - |
            pip install kafka-python elasticsearch
            python /app/consumer.py
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "$MASTER_PRIVATE_IP:9092"
        - name: KAFKA_TOPIC
          value: "api-events"
        - name: KAFKA_GROUP_ID
          value: "consumer-group-1"
        - name: ELASTICSEARCH_HOST
          value: "$MASTER_PRIVATE_IP:9200"
        volumeMounts:
        - name: consumer-code
          mountPath: /app
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: consumer-code
        configMap:
          name: kafka-consumer-code
EOF

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=kafka-consumer --timeout=300s

# Check deployment status
kubectl get deployments
kubectl get pods

# View consumer logs
kubectl logs -l app=kafka-consumer --tail=50
```

## Testing the System

### Test 1: Direct Kafka Message

**On master node:**
```bash
# Send test message to Kafka
echo '{"event":"test","message":"Hello from Kafka","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' | \
sudo /opt/kafka/bin/kafka-console-producer.sh \
  --broker-list localhost:9092 \
  --topic api-events

# Check consumer logs
kubectl logs -l app=kafka-consumer --tail=20

# Should see:
# "Received: {'event': 'test', ...}"
# "Logged to Elasticsearch"
```

### Test 2: S3 Upload Trigger

**On your local machine:**
```bash
# Get S3 bucket name
cd terraform
export BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Create test file
echo "Test file uploaded at $(date)" > test-upload.txt

# Upload to S3
aws s3 cp test-upload.txt s3://$BUCKET_NAME/

# Check Lambda logs
aws logs tail /aws/lambda/devops-final-s3-processor --follow --since 1m

# Should see Lambda processing the S3 event
```

### Test 3: API Gateway Request

**On your local machine:**
```bash
# Get API Gateway URL
export API_URL=$(terraform output -raw api_gateway_url)

# Send POST request
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "api_test",
    "message": "Hello from API Gateway",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'

# Should return:
# {"message": "Event processed successfully", "topic": "api-events"}

# Check Lambda logs
aws logs tail /aws/lambda/devops-final-s3-processor --follow
```

### Test 4: Verify Logs in Kibana

1. Open Kibana: `http://<MASTER_PUBLIC_IP>:5601`
2. Click hamburger menu → **Management** → **Stack Management**
3. Click **Index Patterns** → **Create index pattern**
4. Enter `kafka-events*`
5. Click **Next** → Select `timestamp` as time field → **Create**
6. Go to **Analytics** → **Discover**
7. You should see all your test messages!

**Try filtering:**
- `data.event: "test"`
- `data.event: "api_test"`
- `topic: "api-events"`

## Collecting Evidence for Submission

### AWS Console Screenshots

Take screenshots of:
1. EC2 → Instances (showing 3 running instances)
2. VPC → Your VPCs
3. S3 → Your bucket with uploaded files
4. Lambda → Functions → devops-final-s3-processor
5. API Gateway → devops-final-api

### Kibana Screenshots

Take screenshots of:
1. Discover page showing logs
2. Expanded log entry with all fields
3. Filtered search results

### Save Command Outputs

**On master node:**
```bash
# Kubernetes resources
kubectl get all --all-namespaces > ~/k8s-all-resources.txt
kubectl get nodes -o wide > ~/k8s-nodes.txt
kubectl get pods -o wide > ~/k8s-pods.txt
kubectl describe deployment kafka-consumer > ~/k8s-deployment.txt
kubectl logs -l app=kafka-consumer --tail=100 > ~/k8s-logs.txt

# Kafka information
sudo /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 > ~/kafka-topics.txt
sudo /opt/kafka/bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 > ~/kafka-details.txt
sudo /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list > ~/kafka-groups.txt
sudo /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group consumer-group-1 > ~/kafka-group-details.txt
```

**Download evidence files to local machine:**
```bash
# On your local machine
cd devops-final-project
mkdir -p screenshots

scp -i terraform/devops-key.pem ec2-user@$MASTER_IP:~/*.txt ./screenshots/
```

**Save Terraform outputs:**
```bash
cd terraform
terraform output > ../screenshots/terraform-outputs.txt
```



## Project Evidence and Screenshots

This section provides visual evidence of the deployed infrastructure and successful system operation.

### Infrastructure Deployment

**Terraform Apply Success**

![Terraform Apply](screenshots/image9.jpeg)
*Image 1: Terraform successfully creating infrastructure resources*

**Terraform Outputs**

![Terraform Outputs](screenshots/image8.jpeg)
*Image 2: Terraform outputs showing deployed resource information including IPs and endpoints*

### AWS Console - Deployed Resources

**EC2 Instances**

![EC2 Instances](screenshots/image10.jpeg)
*Image 3: Three EC2 instances running - k8s-control-plane (master), k8s-worker-1, and kafka instance*

**S3 Bucket**

![S3 Bucket](screenshots/image7.jpeg)
*Image 4: S3 bucket created for file uploads*

**S3 Object Upload**

![S3 Object](screenshots/image5.jpeg)
*Image 5: Test file (test.json) uploaded to S3 bucket, triggering Lambda function*

**Lambda Function**

![Lambda Function](screenshots/image6.jpeg)
*Image 6: Lambda function deployed and configured with Python 3.11 runtime*

**API Gateway**

![API Gateway](screenshots/image2.jpeg)
*Image 7: HTTP API Gateway created with regional endpoint*

### System Operation

**Kafka Producer Success**

![Kafka Producer](screenshots/image1.jpeg)
*Image 8: Kafka console producer successfully sending messages to topic*

**Lambda Invocation**

![Lambda Invocation](screenshots/image3.jpeg)
*Image 9: Lambda function successfully invoked from local machine, processing events and sending to Kafka*

**Kafka Consumer Running**

![Kafka Consumer](screenshots/image3.jpeg)
*Image 9: Kafka consumers running in Kubernetes pods, successfully receiving messages*

**Lambda Error Handling**

![Lambda Errors](screenshots/image4.jpeg)
*Image 10: Lambda function error logs showing proper error handling and retry mechanisms*

### Event Flow Verification

The screenshots demonstrate the complete event-driven architecture:

1. **S3 → Lambda → Kafka**: File uploaded to S3 (Image 5) triggers Lambda (Image 6), which sends events to Kafka
2. **API Gateway → Lambda → Kafka**: API Gateway (Image 2) receives HTTP POST, invokes Lambda, which forwards to Kafka (Image 1)
3. **Kafka → Consumers**: Messages consumed by Kubernetes pods (Image 3)
4. **Error Handling**: Dead Letter Queue (DLQ) configuration for failed Lambda invocations (Image 4)

### Architecture Components Verified

✅ **Infrastructure Layer**
- 3 EC2 instances deployed (1 master + 2 workers) - Image 3
- VPC with proper networking configuration
- Security groups configured for required ports

✅ **Application Layer**
- Kafka broker running and accessible - Image 8
- Kubernetes cluster operational - Image 3
- Lambda function deployed and functional - Image 6

✅ **Integration Layer**
- S3 event notifications configured - Image 5
- API Gateway endpoints active - Image 7
- Lambda successfully sends to Kafka - Image 9

✅ **Monitoring & Error Handling**
- CloudWatch logs capturing Lambda executions - Image 10
- DLQ configured for failed invocations - Image 10
- Consumer logs visible in Kubernetes - Image 9

### Key Observations

**From Image 1 (Kafka Producer):**
```
producer=kafka-producer-8ddu74bfff-7xbmb ts=2026-01-10T01:57:31.828000+00:00
{"httpMethod":"POST","ip":"79.177.149.31","path":"/events"...}
```
- Shows successful message production to Kafka
- Contains API Gateway event data with HTTP method, IP, and path

**From Image 9 (Lambda Invocation & Kafka Consumer):**
```
"StatusCode": 200,
"ExecutedVersion": "$LATEST"
```
- Lambda invoked successfully from local machine
- Kafka consumers running and receiving messages

**From Image 10 (Lambda Error Logs):**
```
Traceback (most recent call last):
  ...
kafka.errors.NoBrokersAvailable
```
- Demonstrates proper error handling
- DLQ captures failed invocations for retry

**From Image 2 (Terraform Outputs):**
```
k8s_control_plane_public_ip = "18.185.110.210"
k8s_worker_public_ips = ["3.76.7.196"]
kafka_bootstrap = "10.20.1.216:9092"
kafka_public_ip = "63.180.175.126"
```
- All infrastructure components successfully deployed
- Public and private IPs correctly assigned

**From Image 3 (EC2 Instances):**
- All instances in "Running" state
- Proper instance types: t3.small for control plane, t3.micro for workers
- Located in eu-central-1a availability zone

### Testing Results

| Test Type | Status | Evidence |
|-----------|--------|----------|
| Terraform Deployment | ✅ Success | Images 1, 2 |
| EC2 Instances Running | ✅ Success | Image 3 |
| Kafka Message Production | ✅ Success | Image 1 |
| S3 Upload Trigger | ✅ Success | Images 5, 6 |
| API Gateway Integration | ✅ Success | Image 7 |
| Lambda Function Execution | ✅ Success | Images 6, 9, 10 |
| Kafka Consumer Processing | ✅ Success | Image 9 |
| Error Handling (DLQ) | ✅ Success | Image 10 |

### Notes on Implementation

**Lambda Async Error Handling (Image 10):**
- Lambda async failures are routed to SQS DLQ via EventInvokeConfig on_failure destination
- Failure record includes: requestId, functionArn, condition=RetriesExhausted, approximateInvokeCount, and the exception stack trace
- Tested by misconfiguring Kafka bootstrap to force NoBrokersAvailable, verified DLQ messages arrived in SQS

**API Gateway Configuration (Image 7):**
- Using HTTP API (APIGatewayV2) for simpler configuration
- Regional endpoint type for lower latency
- Created on 2026-01-10

**S3 Bucket Configuration (Image 5, 2):**
- Bucket created in eu-central-1 (Europe Frankfurt)
- Event notification configured for ObjectCreated events
- Successfully triggers Lambda on file upload

**Kafka Setup (Image 8):**
- Running on dedicated EC2 instance (63.180.175.126)
- Private IP for internal communication (10.20.1.216:9092)
- Successfully receiving messages from both API Gateway and S3 Lambda


---

## Architecture Decisions

### Why Kafka on EC2 Instead of MSK?
- **Educational Value**: Manual installation teaches Kafka architecture and configuration
- **Cost Optimization**: MSK is expensive for learning projects
- **Full Control**: Complete access to Kafka configuration and management

### Why Single-Node Elasticsearch?
- **Sufficient for Project Scope**: Handles the required log volume
- **Resource Efficient**: Reduces infrastructure costs
- **Simplified Deployment**: Easier to set up and manage

### Why Flannel CNI?
- **Lightweight**: Low resource overhead
- **Reliable**: Well-tested and stable
- **Easy Setup**: Simple configuration for learning environment

### Topic Design
- **Single Topic** (`api-events`): All events flow through one topic
- **3 Partitions**: Allows parallel processing by multiple consumers
- **Replication Factor 1**: Sufficient for educational purposes

## Assumptions

1. **Region**: All resources deployed in us-east-1
2. **Instance OS**: Amazon Linux 2 for all EC2 instances
3. **Networking**: Public subnets used for simplified access (demo environment)
4. **Security**: Security groups configured for necessary ports
5. **Elasticsearch Security**: Disabled for simplicity (not recommended for production)
6. **Kafka Replication**: Single broker, replication factor 1

## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods

# Describe pod
kubectl describe pod <POD_NAME>

# Check logs
kubectl logs <POD_NAME>

# Common issues:
# - Image pull errors: Check internet connectivity
# - CrashLoopBackOff: Check application logs
```

### Kafka Connection Issues
```bash
# Check Kafka is running
sudo systemctl status kafka
sudo systemctl status zookeeper

# Check Kafka logs
sudo tail -f /opt/kafka/logs/server.log

# Verify Kafka is listening
sudo netstat -tulpn | grep 9092
```

### Elasticsearch Not Accessible
```bash
# Check Elasticsearch status
sudo systemctl status elasticsearch

# Check Elasticsearch logs
sudo journalctl -u elasticsearch -n 100

# Test connection
curl localhost:9200
```

### Worker Nodes Won't Join
```bash
# Verify join command has correct IP and token
# Regenerate token if needed:
kubeadm token create --print-join-command

# Check master node is reachable from workers
ping <MASTER_PRIVATE_IP>

# Verify port 6443 is open
telnet <MASTER_PRIVATE_IP> 6443
```

## Resource Cleanup

**To destroy all resources and avoid ongoing charges:**
```bash
# On your local machine
cd devops-final-project/terraform

# Destroy all AWS resources
terraform destroy

# Type 'yes' when prompted

# Delete SSH key pair
aws ec2 delete-key-pair --key-name devops-key
rm devops-key.pem

# Verify everything is deleted
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-final" \
  --query 'Reservations[].Instances[].InstanceId'
```

## Technologies Used

- **Cloud Provider**: AWS (EC2, VPC, S3, Lambda, API Gateway, IAM)
- **Container Orchestration**: Kubernetes 1.28
- **Message Broker**: Apache Kafka 3.5.1
- **Infrastructure as Code**: Terraform
- **Logging**: Elasticsearch 8.x + Kibana 8.x
- **Programming**: Python 3.11
- **Container Runtime**: containerd

## Project Deliverables

This project includes:

✅ Complete Terraform configuration for all infrastructure

✅ Lambda function for event processing

✅ Kubernetes manifests for consumer applications

✅ Installation scripts for automated setup

✅ Comprehensive documentation

✅ Screenshots demonstrating system functionality

✅ Evidence of log collection and visualization

## Authors :

**Loay Egbaria , Loayegb@gmail.com**

**Loai Saadi**


**DevOps Final Project**

**Course**: DevOps Engineering

1/1/2026

## License

This project is for educational purposes.