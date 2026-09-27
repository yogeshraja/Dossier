import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';
import 'package:dossier/data/local/app_database.dart';

enum SalesReportDateRange {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month');

  final String label;
  const SalesReportDateRange(this.label);
}

class SalesReportState {
  final SalesReportDateRange dateRange;
  final DateTime selectedDate;
  final double openingCashFloat;
  final double physicalCountedCash;
  final bool isGeneratingSlip;

  const SalesReportState({
    this.dateRange = SalesReportDateRange.today,
    required this.selectedDate,
    this.openingCashFloat = 500.0,
    this.physicalCountedCash = 500.0,
    this.isGeneratingSlip = false,
  });

  SalesReportState copyWith({
    SalesReportDateRange? dateRange,
    DateTime? selectedDate,
    double? openingCashFloat,
    double? physicalCountedCash,
    bool? isGeneratingSlip,
  }) {
    return SalesReportState(
      dateRange: dateRange ?? this.dateRange,
      selectedDate: selectedDate ?? this.selectedDate,
      openingCashFloat: openingCashFloat ?? this.openingCashFloat,
      physicalCountedCash: physicalCountedCash ?? this.physicalCountedCash,
      isGeneratingSlip: isGeneratingSlip ?? this.isGeneratingSlip,
    );
  }
}

class SalesReportSummary {
  final List<Invoice> invoices;
  final double totalGrossSales;
  final double totalCashCollected;
  final double totalUpiCollected;
  final double totalPendingDues;
  final int totalOrders;
  final Map<String, int> serviceCountBreakdown;

  const SalesReportSummary({
    required this.invoices,
    required this.totalGrossSales,
    required this.totalCashCollected,
    required this.totalUpiCollected,
    required this.totalPendingDues,
    required this.totalOrders,
    required this.serviceCountBreakdown,
  });
}

class SalesReportNotifier extends StateNotifier<SalesReportState> {
  SalesReportNotifier()
      : super(SalesReportState(selectedDate: DateTime.now()));

  void setDateRange(SalesReportDateRange range) {
    state = state.copyWith(dateRange: range);
  }

  void setOpeningFloat(double amount) {
    state = state.copyWith(openingCashFloat: amount);
  }

  void setPhysicalCash(double amount) {
    state = state.copyWith(physicalCountedCash: amount);
  }

  void setGeneratingSlip(bool isGenerating) {
    state = state.copyWith(isGeneratingSlip: isGenerating);
  }
}

final salesReportProvider =
    StateNotifierProvider<SalesReportNotifier, SalesReportState>((ref) {
  return SalesReportNotifier();
});

final salesReportSummaryProvider = Provider<AsyncValue<SalesReportSummary>>((ref) {
  final invoicesAsync = ref.watch(recentInvoicesStreamProvider);
  final reportState = ref.watch(salesReportProvider);

  return invoicesAsync.whenData((invoices) {
    final now = DateTime.now();
    final filtered = invoices.where((inv) {
      final invDate = inv.createdAt;
      switch (reportState.dateRange) {
        case SalesReportDateRange.today:
          return invDate.year == now.year &&
              invDate.month == now.month &&
              invDate.day == now.day;
        case SalesReportDateRange.yesterday:
          final yesterday = now.subtract(const Duration(days: 1));
          return invDate.year == yesterday.year &&
              invDate.month == yesterday.month &&
              invDate.day == yesterday.day;
        case SalesReportDateRange.thisWeek:
          final weekAgo = now.subtract(const Duration(days: 7));
          return invDate.isAfter(weekAgo);
        case SalesReportDateRange.thisMonth:
          return invDate.year == now.year && invDate.month == now.month;
      }
    }).toList();

    double totalGross = 0;
    double cash = 0;
    double upi = 0;
    double dues = 0;
    final Map<String, int> serviceBreakdown = {};

    for (final inv in filtered) {
      totalGross += inv.grandTotal;
      if (inv.paymentStatus.toUpperCase() == 'PAID') {
        cash += inv.amountPaid;
      } else {
        upi += inv.amountPaid;
      }
      dues += (inv.grandTotal - inv.amountPaid).clamp(0.0, double.infinity);
      final label = inv.invoiceType == 'WALK_IN_POS' ? 'Quick POS Sale' : 'Case Service Fee';
      serviceBreakdown[label] = (serviceBreakdown[label] ?? 0) + 1;
    }

    return SalesReportSummary(
      invoices: filtered,
      totalGrossSales: totalGross,
      totalCashCollected: cash,
      totalUpiCollected: upi,
      totalPendingDues: dues,
      totalOrders: filtered.length,
      serviceCountBreakdown: serviceBreakdown,
    );
  });
});
