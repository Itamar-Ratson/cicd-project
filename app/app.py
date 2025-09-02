from flask import Flask, jsonify
import boto3
import os
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

app = Flask(__name__)

# Initialize tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
otlp_exporter = OTLPSpanExporter(endpoint="opentelemetry-collector:4317", insecure=True)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# AWS clients
dynamodb = boto3.resource('dynamodb', region_name='eu-north-1')
sqs = boto3.client('sqs', region_name='eu-north-1')

@app.route('/')
def home():
    with tracer.start_as_current_span("home"):
        return jsonify({"message": "Hello World", "environment": os.getenv('ENVIRONMENT', 'development')})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/data', methods=['POST'])
def store_data():
    with tracer.start_as_current_span("store_data"):
        # Store in DynamoDB and send to SQS
        table = dynamodb.Table(f"app-table-{os.getenv('ENVIRONMENT', 'development')}")
        queue_url = f"https://sqs.eu-north-1.amazonaws.com/{os.getenv('AWS_ACCOUNT_ID')}/app-queue-{os.getenv('ENVIRONMENT')}"
        
        # Example implementation
        return jsonify({"status": "stored"}), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
