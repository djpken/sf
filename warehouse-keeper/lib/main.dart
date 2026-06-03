import 'package:flutter/material.dart';
import 'package:warehouse_keeper/screens/store_selection_screen.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

void main() {
  runApp(const WarehouseKeeperApp());
}

class WarehouseKeeperApp extends StatelessWidget {
  const WarehouseKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '貳樓補給站',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const StoreSelectionScreen(),
    );
  }
}
