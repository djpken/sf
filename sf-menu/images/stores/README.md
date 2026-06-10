# 門市實拍照

chatbot 的「門市資訊卡」(store card) 會在卡片頂端顯示這家店的照片,讓客人看到店的樣子。

## 怎麼放照片

1. 把每家店的實拍照命名為 **「店名.webp」**,放進這個資料夾。
   檔名要和 `second-floor-chatbot/server/app/data/stores.json` 裡該店的 `image` 路徑一致。
   例:`敦南店` 的 `image` 是 `/images/stores/敦南店.webp` → 檔案就叫 `敦南店.webp`。

2. 目前需要的檔名(對照 stores.json):
   - 敦南店.webp / 公館店.webp / 微風台北車站店.webp / 仁愛店.webp / 南港車站店.webp
   - 師大店.webp / 中山南西店.webp / 微風南山店.webp / 板橋店.webp / 林口店.webp
   - 桃園台茂店.webp / 新竹巨城店.webp / 台中公益店.webp / 高雄店.webp / 高雄夢時代店.webp

## 規格建議

- 格式:`.webp`(與餐點圖一致,檔案小)。
- 比例:橫式約 **16:9 ~ 3:2**,卡片會以 `object-fit: cover` 裁切置中,寬度約 340px、高度 150px。
- 內容:店面外觀或店內氛圍皆可,主體置中較不會被裁掉。

## 還沒放照片時

卡片會自動顯示一個帶店名首字的占位 banner(不會破版),放上實拍照後即自動換成照片。
換新增/改店名時,記得同步更新 stores.json 的 `image` 與這裡的檔名。
