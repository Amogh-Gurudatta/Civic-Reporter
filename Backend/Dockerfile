FROM python:3.14-slim

ENV PYTHONUNBUFFERED True

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . ./

# Explicitly bind to 0.0.0.0 and dynamically read the PORT environment variable 
# injected by Google Cloud Run. We use sh -c to ensure environment variable expansion works seamlessly.
CMD sh -c "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"