enum InventoryType {
  daily('當日盤點'),
  weekly('每週盤點'),
  monthly('月底盤點');

  final String label;

  const InventoryType(this.label);
}
