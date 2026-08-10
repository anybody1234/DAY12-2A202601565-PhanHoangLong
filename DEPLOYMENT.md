# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Phan Hoang Long |
| Mã học viên | 2A202601565 |
| Repo | https://github.com/anybody1234/DAY12-2A202601565-PhanHoangLong |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-iq8a.onrender.com |
| Platform | Render (Blueprint từ `render.yaml`) |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | tự nối qua Render Key Value add-on `day12-redis` (`fromService` trong render.yaml) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

```
$ curl -i https://day12-agent-iq8a.onrender.com/health
HTTP/1.1 200 OK
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i https://day12-agent-iq8a.onrender.com/ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

$ curl -i -X POST https://day12-agent-iq8a.onrender.com/ask \
  -H "Content-Type: application/json" -d '{"question":"Hello"}'
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}

$ curl -i -X POST https://day12-agent-iq8a.onrender.com/ask \
  -H "Content-Type: application/json" -H "X-API-Key: $DEPLOY_API_KEY" \
  -H "X-User-Id: cp5-test" -d '{"question":"Deploy là gì?"}'
HTTP/1.1 200 OK
{"answer":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến
môi trường, health check để orchestrator biết trạng thái, và giới hạn tài
nguyên.","user_id":"cp5-test","history_length":0,
"cost_usd":2.265e-05,"tokens":{"in":3,"out":37}}

# Rate limit — 15 request liên tiếp, giới hạn 10/phút (chạy 2 lần, user khác nhau)
$ for i in $(seq 1 15); do curl -s -o /dev/null -w "%{http_code} " ... ; done
404 404 200 404 200 200 200 200 200 200 200 200 404 200 429
200 200 200 200 200 200 200 200 200 404 200 429 404 429 404
```

Ghi chú: `429` xuất hiện ở các lần cuối, xác nhận rate limit hoạt động đúng.
Nhưng lẫn vào đó là vài mã `404` bất thường — kiểm tra bằng `curl -i` thì
thấy các response 404 này có header `x-render-routing: no-server` và body
`text/plain "Not Found"` (không phải JSON như app luôn trả) → chứng minh 404
đến từ router biên của Render, không phải từ code. Giải thích chi tiết ở
`exercises.md` câu 10 — đặc điểm free-tier (1 instance duy nhất, không có bản
dự phòng, nên có lúc router không thấy instance nào để chuyển request vào).

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
