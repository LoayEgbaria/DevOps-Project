#!/bin/bash
# This script sets up Elasticsearch and Kibana with memory limits
set -e

echo "Setting up Elasticsearch and Kibana (Lightweight Mode)..."

# Import GPG key and add repository
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat <<EOF | sudo tee /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-8.x]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# Install Elasticsearch
sudo yum install -y elasticsearch

# --- CONFIGURE MEMORY LIMITS ---
sudo mkdir -p /etc/elasticsearch/jvm.options.d
echo "-Xms512m" | sudo tee /etc/elasticsearch/jvm.options.d/heap.options
echo "-Xmx512m" | sudo tee -a /etc/elasticsearch/jvm.options.d/heap.options

# Basic network configuration
sudo sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "discovery.type: single-node" | sudo tee -a /etc/elasticsearch/elasticsearch.yml

# Start Elasticsearch
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Install Kibana
sudo yum install -y kibana

# Configure Kibana memory and host
echo 'NODE_OPTIONS="--max-old-space-size=256"' | sudo tee -a /etc/default/kibana
sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
sudo sed -i 's|#elasticsearch.hosts:.*|elasticsearch.hosts: ["http://localhost:9200"]|' /etc/kibana/kibana.yml

# Start Kibana
sudo systemctl start kibana
sudo systemctl enable kibana

echo "Elasticsearch and Kibana setup complete!"