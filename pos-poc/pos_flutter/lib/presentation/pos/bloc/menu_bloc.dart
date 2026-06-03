import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/menu_repository.dart';
import 'menu_event.dart';
import 'menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  final MenuRepository _menuRepository;

  MenuBloc(this._menuRepository) : super(const MenuState()) {
    on<LoadMenu>(_onLoadMenu);
    on<SelectCategory>(_onSelectCategory);
  }

  Future<void> _onLoadMenu(LoadMenu event, Emitter<MenuState> emit) async {
    emit(state.copyWith(status: MenuStatus.loading));
    try {
      final categories = await _menuRepository.getCategories();
      if (categories.isEmpty) {
        emit(state.copyWith(status: MenuStatus.loaded, categories: categories));
        return;
      }
      final firstCategoryId = categories.first.id;
      final items = await _menuRepository.getItems(categoryId: firstCategoryId);
      emit(state.copyWith(
        status: MenuStatus.loaded,
        categories: categories,
        items: items,
        selectedCategoryId: firstCategoryId,
      ));
    } catch (e) {
      emit(
          state.copyWith(status: MenuStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onSelectCategory(
      SelectCategory event, Emitter<MenuState> emit) async {
    emit(state.copyWith(
        status: MenuStatus.loading, selectedCategoryId: event.categoryId));
    try {
      final items =
          await _menuRepository.getItems(categoryId: event.categoryId);
      emit(state.copyWith(status: MenuStatus.loaded, items: items));
    } catch (e) {
      emit(
          state.copyWith(status: MenuStatus.error, errorMessage: e.toString()));
    }
  }
}
