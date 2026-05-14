const baseTables = [
  { id: '01', zone: 'main', seats: 2, status: 'served', party: 2, elapsed: 38 },
  { id: '02', zone: 'main', seats: 2, status: 'available', party: 0, elapsed: 0 },
  { id: '03', zone: 'main', seats: 4, status: 'cooking', party: 3, elapsed: 17 },
  { id: '04', zone: 'main', seats: 4, status: 'cooking', party: 4, elapsed: 26, overdue: 1 },
  { id: '05', zone: 'main', seats: 2, status: 'waitingVisit', party: 2, elapsed: 44 },
  { id: '06', zone: 'main', seats: 2, status: 'seated', party: 2, elapsed: 8 },
  { id: '07', zone: 'main', seats: 4, status: 'ordering', party: 3, elapsed: 11 },
  { id: '08', zone: 'main', seats: 4, status: 'available', party: 0, elapsed: 0 },
  { id: '09', zone: 'main', seats: 4, status: 'cooking', party: 4, elapsed: 10 },
  { id: '10', zone: 'main', seats: 6, status: 'served', party: 5, elapsed: 51 },
  { id: '11', zone: 'main', seats: 2, status: 'available', party: 0, elapsed: 0 },
  { id: '12', zone: 'main', seats: 2, status: 'cooking', party: 2, elapsed: 31, overdue: 2 },
  { id: '13', zone: 'main', seats: 4, status: 'checkout', party: 4, elapsed: 73 },
  { id: '14', zone: 'main', seats: 4, status: 'available', party: 0, elapsed: 0 },
  { id: '15', zone: 'main', seats: 2, status: 'cleaning', party: 0, elapsed: 0 },
  { id: '29', zone: 'window', seats: 2, status: 'cooking', party: 2, elapsed: 13 },
  { id: '30', zone: 'window', seats: 4, status: 'cooking', party: 4, elapsed: 29, overdue: 1 },
  { id: '31', zone: 'window', seats: 2, status: 'available', party: 0, elapsed: 0 },
  { id: '32', zone: 'window', seats: 2, status: 'served', party: 2, elapsed: 46 },
  { id: '33', zone: 'window', seats: 4, status: 'ordering', party: 3, elapsed: 14 },
  { id: '34', zone: 'window', seats: 4, status: 'waitingVisit', party: 4, elapsed: 48 },
  { id: '35', zone: 'window', seats: 2, status: 'available', party: 0, elapsed: 0 },
];

function makeTables() {
  const existing = new Map(baseTables.map((table) => [table.id, table]));
  const tables = [];
  for (let i = 1; i <= 56; i += 1) {
    const id = String(i).padStart(2, '0');
    const zone = i <= 28 ? 'main' : 'window';
    tables.push(existing.get(id) || {
      id,
      zone,
      seats: [2, 4, 2, 6][i % 4],
      status: 'available',
      party: 0,
      elapsed: 0,
    });
  }
  return tables;
}

window.POS_DATA = {
  zones: [
    { id: 'main', label: '主廳', mark: 'A' },
    { id: 'window', label: '窗邊區', mark: 'B' },
  ],
  tables: makeTables(),
  menu: [
    { id: 'combo-a', category: '套餐', name: '貳樓經典早午餐', subtitle: '線上訂位套餐流程：先選時段，再選套餐', price: 420, prep: 12, tags: ['套餐'] },
    { id: 'combo-b', category: '套餐', name: '班尼迪克蛋套餐', subtitle: '含主餐、附餐與飲品，低消 NT$200', price: 480, prep: 14, tags: ['套餐'] },
    { id: 'combo-c', category: '套餐', name: '美式大早餐套餐', subtitle: '適合雙人分享，可加購飲品升級', price: 520, prep: 16, tags: ['套餐'] },
    { id: 'pasta', category: '主餐', name: '奶油培根義大利麵', subtitle: '可備註少醬、加辣、兒童餐具', price: 360, prep: 13, tags: ['人氣'] },
    { id: 'burger', category: '主餐', name: '貳樓牛肉起司堡', subtitle: '薯條可更換沙拉', price: 390, prep: 15, tags: ['招牌'] },
    { id: 'salad', category: '主餐', name: '嫩雞凱薩沙拉', subtitle: '清爽選項，可做醬汁另放', price: 320, prep: 8, tags: ['快速'] },
    { id: 'latte', category: '飲料', name: '熱拿鐵', subtitle: '套餐飲料選項，可補差額升級', price: 160, prep: 3, tags: ['飲料'] },
    { id: 'tea', category: '飲料', name: '冰紅茶', subtitle: '套餐基本飲料，可調整冰量甜度', price: 120, prep: 2, tags: ['飲料'] },
    { id: 'cake', category: '甜點', name: '巴斯克乳酪蛋糕', subtitle: '可加生日牌，適合訪桌加點', price: 180, prep: 4, tags: ['甜點'] },
  ],
  modifiers: {
    doneness: ['套餐 A', '套餐 B', '單點', '加購飲品'],
    notes: ['少醬', '醬汁另放', '先上', '兒童餐具', '生日牌'],
  },
};
