FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MC1H_PLAYWRIGHT=0 \
    MC1H_DB=/tmp/mc1h.db \
    MC1H_CACHE_DB=/tmp/mc1h_cache.db \
    MC1H_OUT=/tmp/mc1h-out \
    MC1H_LOCAL_DATA=/app/data

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# The source tarball contains app/, README.md and docs/.
# ADD extracts it into /app automatically; data/ is copied separately below.
ADD mc1h-src.tar.gz /app/

# User-supplied HTML/JSON exports uploaded to data/ in the GitHub repository.
# .dockerignore excludes only *.db/*.sqlite, so .html/.json files are copied.
# MC1H_LOCAL_DATA=/app/data is set below and in render.yaml.
COPY data/ /app/data/

RUN mkdir -p /app/out /tmp/mc1h-out

EXPOSE 10000

# Render injects PORT (usually 10000). The app must bind to 0.0.0.0.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000} --proxy-headers"]