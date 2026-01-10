#!/bin/bash
# Install Elasticsearch and Kibana on Amazon Linux 2

set -e

echo "========================================="
echo "Installing Elasticsearch and Kibana"
echo "========================================="

# Import Elasticsearch GPG key
echo "Importing Elasticsearch GPG key..."
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# Add Elasticsearch repository
echo "Adding Elasticsearch repository..."
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
echo "Installing Elasticsearch..."
sudo yum install -y elasticsearch

# Configure Elasticsearch
echo "Configuring Elasticsearch..."
sudo sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
sudo sed -i 's/#http.port: 9200/http.port: 9200/' /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "discovery.type: single-node" | sudo tee -a /etc/elasticsearch/elasticsearch.yml

# Start Elasticsearch
echo "Starting Elasticsearch..."
sudo systemctl daemon-reload
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Wait for Elasticsearch to start
echo "Waiting for Elasticsearch to start (this may take 30-60 seconds)..."
sleep 45

# Verify Elasticsearch is running
echo "Verifying Elasticsearch installation..."
curl -X GET "localhost:9200/" || echo "Elasticsearch is still starting..."

# Install Kibana
echo "Installing Kibana..."
sudo yum install -y kibana

# Configure Kibana
echo "Configuring Kibana..."
sudo sed -i 's/#server.port: 5601/server.port: 5601/' /etc/kibana/kibana.yml
sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
sudo sed -i 's|#elasticsearch.hosts:.*|elasticsearch.hosts: ["http://localhost:9200"]|' /etc/kibana/kibana.yml

# Start Kibana
echo "Starting Kibana..."
sudo systemctl daemon-reload
sudo systemctl start kibana
sudo systemctl enable kibana

# Get public IP for access information
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "========================================="
echo "Elasticsearch and Kibana installed successfully!"
echo ""
echo "Elasticsearch: http://$PUBLIC_IP:9200"
echo "Kibana: http://$PUBLIC_IP:5601"
echo ""
echo "Note: Kibana may take 2-3 minutes to be fully ready"
echo "========================================="