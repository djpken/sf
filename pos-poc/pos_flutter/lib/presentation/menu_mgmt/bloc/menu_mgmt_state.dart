import 'package:equatable/equatable.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';

enum MenuMgmtStatus { initial, loading, loaded, saving, error }

class MenuMgmtState extends Equatable {
  final MenuMgmtStatus status;
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;
  final String? errorMessage;

  const MenuMgmtState({
    this.status = MenuMgmtStatus.initial,
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.errorMessage,
  });

  MenuMgmtState copyWith({
    MenuMgmtStatus? status,
    List<MenuCategory>? categories,
    List<MenuItem>? items,
    String? selectedCategoryId,
    String? errorMessage,
  }) {
    return MenuMgmtState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, categories, items, selectedCategoryId, errorMessage];
}
