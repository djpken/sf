# POS Backend

餐飲 POS 系統後端服務 - 使用 Go 開發

## 技術架構

- **語言**: Go 1.21+
- **Web 框架**: Gin
- **資料庫**: PostgreSQL 15
- **快取**: Redis 7
- **ORM**: GORM

## 專案結構

```
pos-backend/
├── cmd/                    # 應用程式入口
│   ├── api/               # API 服務
│   └── local/             # 本地服務
├── internal/              # 私有應用程式程式碼
│   ├── config/           # 配置管理
│   ├── domain/           # 領域模型
│   ├── repository/       # 資料存取層
│   ├── service/          # 業務邏輯層
│   ├── handler/          # HTTP 處理器
│   ├── middleware/       # 中介軟體
│   └── integration/      # 第三方整合
├── pkg/                  # 可共享的程式庫
│   ├── hardware/        # 硬體控制
│   └── utils/           # 工具函式
├── migrations/           # 資料庫遷移
└── scripts/             # 腳本工具
```

## 快速開始

### 前置需求

- Go 1.21+
- Docker & Docker Compose
- Make (可選)

### 安裝

1. 複製配置檔案
```bash
cp config.example.yaml config.yaml
```

2. 啟動開發環境 (PostgreSQL + Redis)
```bash
make dev
# 或
docker-compose up -d postgres redis
```

3. 執行資料庫遷移
```bash
make migrate-up
```

4. 下載依賴
```bash
go mod download
```

5. 啟動 API 服務
```bash
make run
# 或
go run cmd/api/main.go
```

API 服務將在 `http://localhost:8080` 啟動

## 開發指令

```bash
make help           # 顯示所有可用指令
make dev            # 啟動開發環境 (DB + Redis)
make run            # 運行 API 服務
make build          # 編譯應用程式
make test           # 執行測試
make migrate-up     # 執行資料庫遷移
make migrate-down   # 回滾資料庫遷移
make migrate-create name=xxx  # 建立新的遷移檔案
make logs           # 查看容器日誌
make down           # 停止所有服務
make clean          # 清理所有容器和資料卷
```

## API 文件

啟動服務後，可以訪問：
- Swagger UI: `http://localhost:8080/swagger/index.html` (待實作)
- Health Check: `http://localhost:8080/health`

## 環境變數

可以透過環境變數覆蓋配置：

```bash
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export REDIS_HOST=localhost
export JWT_SECRET=your-secret-key
```

## 資料庫遷移

建立新的遷移檔案：
```bash
make migrate-create name=create_users_table
```

這將建立兩個檔案：
- `migrations/YYYYMMDDHHMMSS_create_users_table.up.sql`
- `migrations/YYYYMMDDHHMMSS_create_users_table.down.sql`

## 測試

```bash
# 執行所有測試
make test

# 執行特定套件的測試
go test -v ./internal/service/...

# 測試覆蓋率
go test -cover ./...
```

## 部署

### 使用 Docker

```bash
# 建立映像
docker build -t pos-api:latest .

# 運行容器
docker run -d \
  -p 8080:8080 \
  --name pos-api \
  pos-api:latest
```

### 使用 Docker Compose

```bash
# 啟動所有服務 (包含 API)
docker-compose up -d
```

## 授權

Private
