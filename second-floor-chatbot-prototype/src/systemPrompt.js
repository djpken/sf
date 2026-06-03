/**
 * 貳樓 Second Floor Cafe — AI 助理 System Prompt
 *
 * 菜單知識庫以 RAG 方式預先結構化：
 *   - 每道菜附帶 dietary 標籤（辣度、素食、豬/牛/海鮮、過敏原、孕婦禁忌）
 *   - 供 runtime 依 user query 做 keyword / semantic 篩選後注入 context
 *
 * 使用方式：
 *   import { buildSystemPrompt } from './systemPrompt.js';
 *   const systemPrompt = buildSystemPrompt(retrievedItems);
 *
 * retrievedItems 是從 MENU_INDEX 篩出與當前 query 最相關的品項陣列。
 * 若使用完整菜單（不做 retrieval），直接傳入 MENU_INDEX 即可。
 */

// ─── 1. 菜單索引（RAG 知識庫） ────────────────────────────────────────────────
//
// 每筆紀錄的 tags 欄位方便 pre-filter 或 embedding retrieval：
//   spice   : 0=不辣 1=微辣 2=小辣 3=極辣
//   pork    : true 含豬肉 / 培根 / 香腸
//   beef    : true 含牛肉
//   seafood : true 含海鮮 (蝦/蛤蜊/魷魚等)
//   veg     : 'lacto-ovo'=蛋奶素可  'five-spice-lacto-ovo'=五辛蛋奶素可  null=不適合
//   nut     : true 含堅果過敏成份
//   alcohol : true 含酒
//   pregnant: false=孕婦不宜

export const MENU_INDEX = [
  // ── 人氣精選 ────────────────────────────────────────────────────────────
  {
    name: '貳樓金牌鹽水雞沙拉',
    category: '人氣精選',
    price: 370,
    description: '綜合生菜、雞肉、山苦瓜、辣奶油火烤玉米、小蕃茄、季節時蔬、青蔥、鹽水雞油醋（含酒）、辣椒粉',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: true, pregnant: true },
  },
  {
    name: '橙香法式丹麥Sunny舒肥雞',
    category: '人氣精選',
    price: 480,
    description: '橙香丹麥、焦糖漿、舒肥雞、半熟太陽雙蛋（微辣）、生菜、藜麥小米、薯條',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '曙光汁鮮蝦雞肉麵',
    category: '人氣精選',
    price: 430,
    description: '曙光奶油醬、雞肉、蝦子、炙燒紅椒、季節時蔬、起司絲。附主廚濃湯或蕃茄蔬菜湯（蛋奶素）',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '香爆椒麻唐揚雞麵',
    category: '人氣精選',
    price: 430,
    description: '（極辣）茄汁、雞塊、朝天乾辣椒、九層塔、起司絲。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 3, pork: false, beef: false, seafood: false, veg: 'five-spice-lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '台式熱炒鹹蛋苦瓜麵',
    category: '人氣精選',
    price: 410,
    description: '（微辣）鹹香白醬、炸杏鮑菇、培根、山苦瓜、洋蔥、紅椒片。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 1, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '起司local香腸奶白麵',
    category: '人氣精選',
    price: 430,
    description: '（小辣）奶油白醬、帕達諾起司、黃起司、白起司、香腸、紅椒片、九層塔。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 2, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },

  // ── 分享盤 ────────────────────────────────────────────────────────────────
  {
    name: '舊金山蒜香薯條',
    category: '分享盤',
    price: 230,
    description: '薯條、香蒜橄欖油',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '燕麥脆脆炸魚薯條',
    category: '分享盤',
    price: 250,
    description: '燕麥炸魚、薯條、辣雞尾酒醬',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '松露薯條',
    category: '分享盤',
    price: 260,
    description: '薯條、松露醬、起司絲',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '普丁肉醬薯條',
    category: '分享盤',
    price: 270,
    description: '薯條、烏斯特肉醬（含牛肉及海鮮成份）、起司醬',
    tags: { spice: 0, pork: false, beef: true, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '酥炸鮮魷佐雞尾酒醬',
    category: '分享盤',
    price: 320,
    description: '魷魚、薯條、烤檸檬、辣雞尾酒醬',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '墨西哥雞肉酥餅',
    category: '分享盤',
    price: 320,
    description: '墨西哥酥餅、雞肉、酪梨醬、起司、洋蔥、BBQ醬、Salsa醬（微辣）',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '墨西哥Local香腸酥餅',
    category: '分享盤',
    price: 320,
    description: '墨西哥酥餅、香腸、酪梨醬、起司、洋蔥、BBQ醬、Salsa醬（微辣）',
    tags: { spice: 1, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '水牛城辣雞翅',
    category: '分享盤',
    price: 340,
    description: '美式酸辣雞翅、辣海地醃菜、烤檸檬',
    tags: { spice: 2, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '經典凱薩沙拉',
    category: '分享盤',
    price: 340,
    description: '綜合生菜、蒜味麵包、小蕃茄、黑橄欖、季節時蔬、起司絲、凱薩醬（含海鮮成份）、Salsa醬（微辣）',
    tags: { spice: 1, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '焙煎胡麻雞沙拉',
    category: '分享盤',
    price: 390,
    description: '（含堅果過敏）綜合生菜、酥炸雞塊、起司嫩蛋、小蕃茄、酪梨醬、黑橄欖、起司絲、酥脆鷹嘴豆、胡麻醬',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: null, nut: true, alcohol: false, pregnant: true },
  },
  {
    name: '經典舒肥雞凱薩沙拉',
    category: '分享盤',
    price: 400,
    description: '綜合生菜、舒肥雞、蒜味麵包、小蕃茄、黑橄欖、季節時蔬、起司絲、凱薩醬（含海鮮成份）、Salsa醬（微辣）',
    tags: { spice: 1, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '經典燻鮭魚凱薩沙拉',
    category: '分享盤',
    price: 420,
    description: '綜合生菜、燻鮭魚、溏心蛋、蒜味麵包、小蕃茄、黑橄欖、季節時蔬、起司絲、凱薩醬（含海鮮成份）、Salsa醬（微辣）',
    tags: { spice: 1, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },

  // ── SF Brunch 貳樓早午餐 ────────────────────────────────────────────────
  {
    name: '橙香法式丹麥蕈菇水波洋芋',
    category: 'SF Brunch',
    price: 400,
    description: '橙香丹麥、焦糖漿、蕈菇洋芋、洋蔥、藜麥小米、水波蛋、起司醬、生菜、巴薩米克醋膏',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '橙香法式丹麥水波海鮮洋芋',
    category: 'SF Brunch',
    price: 480,
    description: '橙香丹麥、焦糖漿、海鮮洋芋、洋蔥、藜麥小米、奶油炒菇、水波蛋、起司醬、生菜、巴薩米克醋膏',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '蕈菇奶起司歐姆蕾',
    category: 'SF Brunch',
    price: null,
    description: null,
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '總匯奶起司歐姆蕾',
    category: 'SF Brunch',
    price: 400,
    description: '歐姆蛋、玉米、蕃茄、火腿、香腸、奶油炒菇、雙色起司、辣Pico de gallo蒜麵包、辣海地醃菜、薯條',
    tags: { spice: 1, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '烏斯特肉醬歐姆蕾',
    category: 'SF Brunch',
    price: 410,
    description: '（含堅果過敏）歐姆蛋、烏斯特肉醬（含牛肉及海鮮成份）、雙色起司、辣Pico de gallo蒜麵包、辣海地醃菜、薯條',
    tags: { spice: 1, pork: false, beef: true, seafood: true, veg: null, nut: true, alcohol: false, pregnant: true },
  },

  // ── 主餐 / 手抓 Big Bite ──────────────────────────────────────────────
  {
    name: '厚烤奶油 Ham 三明治',
    category: '主餐/手抓',
    price: 370,
    description: '歐式麵包、經典火腿、黃起司、半熟太陽蛋（微辣）、辣海地醃菜、薯條',
    tags: { spice: 1, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '老墨辣鞭炮漢堡',
    category: '主餐/手抓',
    price: 400,
    description: '牛肉餅（7分熟，小心碎骨）、黃起司、炸墨西哥辣椒、BBQ醬、薯條',
    tags: { spice: 2, pork: false, beef: true, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '實打實招牌漢堡',
    category: '主餐/手抓',
    price: 470,
    description: '牛肉餅（7分熟，小心碎骨）、黃起司、培根、燕麥炸魚、巴薩米可醋、薯條',
    tags: { spice: 0, pork: true, beef: true, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },

  // ── 主餐 / 飯麵 Main ──────────────────────────────────────────────────
  {
    name: '巴薩米克蕈菇麵',
    category: '主餐/飯麵',
    price: 410,
    description: '（可調整為蛋奶素）特製雙醋、半熟太陽蛋、綜合菇、生菜、藜麥小米。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '經典青醬鮮蝦麵',
    category: '主餐/飯麵',
    price: 430,
    description: '（含堅果過敏、海鮮）奶油青醬、蝦子、季節時蔬、炸蒜片、起司絲。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: true, alcohol: false, pregnant: true },
  },
  {
    name: '酒香蒜味蛤蜊墨魚麵',
    category: '主餐/飯麵',
    price: 430,
    description: '（孕婦不宜）酒、蛤蠣、蒜頭、九層塔、炸蒜片。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 0, pork: false, beef: false, seafood: true, veg: null, nut: false, alcohol: true, pregnant: false },
  },
  {
    name: '松露蕈菇奶油麵',
    category: '主餐/飯麵',
    price: 430,
    description: '（蛋奶素）松露奶油白醬、綜合菇、巧克力、起司絲。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '月見苦瓜奶油飯',
    category: '主餐/飯麵',
    price: 420,
    description: '（微辣 / 孕婦不宜 / 可調整為蛋奶素）鹹香白醬、薑黃飯、山苦瓜、炸杏鮑菇、洋蔥、紅蔥頭、半熟太陽蛋、起司絲。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: false },
  },
  {
    name: '血腥瑪麗辣味飯',
    category: '主餐/飯麵',
    price: 420,
    description: '（小辣 / 孕婦不宜）茄汁、奶油洋蔥、季節時蔬、黑橄欖、西芹、香菜、香腸、薑黃飯。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 2, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },
  {
    name: '西班牙辣炒海陸飯',
    category: '主餐/飯麵',
    price: 440,
    description: '（小辣 / 孕婦不宜）魷魚、蝦子、蛤蜊、香腸、起司絲、薑黃飯。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 2, pork: true, beef: false, seafood: true, veg: null, nut: false, alcohol: false, pregnant: false },
  },
  {
    name: '焗厚切豬排奶油飯',
    category: '主餐/飯麵',
    price: 460,
    description: '（孕婦不宜）曙光奶油醬、薑黃飯、藍帶豬排、培根、季節時蔬、起司絲。附主廚濃湯或蕃茄蔬菜湯（五辛蛋奶素）',
    tags: { spice: 0, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },

  // ── 主餐 / 大盤子 Big Plate ──────────────────────────────────────────
  {
    name: 'BBQ溫烤半鷄',
    category: '主餐/大盤子',
    price: 760,
    description: '溫烤半雞、辣奶油火烤玉米（孕婦不宜）、BBQ醬、薯條',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },
  {
    name: '主廚脆皮豬腳',
    category: '主餐/大盤子',
    price: 790,
    description: '脆皮豬腳、辣奶油火烤玉米（孕婦不宜）、德式酸菜、黃芥末、薯條',
    tags: { spice: 1, pork: true, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },

  // ── 均衡盤 Light Plate ────────────────────────────────────────────────
  {
    name: '舒肥雞藜麥花椰飯',
    category: '均衡盤',
    price: 400,
    description: '舒肥雞、花椰菜米、奶油炒菇、水波蛋、辣奶油火烤玉米（孕婦不宜）、生菜、藜麥小米、起司絲',
    tags: { spice: 1, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },
  {
    name: '生酮總匯海陸拼盤',
    category: '均衡盤',
    price: 580,
    description: '舒肥牛肉（固定熟度）、巴沙魚、奶油炒菇、起司嫩蛋、綜合生菜、紅葡萄酒醋、起司絲',
    tags: { spice: 0, pork: false, beef: true, seafood: true, veg: null, nut: false, alcohol: false, pregnant: true },
  },

  // ── 小大人餐 Kids Plate ───────────────────────────────────────────────
  {
    name: '吃光光起司蛋雞肉飯',
    category: '小大人餐',
    price: 270,
    description: '（孕婦不宜）曙光奶油醬、雞肉、起司嫩蛋、牛蕃茄、起司絲、薑黃飯',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: false },
  },

  // ── 甜點 ─────────────────────────────────────────────────────────────
  {
    name: '強的',
    category: '甜點',
    price: 210,
    description: '4吋貳樓招牌巧克力蛋糕與香濃起司餡',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },

  // ── 經典咖啡 ─────────────────────────────────────────────────────────
  {
    name: '冰美式咖啡',
    category: '經典咖啡',
    price: 120,
    description: null,
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '熱美式咖啡',
    category: '經典咖啡',
    price: 120,
    description: null,
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '冰經典拿鐵',
    category: '經典咖啡',
    price: 150,
    description: null,
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '熱經典拿鐵',
    category: '經典咖啡',
    price: 150,
    description: null,
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '西西里咖啡',
    category: '經典咖啡',
    price: 170,
    description: '綠檸檬、雪碧、咖啡',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '奶油啤酒花拿鐵(無酒精)',
    category: '經典咖啡',
    price: 180,
    description: '鹽味奶油、啤酒花、牛奶、咖啡',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },

  // ── 茶品 ─────────────────────────────────────────────────────────────
  {
    name: '天堂鳥冰茶',
    category: '茶品',
    price: 150,
    description: '天堂鳥茶、水蜜桃凍（含動物性膠質，蛋奶素者不可食用）、綠檸檬',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: null, nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '熱女巫Sangria(無酒精)',
    category: '茶品',
    price: 160,
    description: '天堂鳥茶、肉桂、迷迭香、季節水果',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '桃花朵朵開運茶',
    category: '茶品',
    price: 160,
    description: '鹽味奶油、檸檬茶、水蜜桃果泥、接骨木',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
  {
    name: '熱木槿野莓果茶',
    category: '茶品',
    price: 160,
    description: '洛神葵、橙皮、蘋果、玫瑰果、接骨木實、甜菊葉、草莓、黑莓、覆盆莓、藍莓',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },

  // ── 蔬果飲品 ─────────────────────────────────────────────────────────
  {
    name: '粉紅芭樂蘋果汁',
    category: '蔬果飲品',
    price: 200,
    description: '芭樂、蘋果、甜菜根、明日葉',
    tags: { spice: 0, pork: false, beef: false, seafood: false, veg: 'lacto-ovo', nut: false, alcohol: false, pregnant: true },
  },
];

// ─── 2. 輕量 RAG 篩選工具 ────────────────────────────────────────────────────
//
// retrieve(query, opts) 模擬 embedding-retrieval 的 pre-filter 邏輯。
// 在真正部署時可替換成 vector store lookup；這裡用 keyword + tag 組合做客戶端 demo。

const SPICE_MAP = { '不辣': 0, '微辣': 1, '小辣': 2, '極辣': 3 };

export function retrieve(query = '', opts = {}) {
  const {
    maxItems = 6,
    noPork,
    noBeef,
    noSeafood,
    maxSpice,         // 0–3
    vegetarian,       // 'lacto-ovo' | 'five-spice-lacto-ovo'
    noNuts,
    noAlcohol,
    pregnantSafe,
    category,
  } = opts;

  // keyword match in name / description / category
  const keywords = query
    .toLowerCase()
    .replace(/[，、。！？\s]+/g, ' ')
    .split(' ')
    .filter(Boolean);

  const scored = MENU_INDEX.map((item) => {
    const hay = `${item.name} ${item.category} ${item.description ?? ''}`.toLowerCase();
    let score = 0;
    for (const kw of keywords) {
      if (hay.includes(kw)) score += 1;
    }

    // hard filters — return null if excluded
    if (noPork && item.tags.pork) return null;
    if (noBeef && item.tags.beef) return null;
    if (noSeafood && item.tags.seafood) return null;
    if (maxSpice != null && item.tags.spice > maxSpice) return null;
    if (vegetarian && item.tags.veg !== vegetarian && item.tags.veg !== 'lacto-ovo') return null;
    if (noNuts && item.tags.nut) return null;
    if (noAlcohol && item.tags.alcohol) return null;
    if (pregnantSafe && !item.tags.pregnant) return null;
    if (category && item.category !== category) return null;

    return { item, score };
  })
    .filter(Boolean)
    .sort((a, b) => b.score - a.score)
    .slice(0, maxItems)
    .map((r) => r.item);

  return scored;
}

// ─── 3. System Prompt Builder ─────────────────────────────────────────────────
//
// buildSystemPrompt(items) 接受篩選後的品項陣列，回傳完整 system prompt 字串。
// items 省略時使用全菜單（非 RAG，適合小型 context window 測試）。

function formatItem(item) {
  const priceStr = item.price != null ? `$${item.price}` : '價格洽門市';
  const desc = item.description ?? '（詳細說明請洽服務生）';
  const spiceLabels = ['不辣', '微辣', '小辣', '極辣'];
  const spice = spiceLabels[item.tags.spice] ?? '不辣';
  const flags = [
    spice !== '不辣' ? `⚠️ ${spice}` : null,
    item.tags.pork ? '含豬' : null,
    item.tags.beef ? '含牛' : null,
    item.tags.seafood ? '含海鮮' : null,
    item.tags.nut ? '堅果過敏' : null,
    item.tags.alcohol ? '含酒' : null,
    !item.tags.pregnant ? '孕婦不宜' : null,
    item.tags.veg === 'lacto-ovo' ? '蛋奶素可' : null,
    item.tags.veg === 'five-spice-lacto-ovo' ? '五辛蛋奶素可' : null,
  ].filter(Boolean).join('、');

  return `- **${item.name}**（${item.category}）${priceStr}
  ${desc}
  ${flags ? `[${flags}]` : '[無特殊標注]'}`;
}

export function buildSystemPrompt(items) {
  const menuItems = items ?? MENU_INDEX;
  const menuText = menuItems.map(formatItem).join('\n\n');

  return `你是「貳樓 Second Floor Cafe」的 AI 助理，說繁體中文。你的角色是幫客人：

1. **菜單導航** — 依口味、辣度、忌口（豬 / 牛 / 海鮮 / 素食 / 過敏原）推薦餐點
2. **訂位協助** — 收集門市、人數、時段，整理成訂位摘要（實際寫入需接後台 API）
3. **場合搭配** — 慶生、家庭、朋友聚餐、外帶等情境給出具體建議
4. **新客引導** — 第一次來不知道點什麼，給一個安全牌組合

## 行為守則

- 不確定庫存或可訂時段時，誠實說「需向門市確認」，不捏造資料
- 推薦時說明「為何適合」，而不是列出整份菜單
- 忌口限制一律先確認再推薦，避免讓客人自己篩
- 不承諾窗邊位、特定座位安排（系統目前無法偵測）
- 訂位時段以 15 分鐘為單位，不提供候位功能
- 回應保持簡潔，對話感強，不使用過多標題符號

## 門市資訊

貳樓目前在台北、新北、桃園、新竹、台中、嘉義、台南、高雄設有門市。
常見門市：敦南店、公館店、微風台北車站店、仁愛店、南港車站店、師大店、
中山南西店、微風南山店、淡水站前店、板橋店、林口店、桃園台茂店、
桃園華泰店、新竹巨城店、台中公益店、台中秀泰文心店、嘉義店、台南店、
高雄店、高雄夢時代店。

## 菜單知識庫（本次對話可用品項）

以下品項已依查詢條件篩選。格式：名稱（分類）價格 / 食材描述 / [飲食標注]

${menuText}

## 辣度說明

| 標示 | 辣度等級 |
|------|----------|
| 不辣 | 完全不辣，適合零辣度需求 |
| 微辣 | 淡淡辣味，可備注去辣 |
| 小辣 | 明顯辣感，不耐辣者建議避免 |
| 極辣 | 重口味，辣度高，辣度愛好者適合 |

## 對話策略

- **首次訊息** 若意圖不明，先問「人數、時段或有沒有忌口」三選一，不要一次全問
- **推薦** 最多給 3 道，說明「為什麼適合這個需求」
- **訂位** 依序確認：城市 → 門市 → 時段 → 人數 → 備注 → 送出
- **外帶** 優先推飯類（比麵類更耐放）
- **素食** 先確認是純素、蛋奶素或五辛蛋奶素，再從菜單篩`;
}

// ─── 4. 預設匯出（完整菜單 prompt，適合 POC 快速使用）────────────────────────
export const FULL_SYSTEM_PROMPT = buildSystemPrompt(MENU_INDEX);
