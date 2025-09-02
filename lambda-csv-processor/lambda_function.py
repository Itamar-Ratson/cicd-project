import boto3
import csv
import requests
import os
from io import StringIO

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    
    # Get CSV from S3
    bucket = os.environ['S3_BUCKET']
    response = s3.get_object(Bucket=bucket, Key='groups.csv')
    csv_content = response['Body'].read().decode('utf-8')
    
    # Parse CSV
    csv_reader = csv.DictReader(StringIO(csv_content))
    gitlab_url = os.environ['GITLAB_URL']
    gitlab_token = os.environ.get('GITLAB_TOKEN', 'dummy-token')
    
    headers = {'PRIVATE-TOKEN': gitlab_token}
    
    for row in csv_reader:
        # Create GitLab group
        group_data = {
            'name': row['group_name'],
            'path': row['group_name'].lower().replace(' ', '-'),
            'description': row['description'],
            'visibility': row['visibility']
        }
        
        try:
            response = requests.post(
                f"{gitlab_url}/api/v4/groups",
                headers=headers,
                json=group_data
            )
            print(f"Created group: {row['group_name']}")
        except Exception as e:
            print(f"Failed to create group {row['group_name']}: {e}")
    
    return {'statusCode': 200, 'body': 'Groups processed'}
