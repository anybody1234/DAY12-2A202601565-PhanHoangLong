# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng đánh dấu "Câu trả lời của bạn" ở mỗi câu bằng câu
> trả lời thật.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: ..........................  Mã học viên: ..........................

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống cụ thể: lúc tạo Blueprint trên Render, mình tạo web service
> trước khi kịp dán giá trị thật cho `AGENT_API_KEY`. Vì trường này không có
> default, `Settings()` ném `ValidationError` ngay khi `get_settings()` chạy
> lúc app khởi động — container crash ngay, Render đánh dấu deploy fail và
> log ghi rõ `agent_api_key Field required`. Mình biết ngay phải vào tab
> Environment điền khóa, sửa xong là chạy lại được.
>
> Nếu để mặc định `"changeme"` thì container vẫn khởi động bình thường,
> `/health` vẫn 200, dashboard vẫn xanh — không có tín hiệu báo lỗi nào cả.
> Vấn đề là `"changeme"` là giá trị công khai (ai đọc `.env.example` trên
> GitHub cũng biết), nên bất kỳ ai cũng gọi được `/ask` bằng đúng khóa đó.
> Mình sẽ không biết có chuyện gì sai cho tới khi nhận hóa đơn LLM bất
> thường hoặc thấy log có `user_id` lạ — tức là phát hiện SAU khi thiệt hại
> đã xảy ra, thay vì NGAY lúc deploy như với fail-fast.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Một dòng log thật lấy từ `log_event("ask_completed", ...)`:
> ```
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T04:37:44.771282+00:00", "user_id": "sv01", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}
> ```
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. **Lọc/tổng hợp theo trường** — vì mỗi dòng là một JSON object có key
>    cố định, mình dùng `jq '. | select(.event=="ask_completed") | .cost_usd'`
>    (hoặc code Python `json.loads` từng dòng) để cộng tổng `cost_usd` theo
>    `user_id`, trả lời câu "user nào tốn tiền nhất hôm nay?". Với
>    `print("đã trả lời xong")` thì chỉ có chuỗi tự do, không có trường nào
>    để lọc — muốn biết chi phí phải grep bằng regex, dễ vỡ khi format đổi.
> 2. **Cảnh báo tự động theo điều kiện** — hệ thống giám sát (Datadog,
>    CloudWatch...) đọc JSON và tạo alert kiểu "cost_usd trung bình 5 phút
>    qua vượt X" hoặc "tần suất event có level=error vượt Y/phút" mà không
>    cần viết parser riêng. `print()` dạng câu tự nhiên không có "level" hay
>    "timestamp" chuẩn hóa nên không thể set điều kiện cảnh báo tự động.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu, `FROM python:3.11`) | 1.73 GB |
| Multi-stage (`python:3.11-slim` + `COPY --from=builder`) | 270 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Đo thật bằng `docker images`: bản 1 stage build từ `FROM python:3.11`
> (image Debian đầy đủ, kèm nhiều thư viện hệ thống không cần cho việc chạy
> app) và `COPY . .` toàn bộ source + cài `pip install` ngay trong image
> cuối — ra **1.73 GB**. Bản multi-stage dùng `python:3.11-slim` (base nhẹ
> hơn hẳn) cho cả 2 stage, và stage cuối chỉ `COPY --from=builder /install
> /usr/local` (kết quả `pip install`) + `COPY app/ utils/` — ra **270 MB**.
> Chênh lệch ~1.46 GB đó là: (1) phần khác biệt giữa base image đầy đủ và
> base `slim` (thiếu các gói biên dịch/tài liệu/công cụ dòng lệnh không cần
> lúc chạy), (2) toàn bộ cache của `pip` và các file trung gian việc cài đặt
> (thư mục `.git`, `__pycache__`, file test... bị `COPY . .` mang theo mà
> multi-stage không hề "nhìn thấy" vì stage cuối không kế thừa filesystem
> của stage `builder`, chỉ lấy đúng thư mục `/install` cần thiết.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Thử thật: thêm một dòng comment vào cuối `app/main.py` rồi `docker build`
> lại, xem output từng layer:
> ```
> [builder 3/4] COPY requirements.txt .        CACHED
> [builder 4/4] RUN pip install ...             CACHED
> [stage-1 3/6] COPY --from=builder ...         CACHED
> [stage-1 4/6] COPY app/ app/                  (chạy lại)
> [stage-1 5/6] COPY utils/ utils/              (chạy lại)
> [stage-1 6/6] RUN useradd ...                 (chạy lại)
> ```
> Cả 2 layer trong stage `builder` (copy requirements + pip install) vẫn
> `CACHED` vì `requirements.txt` không đổi. Từ `COPY app/ app/` trở đi phải
> chạy lại — kể cả `COPY utils/ utils/` dù nội dung `utils/` không đổi gì
> cả, vì cache của một layer phụ thuộc cả vào digest của layer liền trước:
> layer `app/` đổi → digest cha thay đổi → mọi layer sau nó (dù nội dung
> chính layer đó y nguyên) đều tính là cache miss.
>
> Nếu đặt `COPY . .` lên **trước** `RUN pip install` (như bản Dockerfile
> gốc chưa sửa): sửa một dấu phẩy trong `app/main.py` sẽ làm layer `COPY . .`
> đổi digest → layer `pip install` (đứng ngay sau) cũng cache-miss theo →
> toàn bộ dependency (fastapi, uvicorn, pydantic...) bị cài lại từ đầu mỗi
> lần sửa code, dù không có thư viện nào thay đổi — build chậm hẳn đi, có
> thể từ vài giây (khi cache) lên hàng chục giây/vài phút (khi phải tải và
> cài lại toàn bộ `requirements.txt`).

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện nếu không có `USER`: (1) code Python có lỗ hổng, ví dụ một
> endpoint nào đó vô tình cho phép ghi file theo đường dẫn do người dùng
> nhập (path traversal) hoặc chạy lệnh hệ thống từ input (command injection);
> (2) kẻ tấn công khai thác lỗ hổng đó để thực thi lệnh tuỳ ý *bên trong*
> container; (3) vì tiến trình `uvicorn` đang chạy với quyền `root` (mặc
> định của container), lệnh tuỳ ý đó cũng chạy với quyền `root`; (4) `root`
> trong container có thể đọc/ghi các file được mount từ host, hoặc nếu có
> thêm một lỗ hổng khác ở tầng container runtime (kernel, Docker daemon),
> `root` trong container là điều kiện cần để leo thang tiếp thành `root`
> trên chính máy host.
>
> `RUN useradd --create-home --uid 10001 appuser` + `USER appuser` trong
> `Dockerfile` cắt đứt chuỗi này ở bước (3): dù bước (1) và (2) vẫn xảy ra
> (lỗ hổng trong code Python không tự biến mất), lệnh tuỳ ý kẻ tấn công
> chạy được giờ chỉ có quyền của `appuser` — một user thường, không có
> quyền ghi vào hầu hết hệ thống file, không thể cài phần mềm, và chắc
> chắn không tự động là bước đệm để ra `root` trên host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong 2 giây**. Cách đạt được: gửi đúng 10 request vào
> giây thứ 59 của phút hiện tại (bộ đếm phút này ghi nhận 10, đúng hạn mức,
> chưa bị chặn) — ngay lập tức tại giây 00 của phút kế tiếp, bộ đếm reset về
> 0, nên gửi tiếp 10 request nữa vẫn "đúng luật" theo cách tính này. Tổng
> cộng 20 request rơi vào một khoảng chỉ ~1-2 giây thực tế (từ giây :59 đến
> :01), dù về bản chất đó chính là kiểu burst mà hạn mức 10/phút muốn ngăn.
> Sliding window (đếm 60 giây gần nhất tính từ thời điểm request, không
> tính theo mốc giờ:phút cố định) không có kẽ hở này vì tại bất kỳ thời
> điểm nào, cửa sổ 60 giây ngay trước nó luôn chỉ chứa tối đa `limit` request
> đã được ghi nhận.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau ở *câu hỏi* mà mỗi lớp trả lời: rate limit hỏi "bạn gọi có quá
> nhanh không?" (bảo vệ hạ tầng/độ trễ, đếm số request trong 60 giây, không
> quan tâm mỗi request tốn bao nhiêu tiền). Cost guard hỏi "bạn đã tiêu hết
> ngân sách tháng chưa?" (bảo vệ ví tiền, cộng dồn `cost_usd` theo tháng,
> không quan tâm bạn gọi nhanh hay chậm). Hai trục hoàn toàn độc lập.
>
> - *Rate limit cho qua, cost guard chặn*: user chỉ gửi 1 request/phút —
>   không vi phạm hạn mức 10/phút — nhưng câu hỏi mỗi lần là một văn bản
>   rất dài (nhiều token). Vài request như vậy đã đủ vượt `monthly_budget_usd`,
>   `guard.check()` trả 402 dù `limiter.check()` luôn cho qua.
> - *Cost guard cho qua, rate limit chặn*: user hỏi toàn câu ngắn (chi phí
>   mỗi lần gần như 0, ngân sách tháng còn dư rất nhiều) nhưng bắn 15
>   request trong vài giây với hạn mức 10/phút. `guard.check()` vẫn cho qua
>   (chưa chạm ngân sách) nhưng `limiter.check()` chặn 429 ở request thứ
>   11, vì tốc độ gọi mới là thứ vượt giới hạn, không phải số tiền.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện nếu gộp `/health` và `/ready` thành một endpoint duy nhất,
> cho nó kiểm tra Redis:
> 1. Redis mất kết nối. Endpoint gộp gọi `store.ping()` → `False` → trả 503
>    cho **cả 3 container** cùng lúc, vì cả 3 đều phụ thuộc cùng một Redis.
> 2. Orchestrator (Docker/Railway/K8s) coi endpoint này là **liveness probe**
>    — 503 nghĩa là "process hỏng, cần restart", nên sau vài lần probe fail
>    liên tiếp, nó **restart cả 3 container cùng lúc** — không phải rút
>    traffic ra nhẹ nhàng, mà là kill và khởi động lại.
> 3. Trong lúc cả 3 container đang restart (mất vài giây đến vài chục giây
>    để khởi động lại, chạy `lifespan`, kết nối lại Redis...), **không còn
>    container nào đang chạy để phục vụ request** — toàn bộ service down,
>    dù Redis lúc này có thể đã kết nối lại được rồi.
> 4. Nếu Redis vẫn chưa kết nối lại xong khi 3 container mới khởi động,
>    chúng lại trả 503 ngay từ đầu → orchestrator lại restart tiếp → vòng
>    lặp restart liên tục cho tới khi Redis ổn định.
>
> Tách riêng `/health` (không đụng Redis, luôn 200 trừ lúc đang tắt dần) và
> `/ready` (có kiểm tra Redis, dùng cho readiness) thì kết quả khác hẳn: cả
> 3 container vẫn được coi là "sống" (không bị restart), chỉ bị load
> balancer rút khỏi vòng xoay nhận traffic mới trong lúc `/ready` báo 503 —
> khi Redis nối lại, `/ready` tự trả 200 và traffic được đưa vào lại ngay,
> không cần restart container nào cả. Một sự cố Redis 30 giây chỉ gây gián
> đoạn 30 giây, không biến thành cả cụm cùng sập.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Quan sát thật: chạy `docker compose up -d --scale agent=3`, gọi `/ask`
> 5 lần liên tiếp qua Nginx với cùng `X-User-Id`, `history_length` trả về
> đúng dãy **0, 2, 4, 6, 8** — tăng đều dù request rơi vào container nào
> trong 3 container (Nginx round-robin), vì cả 3 cùng đọc/viết một Redis
> (tăng 2 mỗi lượt vì `/ask` ghi cả message `user` và `assistant`, còn
> `history_length` được tính từ lịch sử đọc *trước khi* ghi lượt mới).
>
> Nếu lịch sử nằm trong `dict` Python (biến toàn cục trong RAM) thay vì
> Redis: mỗi container có `dict` riêng, rỗng lúc khởi động. Dãy số quan sát
> được sẽ **không tăng đều mà nhảy lộn xộn**, phụ thuộc hoàn toàn vào
> container nào nhận request nào — ví dụ nếu 5 request rơi theo thứ tự
> container A, B, A, C, B thì A thấy request 1 (history=0) và request 3
> (history=2, chỉ nhớ request 1 của chính nó); B thấy request 2 (history=0,
> không biết gì về request 1 mà A đã xử lý) và request 5 (history=2, chỉ
> nhớ request 2); C thấy request 4 (history=0). Kết quả quan sát được sẽ
> giống `0, 0, 2, 0, 2` — không thể đoán trước, và trông như agent "mất
> trí nhớ" ngẫu nhiên mỗi lần đổi container.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Sau khi service Render lên `Live`, mình gọi `/ask` 15 lần liên tiếp để test
> rate limit thì thấy kết quả trả về lẫn vài mã `404` xen giữa các mã `200`
> và `429` — ví dụ: `404 404 200 404 200 200 200 ... 200 429`. Ban đầu mình
> nghĩ đây là bug trong `rate_limiter.py`, nhưng để `curl -i` xem đầy đủ
> header/body của một response 404 thì thấy nó có header
> `x-render-routing: no-server` và `Content-Type: text/plain` với body chỉ
> là chuỗi `Not Found` — trong khi app của mình **luôn** trả JSON, kể cả lỗi
> (401 vẫn là `{"detail": "..."}`). Vậy 404 này không xuất phát từ code
> Python, mà từ router biên (edge) của Render.
>
> Nguyên nhân: gói free của Render chỉ chạy **1 instance duy nhất**, không có
> bản dự phòng. Khi mình bắn request liên tục quá nhanh, có những khoảnh
> khắc router của Render tạm thời không thấy instance nào sẵn sàng để
> chuyển request vào (ví dụ đang giữa lúc container khởi động lại do
> throttle tài nguyên free-tier), nên tự trả 404 thay vì chờ.
>
> Cách xử lý: đây là giới hạn của hạ tầng free-tier, không phải lỗi có thể
> sửa trong code — mình xác nhận `429` vẫn xuất hiện đúng ở các lần cuối
> (rate limit hoạt động đúng), và ghi lại hiện tượng 404 kèm bằng chứng
> header vào `DEPLOYMENT.md` để không nhầm là bug. Nếu chạy production thật,
> cách khắc phục đúng là nâng lên gói trả phí có ≥2 instance để router luôn
> có backend dự phòng, hoặc thêm retry-with-backoff ở phía client cho các
> request quan trọng.
