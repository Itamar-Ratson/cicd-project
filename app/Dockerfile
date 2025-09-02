FROM python:3.11-slim as base
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# SAST Stage
FROM base as sast
COPY test_requirements.txt .
RUN pip install bandit safety
COPY app.py .
RUN bandit -r app.py && safety check

# Lint Stage
FROM base as lint
RUN pip install flake8 black
COPY app.py .
RUN flake8 app.py && black --check app.py

# Unit Test Stage
FROM base as unit-test
RUN pip install pytest pytest-cov
COPY app.py test_app.py ./
RUN pytest test_app.py --cov=app --cov-report=term-missing

# Integration Test Stage
FROM base as integration-test
COPY app.py test_integration.py ./
RUN pip install pytest requests
RUN pytest test_integration.py

# DAST Stage
FROM python:3.11-slim as dast
RUN pip install zap-cli
COPY dast_scan.py .
CMD ["python", "dast_scan.py"]

# Production Stage
FROM base as production
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
