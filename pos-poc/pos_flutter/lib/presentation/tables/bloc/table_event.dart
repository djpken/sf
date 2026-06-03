import 'package:equatable/equatable.dart';

abstract class TableEvent extends Equatable {
  const TableEvent();

  @override
  List<Object?> get props => [];
}

class LoadTables extends TableEvent {
  const LoadTables();
}

class RefreshTables extends TableEvent {
  const RefreshTables();
}

class FilterTablesByArea extends TableEvent {
  final String? area;
  const FilterTablesByArea(this.area);

  @override
  List<Object?> get props => [area];
}
