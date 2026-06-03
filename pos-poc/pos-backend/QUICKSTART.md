# 快速啟動指南

## 前置需求

確保您已安裝：
- [Go 1.21+](https://golang.org/dl/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [golang-migrate](https://github.com/golang-migrate/migrate) (可選，用於資料庫遷移)

## 5 分鐘啟動

### 1. 啟動資料庫 (PostgreSQL + Redis)

```bash
cd pos-backend
make dev
# 或
docker-compose up -d postgres redis
```

等待服務啟動完成 (約 10-20 秒)

### 2. 執行資料庫遷移

有兩種方式：

**方式 A: 使用腳本 (需安裝 golang-migrate)**
```bash
# macOS
brew install golang-migrate

# 執行遷移
./scripts/migrate.sh up
```

**方式 B: 手動執行 SQL**
```bash
# 連接到 PostgreSQL
docker exec -it pos_postgres psql -U pos -d pos_db

# 在 psql 中執行
\i /path/to/migrations/000001_init_schema.up.sql
\i /path/to/migrations/000002_seed_data.up.sql
```

### 3. 啟動 API 服務

```bash
make run
# 或
go run cmd/api/main.go
```

服務將在 `http://localhost:8080` 啟動

### 4. 測試 API

```bash
# 健康檢查
curl http://localhost:8080/health

# 登入測試
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "admin123"
  }'
```

## 開發環境配置

### 配置檔案

預設配置位於 `config.yaml`，可以根據需要修改：

```yaml
server:
  port: "8080"
  mode: "debug"

database:
  host: "localhost"
  port: 5432
  user: "pos"
  password: "pos_password"
  dbname: "pos_db"

redis:
  host: "localhost"
  port: 6379

jwt:
  secret: "your-secret-key-change-in-production"
  expireHour: 24
```

### 環境變數

也可以使用環境變數覆蓋配置：

```bash
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export REDIS_HOST=localhost
export JWT_SECRET=your-secret-key
```

## 常用指令

```bash
# 查看所有可用指令
make help

# 啟動開發環境 (DB + Redis)
make dev

# 運行 API 服務
make run

# 編譯應用程式
make build

# 運行測試
make test

# 查看日誌
make logs

# 停止所有服務
make down

# 清理所有容器和資料
make clean
```

## 測試帳號

| 姓名 | Email | PIN | 密碼 | 角色 |
|------|-------|-----|------|------|
| 王大明 | admin@example.com | 1234 | admin123 | admin |
| 李小華 | cashier@example.com | 5678 | admin123 | cashier |
| 陳廚師 | kitchen@example.com | 9012 | admin123 | kitchen |

**Tenant ID:** `11111111-1111-1111-1111-111111111111`

## 目錄結構

```
pos-backend/
├── cmd/api/              # API 服務入口
├── internal/
│   ├── config/          # 配置管理
│   ├── domain/          # 領域模型
│   ├── handler/         # HTTP 處理器
│   ├── middleware/      # 中介軟體
│   ├── repository/      # 資料存取層
│   └── service/         # 業務邏輯層
├── pkg/
│   └── utils/           # 工具函式
├── migrations/          # 資料庫遷移
├── config.yaml          # 配置檔案
└── docker-compose.yml   # Docker 配置
```

## 開發流程

1. **修改程式碼**
2. **重新啟動服務**
   ```bash
   # Ctrl+C 停止當前服務
   make run
   ```
3. **測試 API**
   ```bash
   # 使用 curl 或 Postman 測試
   ```

## 常見問題

### Q: 資料庫連接失敗

**A:** 確保 PostgreSQL 容器正在運行
```bash
docker ps | grep pos_postgres
```

如果沒有運行，執行：
```bash
make dev
```

### Q: Port 8080 已被占用

**A:** 修改 `config.yaml` 中的 port 設定：
```yaml
server:
  port: "8081"
```

### Q: 忘記執行資料庫遷移

**A:** 執行遷移指令：
```bash
./scripts/migrate.sh up
```

### Q: 需要重置資料庫

**A:** 清理並重新建立：
```bash
make clean      # 清理所有資料
make dev        # 重新啟動服務
./scripts/migrate.sh up  # 重新執行遷移
```

## 下一步

- 查看 [API 文件](./API.md) 了解可用端點
- 查看 [README](./README.md) 了解完整功能
- 開始實作新功能 (菜單、訂單等)

## 需要幫助？

- 檢查日誌：`make logs`
- 查看資料庫：`docker exec -it pos_postgres psql -U pos -d pos_db`
- 查看 Redis：`docker exec -it pos_redis redis-cli`
