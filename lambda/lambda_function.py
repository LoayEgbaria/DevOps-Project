import json
import os
import logging
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function triggered by S3 uploads or API Gateway requests.
    Logs events that would be sent to Kafka.
    
    Note: In a production environment, this would use kafka-python library
    to actually send messages to Kafka. For this educational project,
    we log the events which are then collected by the logging system.
    """
    
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Determine event source
        if 'Records' in event:
            # S3 Event
            for record in event['Records']:
                if 's3' in record:
                    bucket = record['s3']['bucket']['name']
                    key = record['s3']['object']['key']
                    event_time = record['eventTime']
                    
                    kafka_message = {
                        'event_type': 's3_upload',
                        'source': 'S3',
                        'bucket': bucket,
                        'key': key,
                        'timestamp': event_time,
                        'size': record['s3']['object']['size']
                    }
                    
                    logger.info(f"S3 Event to Kafka: {json.dumps(kafka_message)}")
                    logger.info(f"KAFKA_TOPIC: {os.environ.get('KAFKA_TOPIC', 'api-events')}")
                    logger.info(f"KAFKA_BOOTSTRAP_SERVERS: {os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'N/A')}")
        
        elif 'body' in event:
            # API Gateway Event
            try:
                body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
            except:
                body = {'raw_body': event['body']}
            
            kafka_message = {
                'event_type': 'api_request',
                'source': 'API_Gateway',
                'data': body,
                'timestamp': datetime.utcnow().isoformat(),
                'path': event.get('path', '/events'),
                'method': event.get('httpMethod', 'POST')
            }
            
            logger.info(f"API Gateway Event to Kafka: {json.dumps(kafka_message)}")
            logger.info(f"KAFKA_TOPIC: {os.environ.get('KAFKA_TOPIC', 'api-events')}")
        
        else:
            # Unknown event type
            logger.warning(f"Unknown event type: {json.dumps(event)}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': 'Event processed successfully',
                'topic': os.environ.get('KAFKA_TOPIC', 'api-events')
            })
        }
    
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }