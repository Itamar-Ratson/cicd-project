import json
import requests
import os

def lambda_handler(event, context):
    slack_webhook = os.environ['SLACK_WEBHOOK_URL']
    
    # Parse message from event
    message = json.loads(event['body']) if 'body' in event else event
    
    # Prepare Slack message
    slack_message = {
        'text': f"🚀 Pipeline Notification",
        'blocks': [
            {
                'type': 'section',
                'text': {
                    'type': 'mrkdwn',
                    'text': f"*Status:* {message.get('status', 'Unknown')}\n*Commit:* `{message.get('commit', 'N/A')}`\n*Build:* #{message.get('build_number', 'N/A')}"
                }
            }
        ]
    }
    
    # Determine channel based on status
    if message.get('environment') == 'production':
        slack_message['channel'] = '#prod-deployments'
    elif message.get('environment') == 'staging':
        slack_message['channel'] = '#staging-deployments'
    else:
        slack_message['channel'] = '#dev-builds'
    
    # Send to Slack
    response = requests.post(slack_webhook, json=slack_message)
    
    return {
        'statusCode': response.status_code,
        'body': json.dumps({'message': 'Notification sent'})
    }
