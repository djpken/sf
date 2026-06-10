"""貳樓 Second Floor Cafe — 菜單 RAG。

菜單資料 (menu.json) 由 prototype 的 systemPrompt.js MENU_INDEX dump 而來,是單一
資料源。retrieve() / build_system_prompt() 由同一份 JS 邏輯忠實 port,行為對齊。

tags 欄位:
  spice   : 0=不辣 1=微辣 2=小辣 3=極辣
  pork    : 含豬肉/培根/香腸
  beef    : 含牛肉
  seafood : 含海鮮
  veg     : 'lacto-ovo'=蛋奶素可  'five-spice-lacto-ovo'=五辛蛋奶素可  None=不適合
  nut     : 含堅果過敏成份
  alcohol : 含酒
  pregnant: False=孕婦不宜
"""

from __future__ import annotations

import json
import re
from pathlib import Path

_DATA_FILE = Path(__file__).parent / "data" / "menu.json"
MENU_INDEX: list[dict] = json.loads(_DATA_FILE.read_text(encoding="utf-8"))

SPICE_LABELS = ["不辣", "微辣", "小辣", "極辣"]

# 純數字/時間 token（人數、時段、價格等）不是菜單搜尋詞,排除以免「4 個朋友」誤中
# 「4吋蛋糕」、或「18:00」誤中描述裡的數字。
_NUMERIC_TOKEN = re.compile(r"^[\d:：.\-]+$")


def _is_search_token(tok: str) -> bool:
    return bool(tok) and _NUMERIC_TOKEN.match(tok) is None


def _longest_common_substring_len(a: str, b: str) -> int:
    """回傳 a、b 的最長連續共同子字串長度(用於判斷使用者是否點名某道菜)。"""
    if not a or not b:
        return 0
    prev = [0] * (len(b) + 1)
    best = 0
    for i in range(1, len(a) + 1):
        curr = [0] * (len(b) + 1)
        for j in range(1, len(b) + 1):
            if a[i - 1] == b[j - 1]:
                curr[j] = prev[j - 1] + 1
                if curr[j] > best:
                    best = curr[j]
        prev = curr
    return best


# 使用者「點名」某道菜的判定門檻:菜名與查詢的最長連續重疊 ≥ 此字數即視為點名。
# 設 3 是為了讓「鹽水雞」「奶油麵」這類核心名也算點名(寧可放行帶標註,也別謊稱沒有)。
_NAMED_DISH_MIN_OVERLAP = 3


def _is_named_dish(name: str, query: str) -> bool:
    if not query:
        return False
    name_l = name.lower()
    query_l = query.lower()
    if name_l in query_l:
        return True
    return _longest_common_substring_len(name_l, query_l) >= _NAMED_DISH_MIN_OVERLAP


def retrieve(
    query: str = "",
    *,
    max_items: int = 6,
    min_score: int = 0,
    no_pork: bool = False,
    no_beef: bool = False,
    no_seafood: bool = False,
    max_spice: int | None = None,  # 0-3
    vegetarian: str | None = None,  # 'lacto-ovo' | 'five-spice-lacto-ovo'
    no_nuts: bool = False,
    no_alcohol: bool = False,
    pregnant_safe: bool = False,
    category: str | None = None,
) -> list[dict]:
    """關鍵字評分 + tag 硬篩選。對齊 systemPrompt.js 的 retrieve()。

    硬篩選(忌口/辣度)直接把不合格品項排除,模型看到的就是合格清單。
    """
    keywords = [k for k in re.split(r"[，、。！？\s]+", query.lower()) if _is_search_token(k)]

    scored: list[tuple[int, dict]] = []
    for item in MENU_INDEX:
        tags = item["tags"]
        # 分類屬檢索範圍(非忌口),點名也不豁免
        if category and item["category"] != category:
            continue

        # 忌口/辣度硬篩選:收集違反項。一般情況直接排除;但若使用者「點名」這道菜,
        # 改為帶衝突標註進清單,讓模型誠實說「這道菜單有、但不符您的設定」,
        # 而非謊稱「沒有這道品項」(最傷信任)。
        conflicts = []
        if no_pork and tags["pork"]:
            conflicts.append("含豬肉")
        if no_beef and tags["beef"]:
            conflicts.append("含牛肉")
        if no_seafood and tags["seafood"]:
            conflicts.append("含海鮮")
        if max_spice is not None and tags["spice"] > max_spice:
            conflicts.append("有辣度")
        if vegetarian and tags["veg"] != vegetarian and tags["veg"] != "lacto-ovo":
            conflicts.append("非素食")
        if no_nuts and tags["nut"]:
            conflicts.append("含堅果")
        if no_alcohol and tags["alcohol"]:
            conflicts.append("含酒")
        if pregnant_safe and not tags["pregnant"]:
            conflicts.append("孕婦不宜")

        named = _is_named_dish(item["name"], query)
        if conflicts:
            if not named:
                continue
            item = {**item, "_diet_conflict": "、".join(conflicts)}

        hay = f"{item['name']} {item['category']} {item.get('description', '')}".lower()
        q_lower = query.lower()
        # 正向：token 出現在 hay 中；或反向：hay 中的詞出現在整段 query 中（處理「薯條好吃嗎」無法切分的情況）
        hay_tokens = [t for t in re.split(r"[，、。！？\s]+", hay) if t]
        score = sum(1 for kw in keywords if kw in hay) + sum(
            1 for ht in hay_tokens if len(ht) >= 2 and _is_search_token(ht) and ht in q_lower
        )
        if named:
            score += 100  # 點名的菜保證排進清單(即使整段菜名無法被切分而關鍵字命中為 0)
        scored.append((score, item))

    # 穩定排序:分數高優先,同分維持菜單原順序
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [item for score, item in scored[:max_items] if score >= min_score]


# 輕量中文忌口/辣度偵測 → 餵給 retrieve() 做硬篩選。
# v1 用關鍵字(中英 union);之後可換成模型 intent 分類或 tool use。
# lowercase 對中文無影響,可讓英文比對不區分大小寫。
def infer_opts(text: str) -> dict:
    t = (text or "").lower()
    opts: dict = {}
    if any(k in t for k in (
        "不吃豬", "不要豬", "沒有豬", "無豬", "去豬",
        "no pork", "pork-free", "pork free", "without pork", "avoid pork",
    )):
        opts["no_pork"] = True
    if any(k in t for k in (
        "不吃牛", "不要牛", "無牛",
        "no beef", "beef-free", "without beef", "avoid beef",
    )):
        opts["no_beef"] = True
    if any(k in t for k in (
        "不吃海鮮", "不要海鮮", "海鮮過敏",
        "no seafood", "seafood allergy", "shellfish allergy", "no fish", "no shrimp",
    )):
        opts["no_seafood"] = True
    if any(k in t for k in (
        "純素", "全素", "蛋奶素", "吃素", "素食",
        "vegetarian", "vegan", "veggie",
    )):
        opts["vegetarian"] = "lacto-ovo"
    # 「可以不要辣嗎 / 能不能去辣」是詢問某道菜能否客製去辣,不是宣告本人吃全程零辣。
    # 若帶這類能力詢問詞,就不設 max_spice 硬篩,否則微辣的指名菜會在進 prompt 前被剔除,
    # 模型看不到而誤答「沒有這道品項」。真正想要不辣餐點的「有不辣的嗎」不含這些詞,仍正常硬篩。
    asking_can_adjust = any(k in t for k in (
        "可以", "能不能", "可不可以", "能否", "可否", "可調", "調整", "調成",
        "can i", "can you", "could you", "is it possible",
    ))
    if not asking_can_adjust and any(k in t for k in (
        "不要辣", "完全去辣", "去辣", "不吃辣", "不辣",
        "not spicy", "no spice", "no spicy", "no chili", "mild",
    )):
        opts["max_spice"] = 0
    if any(k in t for k in (
        "不喝酒", "不要酒", "無酒精", "孕婦", "懷孕",
        "no alcohol", "non-alcoholic", "alcohol-free", "pregnant", "pregnancy",
    )):
        opts["no_alcohol"] = True
    if any(k in t for k in ("孕婦", "懷孕", "pregnant", "pregnancy")):
        opts["pregnant_safe"] = True
    if ("堅果" in t and any(k in t for k in ("過敏", "不要", "不吃"))) or \
       any(k in t for k in ("nut allergy", "no nuts", "peanut allergy", "tree nut")):
        opts["no_nuts"] = True
    return opts


def _format_item(item: dict, item_notes: dict | None = None) -> str:
    price = f"${item['price']}" if item.get("price") is not None else "價格洽門市"
    desc = item.get("description") or "（詳細說明請洽服務生）"
    tags = item["tags"]
    spice = SPICE_LABELS[tags["spice"]] if tags["spice"] < len(SPICE_LABELS) else "不辣"
    can_adjust = bool(item_notes and item_notes.get("spice_adjustable"))
    spice_flag = None
    if spice != "不辣":
        spice_flag = f"⚠️ {spice}（可調）" if can_adjust else f"⚠️ {spice}"
    flags = [
        spice_flag,
        "含豬" if tags["pork"] else None,
        "含牛" if tags["beef"] else None,
        "含海鮮" if tags["seafood"] else None,
        "堅果過敏" if tags["nut"] else None,
        "含酒" if tags["alcohol"] else None,
        "孕婦不宜" if not tags["pregnant"] else None,
        "蛋奶素可" if tags["veg"] == "lacto-ovo" else None,
        "五辛蛋奶素可" if tags["veg"] == "five-spice-lacto-ovo" else None,
    ]
    flag_str = "、".join(f for f in flags if f)
    extra_parts = []
    conflict = item.get("_diet_conflict")
    if conflict:
        # 客人點名了這道菜,但它不符合客人設定(忌口/辣度)。菜單確實有提供,
        # 務必據實說明「這道有、但…」,不可說「沒有這道品項」;同時別主動推薦它。
        extra_parts.append(
            f"⚠️ 此品項菜單有提供,但{conflict},不符合客人目前的飲食設定;"
            f"請據實說明(勿說查無此品項),並改推薦合適的選擇,勿主動推薦本品項"
        )
    if can_adjust and spice == "不辣":
        extra_parts.append("可依需求調整辣度")
    if item_notes and item_notes.get("notes"):
        extra_parts.append(item_notes["notes"])
    extra = f"\n  📝 {'、'.join(extra_parts)}" if extra_parts else ""
    return (
        f"- **{item['name']}**（{item['category']}）{price}\n"
        f"  {desc}\n"
        f"  {f'[{flag_str}]' if flag_str else '[無特殊標注]'}{extra}"
    )


_LANG_DIRECTIVE: dict[str, str] = {
    "zh-TW": "說繁體中文。",
    "en": (
        "Respond in English. Keep dish names in their original Chinese "
        "(a short English gloss in parentheses is welcome). "
        "Translate descriptions and all your replies into English."
    ),
}


def _build_store_notes_section(store_notes: dict) -> str:
    if not store_notes:
        return ""
    parts = []
    for store_name, sn in store_notes.items():
        info = []
        if sn.get("seating_capacity"):
            info.append(f"座位數約 {sn['seating_capacity']} 席")
        if sn.get("table_spacing"):
            info.append(f"桌距{sn['table_spacing']}")
        if sn.get("has_private_room"):
            info.append("有包廂")
        if sn.get("has_outdoor"):
            info.append("有戶外區")
        if sn.get("noise_level"):
            info.append(f"環境{sn['noise_level']}")
        if sn.get("notes"):
            info.append(sn["notes"])
        if info:
            parts.append(f"- **{store_name}**：{'、'.join(info)}")
    if not parts:
        return ""
    return "\n\n## 分店特色資訊\n\n" + "\n".join(parts)


def _build_qa_section(qa_pairs: list | None) -> str:
    """把 admin 設計的「指定問答」組成 system prompt 區段(類似 skills 的 trigger→answer)。"""
    pairs = [
        p
        for p in (qa_pairs or [])
        if p.get("enabled", True) and (p.get("question") or "").strip() and (p.get("answer") or "").strip()
    ]
    if not pairs:
        return ""
    lines = []
    for p in pairs:
        q = p["question"].strip()
        a = p["answer"].strip().replace("\n", "\n  ")
        lines.append(f"- 當客人問到/提到「{q}」這類情境時,務必依下列內容回答:\n  {a}")
    return (
        "\n\n## 指定問答（最高優先,務必遵循）\n\n"
        "以下是店家設定的標準問答。當客人的問題符合某條情境時,你的回答必須以對應內容為準"
        "（可用自然、對話的口吻轉述,但事實與重點不可更動,也不可自行補上未提供的資訊）:\n\n"
        + "\n".join(lines)
    )


# 行為守則預設值。admin 未在後台覆寫時用這份;後台可在「行為守則」分頁編輯。
DEFAULT_BEHAVIOR_RULES = """- **只服務貳樓相關話題**:菜單、餐點、訂位、門市、用餐情境等。遇到與貳樓無關的問題（例如天氣、新聞、寫程式、數學、其他餐廳、通用閒聊、政治時事等），一律婉拒並把對話帶回貳樓,例如:「我是貳樓的點餐 / 訂位小幫手,這部分我幫不上忙,不過想吃點什麼或要訂位都可以問我喔～」。不要回答、不要嘗試解題,即使客人堅持也只引導回貳樓主題
- 不確定庫存或可訂時段時,誠實說「需向門市確認」,不捏造資料
- 推薦時說明「為何適合」,而不是列出整份菜單
- 忌口限制一律先確認再推薦,避免讓客人自己篩
- 不承諾窗邊位、特定座位安排（系統目前無法偵測）
- 訂位時段以 15 分鐘為單位,不提供候位功能
- 回應保持簡潔,對話感強,不使用過多標題符號"""


def build_system_prompt(
    items: list[dict] | None = None,
    locale: str = "zh-TW",
    *,
    menu_notes: dict | None = None,
    store_notes: dict | None = None,
    behavior_rules: str | None = None,
    qa_pairs: list | None = None,
) -> str:
    """接受篩選後品項,回傳完整 system prompt。對齊 systemPrompt.js。

    behavior_rules / qa_pairs 可由後台 admin 動態覆寫;為空時用預設值。
    """
    menu_items = items if items is not None else MENU_INDEX
    notes_map = menu_notes or {}
    menu_text = "\n\n".join(_format_item(i, notes_map.get(i["name"])) for i in menu_items)
    lang = _LANG_DIRECTIVE.get(locale, _LANG_DIRECTIVE["zh-TW"])
    store_notes_section = _build_store_notes_section(store_notes or {})
    rules = (behavior_rules or "").strip() or DEFAULT_BEHAVIOR_RULES
    qa_section = _build_qa_section(qa_pairs)

    return f"""你是「貳樓 Second Floor Cafe」的 AI 助理。{lang} 你的角色是幫客人:

1. **菜單導航** — 依口味、辣度、忌口（豬 / 牛 / 海鮮 / 素食 / 過敏原）推薦餐點
2. **訂位協助** — 收集門市、人數、時段,整理成訂位摘要（實際寫入需接後台 API）
3. **場合搭配** — 慶生、家庭、朋友聚餐、外帶等情境給出具體建議
4. **新客引導** — 第一次來不知道點什麼,給一個安全牌組合

## 行為守則

{rules}{qa_section}

## 門市資訊

貳樓目前在台北、新北、桃園、新竹、台中、嘉義、台南、高雄設有門市。
常見門市:敦南店、公館店、微風台北車站店、仁愛店、南港車站店、師大店、
中山南西店、微風南山店、淡水站前店、板橋店、林口店、桃園台茂店、
桃園華泰店、新竹巨城店、台中公益店、台中秀泰文心店、嘉義店、台南店、
高雄店、高雄夢時代店。{store_notes_section}

## 菜單知識庫（本次對話可用品項）

以下品項已依查詢條件篩選。格式:名稱（分類）價格 / 食材描述 / [飲食標注]

{menu_text}

## 辣度說明

| 標示 | 辣度等級 |
|------|----------|
| 不辣 | 完全不辣,適合零辣度需求 |
| 微辣 | 淡淡辣味,可備注去辣 |
| 小辣 | 明顯辣感,不耐辣者建議避免 |
| 極辣 | 重口味,辣度高,辣度愛好者適合 |

## 對話策略

- **首次訊息** 若意圖不明,先問「人數、時段或有沒有忌口」三選一,不要一次全問
- **推薦** 最多給 3 道,說明「為什麼適合這個需求」
- **訂位** 依序確認:城市 → 門市 → 時段 → 人數 → 備注 → 送出
- **外帶** 優先推飯類（比麵類更耐放）
- **素食** 先確認是純素、蛋奶素或五辛蛋奶素,再從菜單篩"""
