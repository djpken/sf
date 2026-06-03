# POS Flutter

餐廳 POS 系統的 Flutter 前端應用程式

## 功能特色

- 📱 支援平板、手機和桌面裝置
- 🔐 雙重登入方式（Email/Password 和 PIN）
- 📦 Clean Architecture 架構
- 🎨 Material Design 3
- 🔄 BLoC 狀態管理
- 🌐 RESTful API 整合

## 技術架構

### 核心套件
- **flutter_bloc**: 狀態管理
- **dio**: HTTP 網路請求
- **flutter_secure_storage**: 安全儲存
- **shared_preferences**: 本地資料儲存
- **get_it**: 依賴注入
- **equatable**: 值物件比較

### UI 套件
- **flutter_screenutil**: 響應式佈局
- **google_fonts**: 字型
- **cached_network_image**: 圖片快取

## 專案結構

```
lib/
├── core/
│   ├── constants/          # 常數定義
│   │   ├── app_constants.dart
│   │   └── app_colors.dart
│   ├── di/                 # 依賴注入
│   │   └── injection.dart
│   ├── network/            # 網路層
│   │   └── api_client.dart
│   └── storage/            # 儲存層
│       └── secure_storage.dart
├── data/
│   ├── models/             # 資料模型
│   │   ├── employee.dart
│   │   ├── menu_category.dart
│   │   ├── menu_item.dart
│   │   ├── order.dart
│   │   ├── order_item.dart
│   │   ├── payment.dart
│   │   └── table.dart
│   └── repositories/       # 資料倉庫
│       ├── auth_repository.dart
│       ├── menu_repository.dart
│       ├── order_repository.dart
│       └── table_repository.dart
├── presentation/
│   ├── auth/              # 認證功能
│   │   ├── bloc/
│   │   │   ├── auth_bloc.dart
│   │   │   ├── auth_event.dart
│   │   │   └── auth_state.dart
│   │   └── pages/
│   │       ├── login_page.dart
│   │       └── pin_login_page.dart
│   └── home/              # 主頁面
│       └── pages/
│           └── home_page.dart
└── main.dart
```

## 開始使用

### 前置要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- 後端 API 伺服器運行中

### 安裝步驟

1. 安裝依賴套件
```bash
flutter pub get
```

2. 設定 API 端點

編輯 `lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'http://your-api-server:8080/api/v1';
```

3. 執行應用程式
```bash
# 開發模式
flutter run

# 釋出模式
flutter run --release
```

## 開發指南

### 新增 API 端點

1. 在相應的 repository 中新增方法
2. 使用 ApiClient 發送請求
3. 處理錯誤並轉換資料模型

範例：
```dart
Future<MenuItem> getItemById(String id) async {
  try {
    final response = await _apiClient.get('/menu/items/$id');
    final data = response.data['data'] as Map<String, dynamic>;
    return MenuItem.fromJson(data);
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

### 建立新的 BLoC

1. 定義 Events (`*_event.dart`)
2. 定義 States (`*_state.dart`)
3. 實作 BLoC 邏輯 (`*_bloc.dart`)
4. 在 UI 中使用 BlocProvider 和 BlocBuilder

### 建立新頁面

1. 在 `presentation` 中建立對應的資料夾
2. 建立頁面 widget
3. 使用 BlocProvider 注入需要的 BLoC
4. 使用 BlocBuilder/BlocConsumer 監聽狀態變化

## API 端點

### 認證
- `POST /auth/login` - Email/密碼登入
- `POST /auth/login/pin` - PIN 登入
- `GET /auth/me` - 取得當前使用者資訊
- `POST /auth/logout` - 登出

### 選單
- `GET /menu/categories` - 取得所有分類
- `GET /menu/categories/:id` - 取得分類詳情
- `GET /menu/items` - 取得所有菜品
- `GET /menu/items/:id` - 取得菜品詳情

### 訂單
- `POST /orders` - 建立訂單
- `GET /orders` - 取得訂單列表
- `GET /orders/:id` - 取得訂單詳情
- `POST /orders/:id/items` - 新增訂單項目
- `PUT /orders/:id/items/:itemId` - 更新訂單項目
- `DELETE /orders/:id/items/:itemId` - 刪除訂單項目
- `POST /orders/:id/payments` - 新增付款
- `POST /orders/:id/complete` - 完成訂單

### 桌位
- `GET /tables` - 取得桌位列表
- `GET /tables/:id` - 取得桌位詳情
- `GET /tables/available` - 取得可用桌位
- `PUT /tables/:id/status` - 更新桌位狀態

## 測試帳號

使用後端種子資料中的測試帳號：

**Manager 帳號:**
- Email: `manager@test.com`
- Password: `password123`
- PIN: `1234`

**Cashier 帳號:**
- Email: `cashier1@test.com`
- Password: `password123`
- PIN: `5678`

## 建置釋出版本

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### macOS
```bash
flutter build macos --release
```

### Windows
```bash
flutter build windows --release
```

## 效能優化建議

1. **圖片優化**: 使用 `cached_network_image` 快取圖片
2. **列表優化**: 使用 `ListView.builder` 進行懶加載
3. **狀態管理**: 只在需要的地方使用 BlocBuilder
4. **API 呼叫**: 實作請求去抖動（debounce）和節流（throttle）
5. **離線支援**: 考慮實作本地快取策略

## 常見問題

**Q: 登入後顯示 401 錯誤？**
A: 檢查 API 伺服器是否正常運行，以及 baseUrl 設定是否正確。

**Q: 圖片無法顯示？**
A: 確認圖片 URL 是否正確，網路權限是否設定。

**Q: 佈局在不同裝置上顯示異常？**
A: 使用 flutter_screenutil 的響應式單位 (w, h, sp, r)。

## 授權

本專案為 POC (Proof of Concept) 專案，僅供學習和測試使用。

## 聯絡方式

如有問題或建議，請聯絡開發團隊。
