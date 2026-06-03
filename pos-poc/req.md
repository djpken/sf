# 餐飲 POS 系統設計文件

## 專案概述

### 技術選型
- **前端**：Flutter（跨平台：平板、手機、桌面）
- **後端**：Go（高併發、部署簡單）
- **資料庫**：PostgreSQL（主要）、SQLite（本地離線）、Redis（快取）

### 營運需求
| 項目 | 規格 |
|------|------|
| 營業型態 | 內用、外帶、外送 |
| 硬體需求 | 收據機、錢箱、掃碼槍 |
| 付款方式 | 現金、信用卡、Line Pay |
| 發票 | 電子發票 |
| 規模 | 多店 |

---

## 系統架構

```
┌─────────────────────────────────────────────────────────────────┐
│                         雲端服務層                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────────┐ │
│  │ API GW  │  │ 訂單服務 │  │ 報表服務 │  │ 第三方整合          │ │
│  │ (Kong)  │  │         │  │         │  │ - 電子發票          │ │
│  └────┬────┘  └────┬────┘  └────┬────┘  │ - Line Pay         │ │
│       │            │            │       │ - 信用卡            │ │
│       └────────────┼────────────┘       │ - 外送平台          │ │
│                    │                    └─────────────────────┘ │
│              ┌─────┴─────┐                                      │
│              │ PostgreSQL │  ┌───────┐                          │
│              │ (主資料庫)  │  │ Redis │                          │
│              └───────────┘  └───────┘                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS / WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        各分店 (Store)                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ POS 主機     │    │ 廚房顯示器   │    │ 自助點餐機   │        │
│  │ (Flutter)    │    │ (KDS)        │    │ (Kiosk)     │        │
│  └──────┬───────┘    └──────────────┘    └──────────────┘       │
│         │                                                       │
│  ┌──────┴───────────────────────────────────────────────┐       │
│  │              本地服務 (Go Local Server)               │       │
│  │  - 離線訂單處理                                       │       │
│  │  - 硬體控制 (收據機、錢箱、掃碼槍)                     │       │
│  │  - 資料同步                                          │       │
│  │  - SQLite (本地備份)                                 │       │
│  └──────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 資料庫設計

### ER 關係圖

```
tenants (租戶/品牌)
    │
    ├── stores (分店)
    │       ├── tables (桌位)
    │       ├── inventory (庫存)
    │       └── orders (訂單)
    │               ├── order_items (訂單明細)
    │               ├── payments (付款紀錄)
    │               └── invoices (電子發票)
    │
    ├── employees (員工)
    │
    ├── menu_categories (菜單分類)
    │       └── menu_items (商品)
    │               └── menu_item_prices (分店價格)
```

### 資料表結構

#### 租戶/品牌 (tenants)

```sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    tax_id VARCHAR(20),              -- 統一編號
    invoice_config JSONB,            -- 電子發票設定
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 分店 (stores)

```sql
CREATE TABLE stores (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    name VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    settings JSONB,                  -- 分店設定 (營業時間等)
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 員工 (employees)

```sql
CREATE TABLE employees (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    store_id UUID REFERENCES stores(id),
    name VARCHAR(50) NOT NULL,
    pin_code VARCHAR(10),            -- 快速登入碼
    role VARCHAR(20),                -- admin, manager, cashier, kitchen
    permissions JSONB,
    is_active BOOLEAN DEFAULT true
);
```

#### 菜單分類 (menu_categories)

```sql
CREATE TABLE menu_categories (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    name VARCHAR(50) NOT NULL,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);
```

#### 商品 (menu_items)

```sql
CREATE TABLE menu_items (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    category_id UUID REFERENCES menu_categories(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2),              -- 成本
    image_url TEXT,
    barcode VARCHAR(50),             -- 條碼
    is_active BOOLEAN DEFAULT true,
    options JSONB,                   -- 加料、客製化選項
    tax_type VARCHAR(20),            -- 稅別
    sort_order INT DEFAULT 0
);
```

#### 商品分店價格 (menu_item_prices)

```sql
CREATE TABLE menu_item_prices (
    id UUID PRIMARY KEY,
    item_id UUID REFERENCES menu_items(id),
    store_id UUID REFERENCES stores(id),
    price DECIMAL(10,2) NOT NULL,
    UNIQUE(item_id, store_id)
);
```

#### 桌位 (tables)

```sql
CREATE TABLE tables (
    id UUID PRIMARY KEY,
    store_id UUID REFERENCES stores(id),
    name VARCHAR(20) NOT NULL,       -- 桌號
    capacity INT,
    area VARCHAR(50),                -- 區域 (室內、戶外)
    status VARCHAR(20) DEFAULT 'available'  -- available, occupied, reserved
);
```

#### 訂單 (orders)

```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY,
    store_id UUID REFERENCES stores(id),
    order_no VARCHAR(30) NOT NULL,          -- 單號 (每日流水號)
    order_type VARCHAR(20) NOT NULL,        -- dine_in, takeout, delivery
    table_id UUID REFERENCES tables(id),
    customer_name VARCHAR(50),
    customer_phone VARCHAR(20),
    delivery_address TEXT,
    delivery_platform VARCHAR(20),          -- uber_eats, foodpanda, 自家外送
    
    subtotal DECIMAL(10,2),
    discount DECIMAL(10,2) DEFAULT 0,
    tax DECIMAL(10,2),
    service_charge DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2),
    
    status VARCHAR(20) DEFAULT 'pending',   -- pending, preparing, ready, completed, cancelled
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    
    employee_id UUID REFERENCES employees(id),
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 訂單明細 (order_items)

```sql
CREATE TABLE order_items (
    id UUID PRIMARY KEY,
    order_id UUID REFERENCES orders(id),
    item_id UUID REFERENCES menu_items(id),
    item_name VARCHAR(100),          -- 快照
    unit_price DECIMAL(10,2),
    quantity INT NOT NULL,
    subtotal DECIMAL(10,2),
    options JSONB,                   -- 選擇的加料
    notes TEXT,                      -- 備註 (去冰、少糖)
    status VARCHAR(20) DEFAULT 'pending'   -- pending, preparing, ready
);
```

#### 付款紀錄 (payments)

```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY,
    order_id UUID REFERENCES orders(id),
    method VARCHAR(20) NOT NULL,     -- cash, credit_card, line_pay
    amount DECIMAL(10,2) NOT NULL,
    received DECIMAL(10,2),          -- 收款金額 (現金用)
    change DECIMAL(10,2),            -- 找零
    reference_no VARCHAR(100),       -- 交易序號
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### 電子發票 (invoices)

```sql
CREATE TABLE invoices (
    id UUID PRIMARY KEY,
    order_id UUID REFERENCES orders(id),
    invoice_no VARCHAR(20),          -- 發票號碼
    random_code VARCHAR(4),          -- 隨機碼
    buyer_tax_id VARCHAR(10),        -- 買方統編
    amount DECIMAL(10,2),
    tax DECIMAL(10,2),
    status VARCHAR(20),              -- pending, issued, voided
    carrier_type VARCHAR(20),        -- 載具類型
    carrier_no VARCHAR(50),          -- 載具號碼
    issued_at TIMESTAMPTZ,
    raw_response JSONB
);
```

#### 庫存 (inventory)

```sql
CREATE TABLE inventory (
    id UUID PRIMARY KEY,
    store_id UUID REFERENCES stores(id),
    item_id UUID REFERENCES menu_items(id),
    quantity DECIMAL(10,2),
    unit VARCHAR(20),
    low_stock_threshold DECIMAL(10,2),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, item_id)
);
```

### 索引

```sql
CREATE INDEX idx_orders_store_date ON orders(store_id, created_at);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_menu_items_barcode ON menu_items(barcode);
CREATE INDEX idx_invoices_order ON invoices(order_id);
CREATE INDEX idx_payments_order ON payments(order_id);
```

---

## Go 後端結構

```
pos-backend/
├── cmd/
│   ├── api/                      # 雲端 API 服務
│   │   └── main.go
│   └── local/                    # 門市本地服務
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── domain/                   # 領域模型
│   │   ├── tenant.go
│   │   ├── store.go
│   │   ├── employee.go
│   │   ├── menu.go
│   │   ├── order.go
│   │   ├── payment.go
│   │   └── invoice.go
│   ├── repository/               # 資料存取層
│   │   ├── postgres/
│   │   │   ├── tenant_repo.go
│   │   │   ├── store_repo.go
│   │   │   ├── menu_repo.go
│   │   │   ├── order_repo.go
│   │   │   └── ...
│   │   └── sqlite/               # 本地離線用
│   │       └── local_repo.go
│   ├── service/                  # 業務邏輯
│   │   ├── auth_service.go
│   │   ├── menu_service.go
│   │   ├── order_service.go
│   │   ├── payment_service.go
│   │   ├── invoice_service.go
│   │   ├── report_service.go
│   │   └── sync_service.go
│   ├── handler/                  # HTTP handlers
│   │   ├── auth_handler.go
│   │   ├── menu_handler.go
│   │   ├── order_handler.go
│   │   ├── payment_handler.go
│   │   └── report_handler.go
│   ├── middleware/
│   │   ├── auth.go
│   │   ├── cors.go
│   │   └── logger.go
│   └── integration/              # 第三方整合
│       ├── einvoice/             # 電子發票
│       │   ├── provider.go
│       │   ├── turnkey.go        # 關貿
│       │   └── ecpay.go          # 綠界
│       ├── linepay/
│       │   └── client.go
│       ├── creditcard/           # 信用卡
│       │   ├── tappay.go
│       │   └── ecpay.go
│       └── delivery/             # 外送平台
│           ├── ubereats.go
│           └── foodpanda.go
├── pkg/
│   ├── hardware/                 # 硬體控制
│   │   ├── printer/
│   │   │   ├── escpos.go         # ESC/POS 協定
│   │   │   └── receipt.go        # 收據格式
│   │   ├── cashdrawer/
│   │   │   └── drawer.go
│   │   └── scanner/
│   │       └── barcode.go
│   └── utils/
│       ├── crypto.go
│       ├── validator.go
│       └── response.go
├── migrations/                   # 資料庫遷移
│   ├── 000001_init.up.sql
│   └── 000001_init.down.sql
├── scripts/
├── Dockerfile
├── docker-compose.yml
└── go.mod
```

### API 路由設計

```
/api/v1/
├── auth/
│   ├── POST   /login             # 登入
│   ├── POST   /pin-login         # PIN 碼快速登入
│   └── POST   /logout            # 登出
│
├── stores/
│   ├── GET    /                  # 取得分店列表
│   ├── GET    /:id               # 取得分店詳情
│   ├── POST   /                  # 新增分店
│   └── PUT    /:id               # 更新分店
│
├── menu/
│   ├── GET    /categories        # 取得分類列表
│   ├── POST   /categories        # 新增分類
│   ├── GET    /items             # 取得商品列表
│   ├── GET    /items/:id         # 取得商品詳情
│   ├── POST   /items             # 新增商品
│   ├── PUT    /items/:id         # 更新商品
│   └── DELETE /items/:id         # 刪除商品
│
├── orders/
│   ├── GET    /                  # 取得訂單列表
│   ├── GET    /:id               # 取得訂單詳情
│   ├── POST   /                  # 建立訂單
│   ├── PUT    /:id               # 更新訂單
│   ├── PUT    /:id/status        # 更新訂單狀態
│   └── POST   /:id/cancel        # 取消訂單
│
├── payments/
│   ├── POST   /cash              # 現金付款
│   ├── POST   /credit-card       # 信用卡付款
│   ├── POST   /line-pay/request  # Line Pay 請求
│   └── POST   /line-pay/confirm  # Line Pay 確認
│
├── invoices/
│   ├── POST   /issue             # 開立發票
│   ├── POST   /void              # 作廢發票
│   └── GET    /:id               # 查詢發票
│
├── tables/
│   ├── GET    /                  # 取得桌位列表
│   ├── PUT    /:id/status        # 更新桌位狀態
│   └── POST   /:id/transfer      # 換桌
│
├── reports/
│   ├── GET    /daily             # 日報表
│   ├── GET    /monthly           # 月報表
│   ├── GET    /sales             # 銷售報表
│   └── GET    /products          # 商品銷售排行
│
├── inventory/
│   ├── GET    /                  # 庫存列表
│   ├── PUT    /:id               # 更新庫存
│   └── POST   /adjust            # 庫存調整
│
└── sync/
    ├── POST   /upload            # 上傳離線資料
    └── GET    /download          # 下載最新資料
```

---

## Flutter 前端結構

```
pos_flutter/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── routes.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── api_endpoints.dart
│   │   │   └── colors.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   ├── api_interceptor.dart
│   │   │   └── offline_queue.dart
│   │   ├── local_db/
│   │   │   ├── database.dart         # Drift/SQLite
│   │   │   └── tables.dart
│   │   └── errors/
│   │       └── failures.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── login_page.dart
│   │   │   │   │   └── pin_login_page.dart
│   │   │   │   └── widgets/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   └── usecases/
│   │   │   └── data/
│   │   │       ├── models/
│   │   │       └── repositories/
│   │   ├── pos/                       # 點餐主畫面
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── pos_page.dart
│   │   │   │   │   └── checkout_page.dart
│   │   │   │   ├── widgets/
│   │   │   │   │   ├── menu_category_tabs.dart
│   │   │   │   │   ├── menu_grid.dart
│   │   │   │   │   ├── menu_item_card.dart
│   │   │   │   │   ├── cart_panel.dart
│   │   │   │   │   ├── cart_item_tile.dart
│   │   │   │   │   ├── order_type_selector.dart
│   │   │   │   │   ├── table_selector.dart
│   │   │   │   │   ├── item_options_dialog.dart
│   │   │   │   │   └── payment_dialog.dart
│   │   │   │   └── bloc/
│   │   │   │       ├── cart_bloc.dart
│   │   │   │       └── menu_bloc.dart
│   │   │   ├── domain/
│   │   │   └── data/
│   │   ├── orders/                    # 訂單管理
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── orders_page.dart
│   │   │   │   │   └── order_detail_page.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── order_card.dart
│   │   │   │       └── order_status_chip.dart
│   │   │   ├── domain/
│   │   │   └── data/
│   │   ├── kitchen/                   # 廚房顯示 (KDS)
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── kitchen_display_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── kitchen_order_card.dart
│   │   │   └── ...
│   │   ├── tables/                    # 桌位管理
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── table_map_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── table_widget.dart
│   │   │   └── ...
│   │   ├── menu_management/           # 菜單管理
│   │   │   └── ...
│   │   ├── reports/                   # 報表
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   ├── daily_report_page.dart
│   │   │   │   │   └── sales_report_page.dart
│   │   │   │   └── widgets/
│   │   │   └── ...
│   │   ├── inventory/                 # 庫存管理
│   │   │   └── ...
│   │   └── settings/                  # 設定
│   │       ├── presentation/
│   │       │   ├── pages/
│   │       │   │   ├── settings_page.dart
│   │       │   │   ├── printer_settings_page.dart
│   │       │   │   └── store_settings_page.dart
│   │       │   └── widgets/
│   │       └── ...
│   └── shared/
│       ├── widgets/
│       │   ├── loading_widget.dart
│       │   ├── error_widget.dart
│       │   ├── custom_button.dart
│       │   └── numpad.dart
│       ├── models/
│       └── utils/
│           ├── formatters.dart
│           └── validators.dart
├── assets/
│   ├── images/
│   └── fonts/
├── test/
└── pubspec.yaml
```

### 主要畫面設計

#### 1. 點餐主畫面 (POS Page)
```
┌────────────────────────────────────────────────────────────────────┐
│ [內用] [外帶] [外送]                              員工: 王小明  09:30 │
├────────────────────────────────────────────────────────────────────┤
│                                          │                         │
│  [飲料] [餐點] [小食] [甜點]                │   購物車                │
│                                          │                         │
│  ┌───────┐ ┌───────┐ ┌───────┐          │   桌號: A3              │
│  │ 珍奶  │ │ 紅茶  │ │ 綠茶  │          │                         │
│  │ $50   │ │ $30   │ │ $30   │          │   1. 珍珠奶茶 x2  $100   │
│  └───────┘ └───────┘ └───────┘          │      少糖、去冰          │
│                                          │   2. 雞排      x1  $70   │
│  ┌───────┐ ┌───────┐ ┌───────┐          │                         │
│  │ 奶茶  │ │ 拿鐵  │ │ 美式  │          │   ─────────────────     │
│  │ $40   │ │ $60   │ │ $50   │          │   小計:         $170    │
│  └───────┘ └───────┘ └───────┘          │   折扣:           $0    │
│                                          │   ─────────────────     │
│  ┌───────┐ ┌───────┐ ┌───────┐          │   總計:         $170    │
│  │ 雞排  │ │ 薯條  │ │ 漢堡  │          │                         │
│  │ $70   │ │ $40   │ │ $90   │          │   [清空] [掛單] [結帳]   │
│  └───────┘ └───────┘ └───────┘          │                         │
│                                          │                         │
└────────────────────────────────────────────────────────────────────┘
```

#### 2. 結帳畫面 (Checkout Dialog)
```
┌─────────────────────────────────────────┐
│              結帳                        │
├─────────────────────────────────────────┤
│                                         │
│   應付金額:  NT$ 170                     │
│                                         │
│   付款方式:                              │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│   │  現金   │ │ 信用卡  │ │ Line Pay│  │
│   └─────────┘ └─────────┘ └─────────┘  │
│                                         │
│   [數字鍵盤輸入現金金額]                   │
│   ┌───┬───┬───┐                        │
│   │ 7 │ 8 │ 9 │  收款: $200            │
│   ├───┼───┼───┤  找零: $30             │
│   │ 4 │ 5 │ 6 │                        │
│   ├───┼───┼───┤                        │
│   │ 1 │ 2 │ 3 │                        │
│   ├───┼───┼───┤                        │
│   │ C │ 0 │ ⌫ │                        │
│   └───┴───┴───┘                        │
│                                         │
│   發票:                                 │
│   ○ 電子發票  ○ 載具  ○ 統編            │
│                                         │
│          [取消]  [確認結帳]              │
└─────────────────────────────────────────┘
```

---

## 硬體整合

### 整合方式總覽

| 設備 | 協定 | 整合方式 |
|------|------|----------|
| 收據機 | ESC/POS | Go local server 透過 USB/網路列印 |
| 錢箱 | 收據機觸發 | 列印時送開啟指令 |
| 掃碼槍 | USB HID | 模擬鍵盤輸入，Flutter 直接接收 |
| 刷卡機 | SDK | TapPay / 綠界 SDK |

### 收據機 ESC/POS 指令

```go
// pkg/hardware/printer/escpos.go

package printer

const (
    ESC = 0x1B
    GS  = 0x1D
    
    // 初始化
    Init = "\x1B\x40"
    
    // 對齊
    AlignLeft   = "\x1B\x61\x00"
    AlignCenter = "\x1B\x61\x01"
    AlignRight  = "\x1B\x61\x02"
    
    // 字體大小
    FontNormal = "\x1D\x21\x00"
    FontDouble = "\x1D\x21\x11"
    
    // 強調
    BoldOn  = "\x1B\x45\x01"
    BoldOff = "\x1B\x45\x00"
    
    // 切紙
    CutPaper = "\x1D\x56\x00"
    
    // 開錢箱
    OpenDrawer = "\x1B\x70\x00\x19\xFA"
)
```

### 收據格式範例

```go
// pkg/hardware/printer/receipt.go

func (p *Printer) PrintReceipt(order *domain.Order) error {
    var buf bytes.Buffer
    
    // 初始化
    buf.WriteString(Init)
    
    // 店名 (置中、放大)
    buf.WriteString(AlignCenter)
    buf.WriteString(FontDouble)
    buf.WriteString(order.StoreName + "\n")
    buf.WriteString(FontNormal)
    buf.WriteString(order.StoreAddress + "\n")
    buf.WriteString(order.StorePhone + "\n")
    buf.WriteString("--------------------------------\n")
    
    // 訂單資訊
    buf.WriteString(AlignLeft)
    buf.WriteString(fmt.Sprintf("單號: %s\n", order.OrderNo))
    buf.WriteString(fmt.Sprintf("時間: %s\n", order.CreatedAt.Format("2006-01-02 15:04")))
    buf.WriteString(fmt.Sprintf("類型: %s\n", order.OrderType))
    if order.TableName != "" {
        buf.WriteString(fmt.Sprintf("桌號: %s\n", order.TableName))
    }
    buf.WriteString("--------------------------------\n")
    
    // 品項
    for _, item := range order.Items {
        buf.WriteString(fmt.Sprintf("%-16s x%d  $%d\n", 
            item.Name, item.Quantity, item.Subtotal))
        if item.Notes != "" {
            buf.WriteString(fmt.Sprintf("  (%s)\n", item.Notes))
        }
    }
    buf.WriteString("--------------------------------\n")
    
    // 金額
    buf.WriteString(AlignRight)
    buf.WriteString(fmt.Sprintf("小計: $%d\n", order.Subtotal))
    if order.Discount > 0 {
        buf.WriteString(fmt.Sprintf("折扣: -$%d\n", order.Discount))
    }
    buf.WriteString(FontDouble)
    buf.WriteString(fmt.Sprintf("總計: $%d\n", order.Total))
    buf.WriteString(FontNormal)
    
    // 付款資訊
    buf.WriteString(fmt.Sprintf("付款: %s\n", order.PaymentMethod))
    if order.PaymentMethod == "cash" {
        buf.WriteString(fmt.Sprintf("收款: $%d\n", order.Received))
        buf.WriteString(fmt.Sprintf("找零: $%d\n", order.Change))
    }
    buf.WriteString("--------------------------------\n")
    
    // 發票資訊
    buf.WriteString(AlignCenter)
    buf.WriteString(fmt.Sprintf("發票號碼: %s\n", order.InvoiceNo))
    buf.WriteString(fmt.Sprintf("隨機碼: %s\n", order.RandomCode))
    
    // 謝謝光臨
    buf.WriteString("\n謝謝光臨\n\n")
    
    // 切紙
    buf.WriteString(CutPaper)
    
    return p.Write(buf.Bytes())
}
```

---

## 第三方服務整合

### 服務商建議

| 功能 | 服務商 | 備註 |
|------|--------|------|
| 電子發票 | 關貿網路 (Turnkey) | 政府標準、穩定 |
| 電子發票 | 綠界 ECPay | 整合方便 |
| 電子發票 | 鯨躍科技 | API 好用 |
| Line Pay | Line Pay API | 官方 API |
| 信用卡 | TapPay | 整合簡單、手續費低 |
| 信用卡 | 綠界 ECPay | 多功能整合 |
| 簡訊 | 三竹簡訊 | 台灣本土 |
| 簡訊 | Twilio | 國際化 |
| 推播 | Firebase Cloud Messaging | 免費 |

### 電子發票流程

```
1. 結帳完成
      │
      ▼
2. 呼叫發票 API
      │
      ├── 載具 (手機條碼/自然人憑證)
      │       └── 直接存入載具
      │
      ├── 統編
      │       └── 開立 B2B 發票
      │
      └── 雲端發票
              └── 存入會員載具或店家載具
      │
      ▼
3. 取得發票號碼、隨機碼
      │
      ▼
4. 列印發票證明聯 (選擇性)
```

### Line Pay 流程

```
1. 建立付款請求 (Request API)
      │
      ▼
2. 取得付款 URL
      │
      ▼
3. 顯示 QR Code 或導向 Line App
      │
      ▼
4. 用戶在 Line 確認付款
      │
      ▼
5. Line 回呼 Confirm API
      │
      ▼
6. 確認交易完成
```

---

## 開發階段規劃

### Phase 1: MVP (4-6 週)
- [ ] 基礎架構建置
- [ ] 單店、內用 + 外帶
- [ ] 現金付款
- [ ] 收據列印
- [ ] 基本報表

### Phase 2: 付款整合 (2-3 週)
- [ ] Line Pay 整合
- [ ] 信用卡整合
- [ ] 電子發票整合

### Phase 3: 多店擴展 (3-4 週)
- [ ] 多租戶架構
- [ ] 離線模式
- [ ] 資料同步
- [ ] 總部管理後台

### Phase 4: 進階功能 (4-6 週)
- [ ] 外送平台串接
- [ ] 廚房顯示系統 (KDS)
- [ ] 庫存管理
- [ ] 會員系統
- [ ] 進階報表分析

---

## 環境建置

### Docker Compose (開發環境)

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: pos
      POSTGRES_PASSWORD: pos_password
      POSTGRES_DB: pos_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  api:
    build:
      context: ./pos-backend
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://pos:pos_password@postgres:5432/pos_db
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis

volumes:
  postgres_data:
```

### Go 相依套件

```go
// go.mod
module pos-backend

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    gorm.io/gorm v1.25.5
    gorm.io/driver/postgres v1.5.4
    github.com/redis/go-redis/v9 v9.3.0
    github.com/golang-jwt/jwt/v5 v5.2.0
    github.com/google/uuid v1.5.0
    github.com/spf13/viper v1.18.1
    go.uber.org/zap v1.26.0
)
```

### Flutter 相依套件

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 狀態管理
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # 網路
  dio: ^5.4.0
  
  # 本地資料庫
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  
  # UI
  google_fonts: ^6.1.0
  flutter_screenutil: ^5.9.0
  
  # 工具
  intl: ^0.18.1
  uuid: ^4.2.1
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7
  drift_dev: ^2.14.0
```

---

## 備註

### 注意事項
1. 電子發票需向財政部申請營業人資格
2. Line Pay 需申請商家帳號
3. 信用卡收單需與銀行或第三方金流簽約
4. 資料備份策略需提前規劃
5. 離線模式的資料衝突處理邏輯

### 參考資源
- [財政部電子發票整合服務平台](https://www.einvoice.nat.gov.tw/)
- [Line Pay 開發者文件](https://pay.line.me/developers/)
- [TapPay 開發者文件](https://docs.tappaysdk.com/)
- [ESC/POS 指令集](https://reference.epson-biz.com/modules/ref_escpos/)
