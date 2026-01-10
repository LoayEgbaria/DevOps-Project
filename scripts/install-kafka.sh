#!/bin/bash
# Install Apache Kafka on Amazon Linux 2

set -e

echo "========================================="
echo "Installing Apache Kafka"
echo "========================================="

# Install Java
echo "Installing Java 11..."
sudo yum install -y java-11-openjdk java-11-openjdk-devel

# Verify Java installation
java -version

# Download Kafka
echo "Downloading Kafka 3.5.1..."
cd /opt
sudo wget https://archive.apache.org/dist/kafka/3.5.1/kafka_2.13-3.5.1.tgz

# Extract Kafka
echo "Extracting Kafka..."
sudo tar -xzf kafka_2.13-3.5.1.tgz
sudo mv kafka_2.13-3.5.1 kafka
sudo rm kafka_2.13-3.5.1.tgz

# Create systemd service for Zookeeper
echo "Creating Zookeeper service..."
cat <<EOF | sudo tee /etc/systemd/system/zookeeper.service
[Unit]
Description=Apache Zookeeper
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Kafka
echo "Creating Kafka service..."
cat <<EOF | sudo tee /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka
After=network.target zookeeper.service
Requires=zookeeper.service

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Configure Kafka to advertise on private IP
echo "Configuring Kafka..."
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "advertised.listeners=PLAINTEXT://$PRIVATE_IP:9092" | sudo tee -a /opt/kafka/config/server.properties

# Reload systemd
sudo systemctl daemon-reload

# Start Zookeeper
echo "Starting Zookeeper..."
sudo systemctl start zookeeper
sudo systemctl enable zookeeper

# Wait for Zookeeper to be ready
echo "Waiting for Zookeeper to start..."
sleep 10

# Start Kafka
echo "Starting Kafka..."
sudo systemctl start kafka
sudo systemctl enable kafka

# Wait for Kafka to be ready
echo "Waiting for Kafka to start..."
sleep 15

# Verify Kafka is running
echo "Verifying Kafka installation..."
sudo systemctl status kafka --no-pager

echo "========================================="
echo "Apache Kafka installed successfully!"
echo "Kafka is listening on port 9092"
echo "========================================="