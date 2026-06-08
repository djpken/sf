const DICT = {
  'zh-TW': {
    'welcome.title': '嗨，我是貳樓 AI 助理',
    'welcome.subtitle': '幫你看菜單、配餐點、找適合的門市時段。從下面挑一個，或直接打字開始。',
    'composer.placeholder': '輸入訊息，或點上方建議開始…',
    'sidebar.wordmark': '貳樓助理',
    'sidebar.label': '對話列表',
    'sidebar.close': '關閉側欄',
    'sidebar.new': '新對話',
    'sidebar.history': '歷史對話',
    'sidebar.empty': '還沒有對話紀錄',
    'sidebar.untitled': '未命名對話',
    'sidebar.delete': '刪除對話',
    'chat.title': 'Second Floor Assistant',
    'chat.label': '貳樓助理對話',
    'chat.menu': '對話選單',
    'copy': '複製',
    'copied': '已複製',
    'send': '送出訊息',
    'error.load': '載入對話失敗',
    'followups.ask': '你可能想問',
    'followups.say': '你可能想說',
    'booking.confirmed': '✅ 訂位已送出（測試）· 單號 {id}',
    'booking.failed': '😣 這個時段客滿，訂位未成立（測試）',
    'booking.time': '時段',
    'booking.party': '人數',
    'booking.note': '備註',
    'avail.available': '有位可訂',
    'avail.full': '此時段客滿',
    'avail.date': '日期',
    'avail.time': '時段',
    'avail.party': '人數',
    'avail.alts': '可改時段',
    'avail.altSend': '改 {time} 可以嗎？',
    'lookup.none': '查無此訂位',
    'lookup.noneHint': '查不到單號 {id}，請確認是否正確（測試資料）。',
    'lookup.ref': '單號',
    'status.confirmed': '已確認',
    'store.address': '地址',
    'store.phone': '電話',
    'store.hours': '時間',
    'lang.switch': 'EN',
    'contact.label': '聯絡門市',
    'contact.title': '門市電話',
    'menu.related': '相關菜色',
  },
  en: {
    'welcome.title': "Hi, I'm the Second Floor Assistant",
    'welcome.subtitle': 'Browse the menu, pair dishes, and find the right location and time. Pick one below or just type.',
    'composer.placeholder': 'Type a message, or pick a suggestion above…',
    'sidebar.wordmark': 'SF Assistant',
    'sidebar.label': 'Conversations',
    'sidebar.close': 'Close sidebar',
    'sidebar.new': 'New chat',
    'sidebar.history': 'History',
    'sidebar.empty': 'No conversations yet',
    'sidebar.untitled': 'Untitled chat',
    'sidebar.delete': 'Delete chat',
    'chat.title': 'Second Floor Assistant',
    'chat.label': 'Second Floor chat',
    'chat.menu': 'Chat menu',
    'copy': 'Copy',
    'copied': 'Copied',
    'send': 'Send message',
    'error.load': 'Failed to load conversation',
    'followups.ask': 'You might want to ask',
    'followups.say': 'You might want to say',
    'booking.confirmed': '✅ Booking confirmed (test) · Ref {id}',
    'booking.failed': '😣 That slot is full — booking not made (test)',
    'booking.time': 'Time',
    'booking.party': 'Party',
    'booking.note': 'Note',
    'avail.available': 'Available',
    'avail.full': 'Fully booked',
    'avail.date': 'Date',
    'avail.time': 'Time',
    'avail.party': 'Party',
    'avail.alts': 'Other slots',
    'avail.altSend': 'How about {time}?',
    'lookup.none': 'Reservation not found',
    'lookup.noneHint': 'No booking for {id} — please check the reference (test data).',
    'lookup.ref': 'Ref',
    'status.confirmed': 'Confirmed',
    'store.address': 'Address',
    'store.phone': 'Phone',
    'store.hours': 'Hours',
    'lang.switch': '中',
    'contact.label': 'Call Store',
    'contact.title': 'Store Phones',
    'menu.related': 'Related dishes',
  },
};

const SUPPORTED = ['zh-TW', 'en'];

export function getLocale() {
  const stored = localStorage.getItem('sf_locale');
  if (stored && SUPPORTED.includes(stored)) return stored;
  return navigator.language?.startsWith('en') ? 'en' : 'zh-TW';
}

export function persistLocale(locale) {
  localStorage.setItem('sf_locale', locale);
  document.documentElement.lang = locale;
}

export function t(locale, key, vars = {}) {
  const dict = DICT[locale] ?? DICT['zh-TW'];
  let str = dict[key] ?? DICT['zh-TW'][key] ?? key;
  for (const [k, v] of Object.entries(vars)) {
    str = str.replace(`{${k}}`, String(v));
  }
  return str;
}

export const STARTERS = {
  'zh-TW': [
    '今晚 4 個朋友想吃貳樓，想找可以慢慢聊天的位子。',
    '想幫女友慶生，但不要那種很正式的餐廳。',
    '今天想吃清爽一點，但不要吃完很空。',
    '第一次吃貳樓，不知道招牌是什麼，也怕點太多。',
    '想帶兩份主餐回家，一份不要太辣。',
    '我同事不吃豬肉，想幫大家找可以一起點的餐。',
  ],
  en: [
    '4 friends tonight at Second Floor — looking for a relaxed spot to linger.',
    'Planning a birthday dinner for my girlfriend, but nothing too formal.',
    'Want something light today, but not unsatisfying.',
    "First time here — not sure what the signature dishes are, afraid of over-ordering.",
    'Taking two entrees home — one not too spicy.',
    "My colleague doesn't eat pork — want dishes we can all share.",
  ],
};
