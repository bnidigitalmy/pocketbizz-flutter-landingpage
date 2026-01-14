import 'package:intl/intl.dart';

import '../../data/models/stock_item.dart';
import '../../data/models/production_batch.dart';
import '../../data/repositories/bookings_repository_supabase.dart';
import '../../data/repositories/purchase_order_repository_supabase.dart';
import '../../data/repositories/planner_tasks_repository_supabase.dart';
import '../../data/repositories/stock_repository_supabase.dart';
import '../../data/repositories/production_repository_supabase.dart';
import '../../data/repositories/consignment_claims_repository_supabase.dart';
import '../supabase/supabase_client.dart';

/// Lightweight auto-task generator (runs on-demand from dashboard)
class PlannerAutoService {
  PlannerAutoService()
      : _plannerRepo = PlannerTasksRepositorySupabase(),
        _stockRepo = StockRepository(supabase),
        _poRepo = PurchaseOrderRepository(supabase),
        _bookingsRepo = BookingsRepositorySupabase(),
        _productionRepo = ProductionRepository(supabase),
        _claimsRepo = ConsignmentClaimsRepositorySupabase();

  final PlannerTasksRepositorySupabase _plannerRepo;
  final StockRepository _stockRepo;
  final PurchaseOrderRepository _poRepo;
  final BookingsRepositorySupabase _bookingsRepo;
  final ProductionRepository _productionRepo;
  final ConsignmentClaimsRepositorySupabase _claimsRepo;

  /// DISABLED: Auto-generate tasks removed
  /// Planner now only shows user-created tasks
  /// Dashboard alert widgets handle system alerts (bookings, low stock, expiry, etc.)
  Future<void> runAll() async {
    // Auto-generate tasks disabled - planner is now for user-created tasks only
    // This prevents duplicate alerts with dashboard alert widgets
    return;
  }

  Future<void> _generateLowStockTasks() async {
    final items = await _stockRepo.getLowStockItems();
    final now = DateTime.now();
    for (final StockItem item in items.take(20)) {
      final due = DateTime(now.year, now.month, now.day, 9, 0);
      final title = 'Stok rendah: ${item.name} (${item.currentQuantity.toStringAsFixed(1)} ${item.unit})';
      final hash = 'auto_low_stock:${item.id}';
      await _plannerRepo.upsertAutoTask(
        autoHash: hash,
        title: title,
        type: 'auto_low_stock',
        source: 'inventory',
        linkedType: 'stock',
        linkedId: item.id,
        dueAt: due,
        remindAt: due.subtract(const Duration(minutes: 30)),
        metadata: {
          'current_quantity': item.currentQuantity,
          'threshold': item.lowStockThreshold,
          'unit': item.unit,
        },
      );
    }
  }

  Future<void> _generatePendingPOTasks() async {
    final allPOs = await _poRepo.getAllPurchaseOrders();
    final pending = allPOs.where((po) => po.status == 'pending').take(20);
    final now = DateTime.now();
    for (final po in pending) {
      final due = now.add(const Duration(hours: 4));
      final title = 'Terima barang untuk PO ${po.poNumber} (${po.supplierName})';
      final hash = 'auto_po_pending:${po.id}';
      await _plannerRepo.upsertAutoTask(
        autoHash: hash,
        title: title,
        type: 'auto_po_pending',
        source: 'po',
        linkedType: 'po',
        linkedId: po.id,
        dueAt: due,
        remindAt: due.subtract(const Duration(minutes: 30)),
        metadata: {
          'supplier': po.supplierName,
          'total': po.totalAmount,
        },
      );
    }
  }

  Future<void> _generateTodayBookingTasks() async {
    // Best-effort: get bookings and check those scheduled for today
    final bookings = await _bookingsRepo.listBookings();
    final today = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    final todayKey = formatter.format(today);

    for (final b in bookings.take(30)) {
      final scheduledDate = DateTime.tryParse(b.deliveryDate);
      if (scheduledDate == null) continue;
      final key = formatter.format(scheduledDate);
      final isToday = key == todayKey;
      final isPending = (b.status.toLowerCase()) == 'pending';
      if (!isToday || !isPending) continue;

      final due = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9,
        0,
      );
      final title = 'Siapkan tempahan ${b.bookingNumber} untuk hari ini';
      final hash = 'auto_booking_delivery:${b.id}:$todayKey';

      await _plannerRepo.upsertAutoTask(
        autoHash: hash,
        title: title,
        type: 'auto_booking_delivery',
        source: 'booking',
        linkedType: 'booking',
        linkedId: b.id,
        dueAt: due,
        remindAt: due.subtract(const Duration(minutes: 45)),
        metadata: {
          'customer': b.customerName,
          'amount': b.totalAmount,
          'status': b.status,
        },
      );
    }
  }

  Future<void> _generateClaimBalanceTasks() async {
    // Fetch claims with balance > 0 and status not settled
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final resp = await supabase
        .from('consignment_claims')
        .select('id, claim_number, vendor_name, balance_amount, due_date, status')
        .eq('business_owner_id', userId)
        .neq('status', 'settled')
        .gt('balance_amount', 0)
        .limit(30);

    if (resp is! List) return;
    final now = DateTime.now();
    for (final row in resp) {
      final claimId = row['id'] as String;
      final claimNumber = (row['claim_number'] as String?) ?? claimId.substring(0, 6);
      final vendorName = row['vendor_name'] as String? ?? 'Vendor';
      final balance = (row['balance_amount'] as num?)?.toDouble() ?? 0.0;
      final dueDateStr = row['due_date'] as String?;
      DateTime? dueDate;
      if (dueDateStr != null) {
        dueDate = DateTime.tryParse(dueDateStr)?.toLocal();
      }

      final isOverdue = dueDate != null && dueDate.isBefore(now);
      final due = dueDate ?? now.add(const Duration(hours: 6));
      final title = isOverdue
          ? 'Bayar tuntutan $claimNumber (terlewat) - $vendorName'
          : 'Bayar tuntutan $claimNumber - $vendorName';
      final hash = 'auto_vendor_claim:$claimId';

      await _plannerRepo.upsertAutoTask(
        autoHash: hash,
        title: title,
        type: 'auto_vendor_claim',
        source: 'claims',
        linkedType: 'claim',
        linkedId: claimId,
        dueAt: due,
        remindAt: due.subtract(const Duration(minutes: 45)),
        metadata: {
          'vendor': vendorName,
          'balance': balance,
          'due_date': dueDate?.toIso8601String(),
          'status': row['status'],
        },
      );
    }
  }

  Future<void> _generateExpiryBatchTasks() async {
    // Batches that will expire within 3 days and still have remaining qty
    final batches = await _productionRepo.getAllBatches();
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 3));

    for (final ProductionBatch b in batches.take(40)) {
      if (b.expiryDate == null) continue;
      if (b.remainingQty <= 0) continue;
      final exp = b.expiryDate!;
      if (exp.isBefore(now)) {
        // already expired - prompt immediate action
        final title = 'Batch ${b.batchNumber ?? b.id} sudah luput (${b.productName})';
        final hash = 'auto_expiry:${b.id}:expired';
        await _plannerRepo.upsertAutoTask(
          autoHash: hash,
          title: title,
          type: 'auto_expiry',
          source: 'production',
          linkedType: 'batch',
          linkedId: b.id,
          dueAt: now.add(const Duration(hours: 1)),
          remindAt: now.add(const Duration(minutes: 10)),
          metadata: {
            'product': b.productName,
            'expiry_date': exp.toIso8601String(),
            'remaining_qty': b.remainingQty,
          },
        );
      } else if (!exp.isAfter(soon)) {
        // expiring soon
        final title = 'Batch ${b.batchNumber ?? b.id} luput ${DateFormat('d MMM', 'ms_MY').format(exp)} - ${b.productName}';
        final hash = 'auto_expiry:${b.id}:${DateFormat('yyyyMMdd').format(exp)}';
        final due = DateTime(exp.year, exp.month, exp.day, 9, 0);
        await _plannerRepo.upsertAutoTask(
          autoHash: hash,
          title: title,
          type: 'auto_expiry',
          source: 'production',
          linkedType: 'batch',
          linkedId: b.id,
          dueAt: due,
          remindAt: due.subtract(const Duration(hours: 2)),
          metadata: {
            'product': b.productName,
            'expiry_date': exp.toIso8601String(),
            'remaining_qty': b.remainingQty,
          },
        );
      }
    }
  }
}

