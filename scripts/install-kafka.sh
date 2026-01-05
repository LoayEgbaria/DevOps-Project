#!/bin/bash
# This script installs Apache Kafka with memory limits
set -e

echo "Installing Apache Kafka (Lightweight Mode)..."

# Install Java 11
sudo yum install -y java-11-openjdk

# Download and install Kafka 3.5.1
cd /opt
sudo wget https://archive.apache.org/dist/kafka/3.5.1/kafka_2.13-3.5.1.tgz
sudo tar -xzf kafka_2.13-3.5.1.tgz
sudo mv kafka_2.13-3.5.1 kafka

# Create Kafka systemd service with 256MB memory limit
cat <<EOF | sudo tee /etc/systemd/system/kafka.service
[Unit]
Description=Apache Kafka
After=network.target

[Service]
Type=simple
User=root
# CRITICAL: Limit memory for t3.micro
Environment="KAFKA_HEAP_OPTS=-Xmx256M -Xms256M"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start Kafka service
sudo systemctl daemon-reload
sudo systemctl start kafka
sudo systemctl enable kafka

echo "Kafka installation complete with memory limits!"