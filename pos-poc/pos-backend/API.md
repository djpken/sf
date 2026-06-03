# POS API 文件

## 基礎資訊

- Base URL: `http://localhost:8080`
- API Version: `v1`
- API Prefix: `/api/v1`

## 認證

大多數 API 需要 JWT 認證。在請求 header 中包含：

```
Authorization: Bearer <your-jwt-token>
```

## 端點

### 健康檢查

#### GET /health

檢查服務健康狀態

**Response:**
```json
{
  "status": "healthy",
  "time": "2024-01-01T12:00:00Z"
}
```

---

### 認證 (Auth)

#### POST /api/v1/auth/login

使用 Email 和密碼登入

**Request Body:**
```json
{
  "email": "admin@example.com",
  "password": "admin123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "employee": {
      "id": "33333333-3333-3333-3333-333333333331",
      "tenant_id": "11111111-1111-1111-1111-111111111111",
      "store_id": "22222222-2222-2222-2222-222222222221",
      "name": "王大明",
      "email": "admin@example.com",
      "role": "admin",
      "is_active": true
    }
  }
}
```

#### POST /api/v1/auth/pin-login

使用 PIN 碼快速登入

**Request Body:**
```json
{
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "pin_code": "1234"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "employee": {
      "id": "33333333-3333-3333-3333-333333333331",
      "tenant_id": "11111111-1111-1111-1111-111111111111",
      "name": "王大明",
      "role": "admin"
    }
  }
}
```

#### POST /api/v1/auth/logout

登出 (需要認證)

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

### 測試端點

#### GET /api/v1/ping

測試已認證的端點

**Headers:**
```
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "pong (authenticated)"
}
```

---

## 錯誤回應

所有錯誤回應遵循以下格式：

```json
{
  "success": false,
  "error": "錯誤訊息"
}
```

### HTTP 狀態碼

- `200` - 成功
- `400` - 請求錯誤
- `401` - 未授權 (未登入或 token 無效)
- `403` - 禁止存取 (權限不足)
- `404` - 資源不存在
- `500` - 伺服器錯誤

---

## 測試範例

### 使用 curl

1. **健康檢查**
```bash
curl http://localhost:8080/health
```

2. **登入**
```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "admin123"
  }'
```

3. **PIN 登入**
```bash
curl -X POST http://localhost:8080/api/v1/auth/pin-login \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "11111111-1111-1111-1111-111111111111",
    "pin_code": "1234"
  }'
```

4. **測試已認證端點**
```bash
# 先登入取得 token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  | jq -r '.data.token')

# 使用 token 訪問受保護的端點
curl http://localhost:8080/api/v1/ping \
  -H "Authorization: Bearer $TOKEN"
```

---

## 開發資訊

### 測試帳號

種子資料中包含以下測試帳號：

| 姓名 | Email | PIN | 密碼 | 角色 |
|------|-------|-----|------|------|
| 王大明 | admin@example.com | 1234 | admin123 | admin |
| 李小華 | cashier@example.com | 5678 | admin123 | cashier |
| 陳廚師 | kitchen@example.com | 9012 | admin123 | kitchen |

**Tenant ID:** `11111111-1111-1111-1111-111111111111`

### JWT Claims

JWT token 包含以下 claims：

```json
{
  "user_id": "uuid",
  "tenant_id": "uuid",
  "store_id": "uuid",
  "role": "admin|manager|cashier|kitchen",
  "exp": 1234567890,
  "iat": 1234567890
}
```

---

## 待實作功能

以下端點規劃中，尚未實作：

- [ ] 分店管理 (`/api/v1/stores`)
- [ ] 菜單管理 (`/api/v1/menu`)
- [ ] 訂單管理 (`/api/v1/orders`)
- [ ] 付款處理 (`/api/v1/payments`)
- [ ] 發票管理 (`/api/v1/invoices`)
- [ ] 桌位管理 (`/api/v1/tables`)
- [ ] 報表查詢 (`/api/v1/reports`)
- [ ] 庫存管理 (`/api/v1/inventory`)
