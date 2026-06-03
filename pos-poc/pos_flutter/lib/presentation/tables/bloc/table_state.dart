import 'package:equatable/equatable.dart';
import '../../../data/models/table.dart';

enum TableLoadStatus { initial, loading, loaded, error }

class TableState extends Equatable {
  final TableLoadStatus status;
  final List<TableModel> tables;
  final String? selectedArea;
  final String? errorMessage;

  const TableState({
    this.status = TableLoadStatus.initial,
    this.tables = const [],
    this.selectedArea,
    this.errorMessage,
  });

  List<TableModel> get filteredTables {
    if (selectedArea == null) return tables;
    return tables.where((t) => t.area == selectedArea).toList();
  }

  List<String> get availableAreas {
    final areas =
        tables.map((t) => t.area).whereType<String>().toSet().toList();
    areas.sort();
    return areas;
  }

  TableState copyWith({
    TableLoadStatus? status,
    List<TableModel>? tables,
    String? selectedArea,
    bool clearAreaFilter = false,
    String? errorMessage,
  }) {
    return TableState(
      status: status ?? this.status,
      tables: tables ?? this.tables,
      selectedArea:
          clearAreaFilter ? null : (selectedArea ?? this.selectedArea),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tables, selectedArea, errorMessage];
}
