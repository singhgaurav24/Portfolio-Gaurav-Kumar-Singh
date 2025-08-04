# Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app/ .
COPY app/requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "aap.py"]