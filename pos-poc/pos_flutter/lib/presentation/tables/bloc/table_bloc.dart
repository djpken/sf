import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/table_repository.dart';
import 'table_event.dart';
import 'table_state.dart';

class TableBloc extends Bloc<TableEvent, TableState> {
  final TableRepository _tableRepository;

  TableBloc(this._tableRepository) : super(const TableState()) {
    on<LoadTables>(_onLoadTables);
    on<RefreshTables>(_onRefreshTables);
    on<FilterTablesByArea>(_onFilterByArea);
  }

  Future<void> _onLoadTables(LoadTables event, Emitter<TableState> emit) async {
    emit(state.copyWith(status: TableLoadStatus.loading));
    try {
      final tables = await _tableRepository.getTables();
      emit(state.copyWith(status: TableLoadStatus.loaded, tables: tables));
    } catch (e) {
      emit(state.copyWith(
          status: TableLoadStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshTables(
      RefreshTables event, Emitter<TableState> emit) async {
    try {
      final tables = await _tableRepository.getTables();
      emit(state.copyWith(status: TableLoadStatus.loaded, tables: tables));
    } catch (e) {
      emit(state.copyWith(
          status: TableLoadStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onFilterByArea(
      FilterTablesByArea event, Emitter<TableState> emit) async {
    emit(state.copyWith(
      selectedArea: event.area,
      clearAreaFilter: event.area == null,
    ));
  }
}
