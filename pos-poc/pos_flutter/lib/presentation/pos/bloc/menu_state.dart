import 'package:equatable/equatable.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';

enum MenuStatus { initial, loading, loaded, error }

class MenuState extends Equatable {
  final MenuStatus status;
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;
  final String? errorMessage;

  const MenuState({
    this.status = MenuStatus.initial,
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.errorMessage,
  });

  MenuState copyWith({
    MenuStatus? status,
    List<MenuCategory>? categories,
    List<MenuItem>? items,
    String? selectedCategoryId,
    String? errorMessage,
  }) {
    return MenuState(
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
