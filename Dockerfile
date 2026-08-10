# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
# Multi-stage: stage `builder` cài dependency, stage runtime chỉ copy
# kết quả sang → image nhỏ, không mang theo compiler, chạy user thường,
# đọc cổng từ biến môi trường PORT.
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/ app/
COPY utils/ utils/

RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import os, urllib.request; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=3)"

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
