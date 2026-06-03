# 快速測試指令

複製貼上即可測試所有 API

## 1. 啟動服務

```bash
# 終端機 1: 啟動資料庫
cd /Users/kunkun/Projects/sf/pos-poc/pos-backend
make dev

# 等待 10 秒讓資料庫啟動

# 終端機 2: 執行資料庫遷移
brew install golang-migrate  # 只需執行一次
./scripts/migrate.sh up

# 終端機 2: 啟動 API 服務
make run
```

## 2. 基礎測試

```bash
# 健康檢查
curl http://localhost:8080/health

# 登入並取得 Token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  | jq -r '.data.token')

echo "Token: $TOKEN"
```

## 3. 菜單測試

```bash
# 列出所有分類
curl -s http://localhost:8080/api/v1/menu/categories \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 列出所有商品
curl -s http://localhost:8080/api/v1/menu/items \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 透過條碼查詢商品
curl -s http://localhost:8080/api/v1/menu/items/barcode/1001 \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 建立新分類
curl -s -X POST http://localhost:8080/api/v1/menu/categories \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"測試分類","sort_order":99}' | jq '.'

# 建立新商品
curl -s -X POST http://localhost:8080/api/v1/menu/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"測試商品",
    "description":"這是測試商品",
    "price":99.99,
    "category_id":"44444444-4444-4444-4444-444444444441"
  }' | jq '.'
```

## 4. 訂單測試

```bash
# 建立訂單 (內用)
ORDER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_type": "dine_in",
    "table_id": "66666666-6666-6666-6666-666666666661",
    "items": [
      {
        "item_id": "55555555-5555-5555-5555-555555555551",
        "quantity": 2,
        "options": {"sugar": "少糖", "ice": "去冰"},
        "notes": "不要珍珠"
      },
      {
        "item_id": "55555555-5555-5555-5555-555555555555",
        "quantity": 1
      }
    ],
    "notes": "快一點"
  }')

echo "$ORDER_RESPONSE" | jq '.'

# 取得訂單 ID
ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.id')
echo "Order ID: $ORDER_ID"

# 查看訂單詳情
curl -s http://localhost:8080/api/v1/orders/$ORDER_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 列出所有訂單
curl -s http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 列出待處理訂單
curl -s "http://localhost:8080/api/v1/orders?status=pending" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

## 5. 訂單狀態更新

```bash
# 更新訂單狀態為準備中
curl -s -X PUT http://localhost:8080/api/v1/orders/$ORDER_ID/status \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"preparing"}' | jq '.'

# 新增商品到訂單
curl -s -X POST http://localhost:8080/api/v1/orders/$ORDER_ID/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "item_id": "55555555-5555-5555-5555-555555555558",
    "quantity": 1,
    "notes": "加大"
  }' | jq '.'
```

## 6. 付款測試

```bash
# 現金付款
curl -s -X POST http://localhost:8080/api/v1/orders/$ORDER_ID/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "method": "cash",
    "amount": 200,
    "received": 500
  }' | jq '.'

# 查看更新後的訂單 (應該已付款完成)
curl -s http://localhost:8080/api/v1/orders/$ORDER_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.data | {
    order_no,
    status,
    payment_status,
    total,
    payments
  }'
```

## 7. 建立外帶訂單

```bash
# 外帶訂單
TAKEOUT_ORDER=$(curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_type": "takeout",
    "customer_name": "張三",
    "customer_phone": "0912345678",
    "items": [
      {
        "item_id": "55555555-5555-5555-5555-555555555552",
        "quantity": 3
      }
    ]
  }')

echo "$TAKEOUT_ORDER" | jq '.'
TAKEOUT_ID=$(echo "$TAKEOUT_ORDER" | jq -r '.data.id')

# 信用卡付款
curl -s -X POST http://localhost:8080/api/v1/orders/$TAKEOUT_ID/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "method": "credit_card",
    "amount": 94.50,
    "reference_no": "CC-123456789"
  }' | jq '.'
```

## 8. 建立外送訂單

```bash
# 外送訂單
DELIVERY_ORDER=$(curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_type": "delivery",
    "customer_name": "李四",
    "customer_phone": "0987654321",
    "delivery_address": "台北市信義區信義路五段7號",
    "delivery_platform": "uber_eats",
    "items": [
      {
        "item_id": "55555555-5555-5555-5555-555555555556",
        "quantity": 2
      }
    ]
  }')

echo "$DELIVERY_ORDER" | jq '.'
```

## 9. 報表測試

```bash
# 查看今日銷售額
curl -s http://localhost:8080/api/v1/orders/sales/daily \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 查看特定日期銷售額
curl -s "http://localhost:8080/api/v1/orders/sales/daily?date=2024-01-01" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

## 10. 進階查詢

```bash
# 查詢已完成訂單
curl -s "http://localhost:8080/api/v1/orders?status=completed" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 查詢未付款訂單
curl -s "http://localhost:8080/api/v1/orders?payment_status=unpaid" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 分頁查詢
curl -s "http://localhost:8080/api/v1/orders?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 依分類查詢商品
curl -s "http://localhost:8080/api/v1/menu/items?category_id=44444444-4444-4444-4444-444444444441" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

## 11. 完整下單流程

```bash
# 完整流程：從點餐到付款
echo "=== 開始完整下單流程 ==="

# 1. 查看菜單
echo "1. 查看菜單..."
curl -s http://localhost:8080/api/v1/menu/items \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.data[] | {id, name, price}'

# 2. 建立訂單
echo "2. 建立訂單..."
NEW_ORDER=$(curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_type": "dine_in",
    "table_id": "66666666-6666-6666-6666-666666666662",
    "items": [
      {"item_id": "55555555-5555-5555-5555-555555555551", "quantity": 1},
      {"item_id": "55555555-5555-5555-5555-555555555555", "quantity": 1}
    ]
  }')

NEW_ORDER_ID=$(echo "$NEW_ORDER" | jq -r '.data.id')
TOTAL=$(echo "$NEW_ORDER" | jq -r '.data.total')
echo "訂單建立成功! ID: $NEW_ORDER_ID, 總額: NT$ $TOTAL"

# 3. 查看訂單
echo "3. 查看訂單詳情..."
curl -s http://localhost:8080/api/v1/orders/$NEW_ORDER_ID \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.data | {order_no, total, status, items: .items | length}'

# 4. 付款
echo "4. 付款..."
curl -s -X POST http://localhost:8080/api/v1/orders/$NEW_ORDER_ID/payments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"method\":\"cash\",\"amount\":$TOTAL,\"received\":500}" \
  | jq '.data | {order_no, payment_status, payments}'

echo "=== 流程完成 ==="
```

## 12. 自動化測試腳本

```bash
# 執行完整測試腳本
./scripts/test_api.sh
```

## 13. 清理測試資料

```bash
# 如需重置資料庫
make clean
make dev
./scripts/migrate.sh up
```

## 常用指令快捷方式

```bash
# 設定環境變數
export API_BASE="http://localhost:8080/api/v1"
export TOKEN=$(curl -s -X POST $API_BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  | jq -r '.data.token')

# 之後可以直接使用
curl -s $API_BASE/menu/items -H "Authorization: Bearer $TOKEN" | jq '.'
```

## 測試帳號資訊

```
Email: admin@example.com
Password: admin123
PIN: 1234
Tenant ID: 11111111-1111-1111-1111-111111111111
Store ID: 22222222-2222-2222-2222-222222222221
```

## 注意事項

1. 確保已安裝 `jq` (JSON 處理工具)
   ```bash
   brew install jq
   ```

2. 確保服務正在運行
   ```bash
   curl http://localhost:8080/health
   ```

3. 如果 Token 過期，重新登入取得新 Token
   ```bash
   TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"admin123"}' \
     | jq -r '.data.token')
   ```
