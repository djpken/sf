"""核心業務邏輯測試 — 不依賴 LLM，不發網路請求。"""

import os
import sys
import tempfile

# 讓 pytest 能 import app 套件
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# ─── booking: 客滿判定決定性 ────────────────────────────────────────────────────

def test_slot_full_deterministic():
    """同一組輸入永遠回傳相同結果(決定性偽隨機)。"""
    from app.booking import _is_slot_full

    result_a = _is_slot_full("台北信義", "2025-12-31", "19:00", 2)
    result_b = _is_slot_full("台北信義", "2025-12-31", "19:00", 2)
    assert result_a == result_b, "相同輸入應回傳一致的客滿/有位狀態"


def test_check_and_submit_consistency():
    """check_availability 查到客滿 → submit_reservation 同組輸入也應失敗。"""
    from app.booking import _is_slot_full, check_availability, submit_reservation

    store = "台北信義"
    date = "2025-08-15"
    time_ = "18:30"
    party = 8  # 大桌 + 熱門時段,應有相當機率客滿

    # 找一個確定客滿的時段
    full_slot = None
    for t in ("18:00", "19:00", "20:00", "18:30"):
        if _is_slot_full(store, date, t, party):
            full_slot = t
            break

    if full_slot is None:
        # 若測試資料剛好全不滿,跳過此次(不強制失敗)
        return

    submit_result = submit_reservation(
        store=store, date=date, time=full_slot, party_size=party
    )
    assert submit_result["status"] == "failed", (
        f"check 判定客滿的時段 submit 應回 failed，實際: {submit_result}"
    )


# ─── menu RAG: 忌口硬篩選 ────────────────────────────────────────────────────────

def test_retrieve_excludes_pork():
    """no_pork=True 時，結果不應含任何 pork=True 的品項。"""
    from app.menu import retrieve

    results = retrieve("推薦主食", max_items=50, no_pork=True)
    pork_items = [item for item in results if item["tags"]["pork"]]
    assert pork_items == [], f"no_pork=True 卻出現含豬肉品項: {[i['name'] for i in pork_items]}"


# ─── db: SF_DB_PATH env var ────────────────────────────────────────────────────

def test_db_path_env_override():
    """SF_DB_PATH 設定時，_DB_PATH 應使用該路徑而非預設路徑。"""
    with tempfile.TemporaryDirectory() as tmp:
        custom_path = os.path.join(tmp, "test.db")
        os.environ["SF_DB_PATH"] = custom_path

        # 強制重新載入 db 模組讓 _DB_PATH 重算
        import importlib
        import app.db as db_module
        importlib.reload(db_module)

        assert str(db_module._DB_PATH) == custom_path, (
            f"期望 _DB_PATH={custom_path!r}，實際={db_module._DB_PATH!r}"
        )

        # 清理：還原 env 並 reload 成預設
        del os.environ["SF_DB_PATH"]
        importlib.reload(db_module)
