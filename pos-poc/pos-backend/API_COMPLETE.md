# POS API 完整文件

## 基礎資訊

- Base URL: `http://localhost:8080`
- API Version: `v1`
- API Prefix: `/api/v1`
- 認證方式: JWT Bearer Token

## 認證

大多數 API 需要 JWT 認證。在請求 header 中包含：

```
Authorization: Bearer <your-jwt-token>
```

---

## API 端點總覽

### 認證 (Authentication)
- `POST /api/v1/auth/login` - Email/密碼登入
- `POST /api/v1/auth/pin-login` - PIN 碼快速登入
- `POST /api/v1/auth/logout` - 登出

### 菜單管理 (Menu Management)

#### 菜單分類
- `GET /api/v1/menu/categories` - 取得分類列表
- `GET /api/v1/menu/categories/:id` - 取得分類詳情
- `POST /api/v1/menu/categories` - 建立分類
- `PUT /api/v1/menu/categories/:id` - 更新分類
- `DELETE /api/v1/menu/categories/:id` - 刪除分類

#### 菜單商品
- `GET /api/v1/menu/items` - 取得商品列表
- `GET /api/v1/menu/items/:id` - 取得商品詳情
- `GET /api/v1/menu/items/barcode/:barcode` - 透過條碼查詢商品
- `POST /api/v1/menu/items` - 建立商品
- `PUT /api/v1/menu/items/:id` - 更新商品
- `DELETE /api/v1/menu/items/:id` - 刪除商品

#### 商品價格
- `GET /api/v1/menu/items/:id/prices` - 取得商品所有價格
- `GET /api/v1/menu/items/:id/prices/:store_id` - 取得商品在特定分店的價格
- `PUT /api/v1/menu/items/:id/prices/:store_id` - 設定商品分店價格

### 訂單管理 (Order Management)
- `GET /api/v1/orders` - 取得訂單列表
- `GET /api/v1/orders/:id` - 取得訂單詳情
- `POST /api/v1/orders` - 建立訂單
- `PUT /api/v1/orders/:id` - 更新訂單
- `PUT /api/v1/orders/:id/status` - 更新訂單狀態
- `POST /api/v1/orders/:id/cancel` - 取消訂單
- `POST /api/v1/orders/:id/items` - 新增商品到訂單
- `POST /api/v1/orders/:id/payments` - 新增付款
- `GET /api/v1/orders/sales/daily` - 取得每日銷售額

---

## 詳細 API 文件

### 1. 認證 (Authentication)

#### POST /api/v1/auth/login
Email/密碼登入

**Request:**
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
      "id": "uuid",
      "name": "王大明",
      "role": "admin",
      "tenant_id": "uuid",
      "store_id": "uuid"
    }
  }
}
```

#### POST /api/v1/auth/pin-login
PIN 碼快速登入

**Request:**
```json
{
  "tenant_id": "11111111-1111-1111-1111-111111111111",
  "pin_code": "1234"
}
```

---

### 2. 菜單分類 (Menu Categories)

#### GET /api/v1/menu/categories
取得分類列表

**Query Parameters:**
- `include_inactive` (boolean) - 是否包含停用的分類

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "name": "飲料",
      "sort_order": 1,
      "is_active": true,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /api/v1/menu/categories
建立分類

**Request:**
```json
{
  "name": "新分類",
  "sort_order": 10
}
```

#### PUT /api/v1/menu/categories/:id
更新分類

**Request:**
```json
{
  "name": "更新的分類名稱",
  "sort_order": 5,
  "is_active": true
}
```

---

### 3. 菜單商品 (Menu Items)

#### GET /api/v1/menu/items
取得商品列表

**Query Parameters:**
- `category_id` (uuid) - 依分類篩選
- `include_inactive` (boolean) - 是否包含停用的商品

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "tenant_id": "uuid",
      "category_id": "uuid",
      "name": "珍珠奶茶",
      "description": "經典珍珠奶茶",
      "price": 50.00,
      "cost": 20.00,
      "image_url": "",
      "barcode": "1001",
      "is_active": true,
      "options": {
        "sugar": ["正常", "少糖", "半糖", "微糖", "無糖"],
        "ice": ["正常冰", "少冰", "去冰", "溫", "熱"]
      },
      "sort_order": 1,
      "category": {
        "id": "uuid",
        "name": "飲料"
      }
    }
  ]
}
```

#### POST /api/v1/menu/items
建立商品

**Request:**
```json
{
  "category_id": "uuid",
  "name": "新商品",
  "description": "商品描述",
  "price": 100.00,
  "cost": 50.00,
  "barcode": "1234567890",
  "options": {
    "size": ["小", "中", "大"]
  },
  "sort_order": 1
}
```

#### GET /api/v1/menu/items/barcode/:barcode
透過條碼查詢商品

**Example:**
```bash
GET /api/v1/menu/items/barcode/1001
```

---

### 4. 訂單管理 (Orders)

#### GET /api/v1/orders
取得訂單列表

**Query Parameters:**
- `status` (string) - 訂單狀態: pending, preparing, ready, completed, cancelled
- `payment_status` (string) - 付款狀態: unpaid, partial, paid, refunded
- `start_date` (string) - 開始日期 (RFC3339 格式)
- `end_date` (string) - 結束日期 (RFC3339 格式)
- `limit` (int) - 每頁筆數 (預設 50, 最大 100)
- `offset` (int) - 偏移量 (預設 0)

**Response:**
```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": "uuid",
        "store_id": "uuid",
        "order_no": "20240101-0001",
        "order_type": "dine_in",
        "table_id": "uuid",
        "subtotal": 120.00,
        "discount": 0,
        "tax": 6.00,
        "service_charge": 0,
        "total": 126.00,
        "status": "completed",
        "payment_status": "paid",
        "items": [...],
        "payments": [...],
        "created_at": "2024-01-01T12:00:00Z"
      }
    ],
    "total": 100,
    "limit": 50,
    "offset": 0
  }
}
```

#### POST /api/v1/orders
建立訂單

**Request:**
```json
{
  "order_type": "dine_in",
  "table_id": "uuid",
  "items": [
    {
      "item_id": "uuid",
      "quantity": 2,
      "options": {
        "sugar": "少糖",
        "ice": "去冰"
      },
      "notes": "備註"
    }
  ],
  "notes": "訂單備註"
}
```

**訂單類型:**
- `dine_in` - 內用 (需要 table_id)
- `takeout` - 外帶
- `delivery` - 外送 (需要 customer_name, customer_phone, delivery_address)

**Response:**
```json
{
  "success": true,
  "message": "Order created successfully",
  "data": {
    "id": "uuid",
    "order_no": "20240101-0001",
    "order_type": "dine_in",
    "subtotal": 100.00,
    "tax": 5.00,
    "total": 105.00,
    "status": "pending",
    "payment_status": "unpaid",
    "items": [
      {
        "id": "uuid",
        "item_id": "uuid",
        "item_name": "珍珠奶茶",
        "unit_price": 50.00,
        "quantity": 2,
        "subtotal": 100.00,
        "options": {
          "sugar": "少糖",
          "ice": "去冰"
        },
        "status": "pending"
      }
    ]
  }
}
```

#### PUT /api/v1/orders/:id/status
更新訂單狀態

**Request:**
```json
{
  "status": "preparing"
}
```

**狀態選項:**
- `pending` - 待處理
- `preparing` - 準備中
- `ready` - 已完成
- `completed` - 已完成
- `cancelled` - 已取消

#### POST /api/v1/orders/:id/items
新增商品到訂單

**Request:**
```json
{
  "item_id": "uuid",
  "quantity": 1,
  "options": {},
  "notes": "備註"
}
```

#### POST /api/v1/orders/:id/payments
新增付款

**Request:**
```json
{
  "method": "cash",
  "amount": 126.00,
  "received": 200.00
}
```

**付款方式:**
- `cash` - 現金 (需提供 received 收款金額)
- `credit_card` - 信用卡
- `line_pay` - Line Pay
- `other` - 其他

**Response:**
```json
{
  "success": true,
  "message": "Payment added successfully",
  "data": {
    "id": "uuid",
    "order_no": "20240101-0001",
    "total": 126.00,
    "payment_status": "paid",
    "status": "completed",
    "payments": [
      {
        "id": "uuid",
        "method": "cash",
        "amount": 126.00,
        "received": 200.00,
        "change": 74.00,
        "status": "completed"
      }
    ]
  }
}
```

#### GET /api/v1/orders/sales/daily
取得每日銷售額

**Query Parameters:**
- `date` (string) - 日期 (YYYY-MM-DD 格式, 預設今日)

**Response:**
```json
{
  "success": true,
  "data": {
    "date": "2024-01-01",
    "total_sales": 12580.00
  }
}
```

---

## 測試範例

### 完整下單流程

```bash
# 1. 登入
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  | jq -r '.data.token')

# 2. 查看菜單
curl -s http://localhost:8080/api/v1/menu/items \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 3. 建立訂單
ORDER_ID=$(curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_type": "dine_in",
    "table_id": "66666666-6666-6666-6666-666666666661",
    "items": [
      {
        "item_id": "55555555-5555-5555-5555-555555555551",
        "quantity": 2,
        "options": {"sugar": "少糖", "ice": "去冰"}
      }
    ]
  }' | jq -r '.data.id')

# 4. 查看訂單
curl -s http://localhost:8080/api/v1/orders/$ORDER_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 5. 付款
curl -s -X POST http://localhost:8080/api/v1/orders/$ORDER_ID/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "method": "cash",
    "amount": 105.00,
    "received": 200.00
  }' | jq '.'

# 6. 查看當日銷售
curl -s http://localhost:8080/api/v1/orders/sales/daily \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

---

## 錯誤處理

所有錯誤回應格式：

```json
{
  "success": false,
  "error": "錯誤訊息"
}
```

### HTTP 狀態碼

- `200` - 成功
- `400` - 請求錯誤 (參數不正確)
- `401` - 未授權 (未登入或 token 無效)
- `403` - 禁止存取 (權限不足)
- `404` - 資源不存在
- `500` - 伺服器錯誤

---

## 測試帳號

| 姓名 | Email | PIN | 密碼 | 角色 |
|------|-------|-----|------|------|
| 王大明 | admin@example.com | 1234 | admin123 | admin |
| 李小華 | cashier@example.com | 5678 | admin123 | cashier |
| 陳廚師 | kitchen@example.com | 9012 | admin123 | kitchen |

**Tenant ID:** `11111111-1111-1111-1111-111111111111`
**Store ID:** `22222222-2222-2222-2222-222222222221`

---

## 自動化測試

執行完整 API 測試：

```bash
cd pos-backend
./scripts/test_api.sh
```

這個腳本會測試所有主要 API 端點。
