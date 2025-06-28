import json
import os

def handler(event, context):
    """
    Placeholder Lambda function for initial Terraform deployment
    This will be replaced by the actual Lambda code during CI/CD deployment
    """
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': 'Placeholder function - Deployment in progress',
            'environment': os.getenv('ENVIRONMENT', 'dev'),
            'status': 'pending',
            'request_id': context.aws_request_id,
            'function_name': context.function_name,
            'project': 'youtube-downloader'
        })
    }
