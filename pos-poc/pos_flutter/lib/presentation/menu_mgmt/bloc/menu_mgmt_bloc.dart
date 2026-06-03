import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/repositories/menu_repository.dart';
import 'menu_mgmt_event.dart';
import 'menu_mgmt_state.dart';

class MenuMgmtBloc extends Bloc<MenuMgmtEvent, MenuMgmtState> {
  final MenuRepository _menuRepository;

  MenuMgmtBloc(this._menuRepository) : super(const MenuMgmtState()) {
    on<LoadMenuMgmt>(_onLoad);
    on<SelectMgmtCategory>(_onSelectCategory);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<CreateItem>(_onCreateItem);
    on<UpdateItem>(_onUpdateItem);
    on<DeleteItem>(_onDeleteItem);
  }

  Future<void> _onLoad(LoadMenuMgmt event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.loading));
    try {
      final categories = await _menuRepository.getCategories();
      final firstCategoryId =
          categories.isNotEmpty ? categories.first.id : null;
      final items = firstCategoryId != null
          ? await _menuRepository.getItems(categoryId: firstCategoryId)
          : <MenuItem>[];
      emit(MenuMgmtState(
        status: MenuMgmtStatus.loaded,
        categories: categories,
        items: items,
        selectedCategoryId: firstCategoryId,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onSelectCategory(
      SelectMgmtCategory event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(
        selectedCategoryId: event.categoryId, status: MenuMgmtStatus.loading));
    try {
      final items = event.categoryId != null
          ? await _menuRepository.getItems(categoryId: event.categoryId)
          : await _menuRepository.getItems();
      emit(state.copyWith(status: MenuMgmtStatus.loaded, items: items));
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateCategory(
      CreateCategory event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.createCategory(
        name: event.name,
        description: event.description,
        displayOrder: event.displayOrder,
      );
      add(const LoadMenuMgmt());
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateCategory(
      UpdateCategory event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.updateCategory(
        event.id,
        name: event.name,
        description: event.description,
        displayOrder: event.displayOrder,
        isActive: event.isActive,
      );
      add(const LoadMenuMgmt());
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteCategory(
      DeleteCategory event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.deleteCategory(event.id);
      add(const LoadMenuMgmt());
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreateItem(
      CreateItem event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.createItem(
        categoryId: event.categoryId,
        name: event.name,
        description: event.description,
        price: event.price,
        isActive: event.isActive,
        displayOrder: event.displayOrder,
      );
      add(SelectMgmtCategory(state.selectedCategoryId));
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateItem(
      UpdateItem event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.updateItem(
        event.id,
        categoryId: event.categoryId,
        name: event.name,
        description: event.description,
        price: event.price,
        isActive: event.isActive,
        displayOrder: event.displayOrder,
      );
      add(SelectMgmtCategory(state.selectedCategoryId));
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteItem(
      DeleteItem event, Emitter<MenuMgmtState> emit) async {
    emit(state.copyWith(status: MenuMgmtStatus.saving));
    try {
      await _menuRepository.deleteItem(event.id);
      add(SelectMgmtCategory(state.selectedCategoryId));
    } catch (e) {
      emit(state.copyWith(
          status: MenuMgmtStatus.error, errorMessage: e.toString()));
    }
  }
}
