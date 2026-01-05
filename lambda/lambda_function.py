import json
import os
from kafka import KafkaProducer

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    # Initialize Kafka Producer
    # Environment variables are defined in your s3-lambda.tf
    producer = KafkaProducer(
        bootstrap_servers=os.environ['KAFKA_BOOTSTRAP_SERVERS'],
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        # Adding a short timeout ensures the Lambda doesn't hang if Kafka is down
        request_timeout_ms=5000 
    )
    
    topic = os.environ['KAFKA_TOPIC']

    # --- SCENARIO 1: API GATEWAY (Product, Order, Supplier) ---
    if 'httpMethod' in event:
        print("Processing API Gateway Event")
        try:
            body = json.loads(event['body']) if event.get('body') else {}
            
            # Enrich the message with metadata
            message = {
                'source': 'api_gateway',
                'method': event['httpMethod'],
                'data': body
            }
            
            producer.send(topic, message)
            producer.flush() # Ensure message is sent before Lambda finishes
            
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'message': 'API Event sent to Kafka', 'topic': topic})
            }
        except Exception as e:
            print(f"Error processing API event: {str(e)}")
            return {'statusCode': 500, 'body': json.dumps(f"Error: {str(e)}")}

    # --- SCENARIO 2: S3 UPLOAD TRIGGER ---
    elif 'Records' in event:
        print("Processing S3 Event")
        for record in event['Records']:
            message = {
                'source': 's3_upload',
                'bucket': record['s3']['bucket']['name'],
                'key': record['s3']['object']['key'],
                'size': record['s3']['object']['size'],
                'timestamp': record['eventTime']
            }
            
            producer.send(topic, message)
            print(f"S3 Event sent to Kafka: {message['key']}")
        
        producer.flush()
        return {
            'statusCode': 200,
            'body': json.dumps('S3 Events processed successfully')
        }

    return {
        'statusCode': 400,
        'body': json.dumps('Unsupported event source')
    }