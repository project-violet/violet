FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements-server.txt ./
RUN pip install --no-cache-dir -r requirements-server.txt

COPY accelerated_index.py common.py search.py server.py ./

EXPOSE 8788

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8788", "--workers", "1"]
