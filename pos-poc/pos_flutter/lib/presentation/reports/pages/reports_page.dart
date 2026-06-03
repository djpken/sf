import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../data/repositories/report_repository.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Map<String, dynamic>? _summary;
  List<dynamic> _productRanking = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repository = getIt<ReportRepository>();
      final summary = await repository.getSummary();
      final ranking = await repository.getProductRanking(limit: 10);

      setState(() {
        _summary = summary;
        _productRanking = ranking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          color: Colors.white,
          child: Row(
            children: [
              Text(l10n.reportsTitle,
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: _loadReports,
                tooltip: l10n.refresh,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48.sp, color: AppColors.error),
                          SizedBox(height: 12.h),
                          Text(l10n.loadFailed,
                              style: TextStyle(
                                  fontSize: 16.sp, color: AppColors.error)),
                          SizedBox(height: 8.h),
                          Text(_error!,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary)),
                          SizedBox(height: 12.h),
                          ElevatedButton(
                              onPressed: _loadReports, child: Text(l10n.retry)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.todaySummary,
                                style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 12.h),
                            if (_summary != null)
                              _buildSummaryCards(l10n, _summary!),
                            SizedBox(height: 24.h),
                            Text(l10n.productRanking,
                                style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 12.h),
                            _buildProductRanking(l10n),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
      AppLocalizations l10n, Map<String, dynamic> summary) {
    final revenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (summary['order_count'] as num?)?.toInt() ?? 0;
    final avgOrder = (summary['average_order_value'] as num?)?.toDouble() ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 2.0,
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      children: [
        _SummaryCard(
          icon: Icons.attach_money,
          label: l10n.todayRevenue,
          value: 'NT\$ ${revenue.toStringAsFixed(0)}',
          color: AppColors.primary,
        ),
        _SummaryCard(
          icon: Icons.receipt_long,
          label: l10n.orderCount,
          value: '$orderCount',
          color: AppColors.success,
        ),
        _SummaryCard(
          icon: Icons.trending_up,
          label: l10n.avgOrder,
          value: 'NT\$ ${avgOrder.toStringAsFixed(0)}',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildProductRanking(AppLocalizations l10n) {
    if (_productRanking.isEmpty) {
      return Center(
        child: Text(l10n.noDataAvailable,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp)),
      );
    }
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _productRanking.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _productRanking[index] as Map<String, dynamic>;
          final name = item['item_name'] as String? ?? '-';
          final qty = (item['total_quantity'] as num?)?.toInt() ?? 0;
          final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  index < 3 ? AppColors.primary : AppColors.surface,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index < 3 ? Colors.white : AppColors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(name,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
            subtitle: Text(l10n.salesQty(qty),
                style:
                    TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            trailing: Text(
              'NT\$ ${revenue.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.sp, color: AppColors.textSecondary)),
                  SizedBox(height: 4.h),
                  Text(value,
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
