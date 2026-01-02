import json
import os
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 upload
    Sends event to Kafka
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    # Extract S3 event details
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        event_time = record['eventTime']
        
        message = {
            'event_type': 's3_upload',
            'bucket': bucket,
            'key': key,
            'timestamp': event_time,
            'size': record['s3']['object']['size']
        }
        
        print(f"S3 Upload Event: {json.dumps(message)}")
        
        # In production, you would send this to Kafka
        # For this project, we'll log it and it will be picked up by the logging system
        
        # Note: To actually send to Kafka from Lambda, you would need:
        # 1. kafka-python library in Lambda layer
        # 2. VPC configuration to reach Kafka
        # 3. Code like:
        # from kafka import KafkaProducer
        # producer = KafkaProducer(
        #     bootstrap_servers=os.environ['KAFKA_BOOTSTRAP_SERVERS'],
        #     value_serializer=lambda v: json.dumps(v).encode('utf-8')
        # )
        # producer.send(os.environ['KAFKA_TOPIC'], message)
        
    return {
        'statusCode': 200,
        'body': json.dumps('Event processed successfully')
    }