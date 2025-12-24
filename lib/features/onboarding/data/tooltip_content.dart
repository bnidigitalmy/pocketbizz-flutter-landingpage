/// Tooltip content untuk setiap module
class TooltipContent {
  // Dashboard Module
  static const dashboard = TooltipData(
    moduleKey: 'dashboard',
    title: 'Selamat Datang!',
    message: 'Lihat ringkasan perniagaan hari ini. Jualan, stok rendah, dan tindakan segera semua ada di sini.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  // Sales Module
  static const sales = TooltipData(
    moduleKey: 'sales',
    title: 'Sistem Jualan',
    message: 'Rekod jualan harian anda di sini. Pilih produk, tambah ke cart, dan buat invois.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const salesEmpty = TooltipData(
    moduleKey: 'sales_empty',
    title: 'Belum Ada Jualan',
    message: 'Buat jualan pertama anda dengan klik butang "Jualan Baru".',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Expenses Module
  static const expenses = TooltipData(
    moduleKey: 'expenses',
    title: 'Rekod Perbelanjaan',
    message: 'Simpan semua resit perbelanjaan di sini. Scan resit atau masukkan manual.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const expensesEmpty = TooltipData(
    moduleKey: 'expenses_empty',
    title: 'Mula Rekod Perbelanjaan',
    message: 'Klik "Tambah Perbelanjaan" untuk simpan resit pertama anda.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Inventory Module
  static const inventory = TooltipData(
    moduleKey: 'inventory',
    title: 'Urus Stok',
    message: 'Lihat semua stok dalam satu tempat. Dapat alert bila stok nak habis.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const inventoryEmpty = TooltipData(
    moduleKey: 'inventory_empty',
    title: 'Tambah Stok Pertama',
    message: 'Tambah produk dan stok anda. Sistem akan track stok automatik selepas jualan.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Reports Module
  static const reports = TooltipData(
    moduleKey: 'reports',
    title: 'Laporan Perniagaan',
    message: 'Lihat untung rugi, jualan mengikut bulan, dan analisis perniagaan anda.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const reportsEmpty = TooltipData(
    moduleKey: 'reports_empty',
    title: 'Laporan Akan Muncul',
    message: 'Selepas rekod jualan dan perbelanjaan, laporan automatik akan dihasilkan.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Products Module
  static const products = TooltipData(
    moduleKey: 'products',
    title: 'Senarai Produk',
    message: 'Tambah dan urus semua produk di sini. Produk akan muncul dalam sistem jualan.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const productsEmpty = TooltipData(
    moduleKey: 'products_empty',
    title: 'Tambah Produk Pertama',
    message: 'Tambah produk anda. Selepas tambah, anda boleh guna dalam sistem jualan.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Bookings Module
  static const bookings = TooltipData(
    moduleKey: 'bookings',
    title: 'Sistem Tempahan',
    message: 'Urus semua tempahan pelanggan di sini. Buat tempahan baru dan track status.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const bookingsEmpty = TooltipData(
    moduleKey: 'bookings_empty',
    title: 'Belum Ada Tempahan',
    message: 'Klik "Tempahan Baru" untuk buat tempahan pertama anda.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Vendors Module
  static const vendors = TooltipData(
    moduleKey: 'vendors',
    title: 'Urus Vendor',
    message: 'Tambah vendor yang jual produk anda. Set commission dan sistem akan track bayaran automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const vendorsEmpty = TooltipData(
    moduleKey: 'vendors_empty',
    title: 'Tambah Vendor Pertama',
    message: 'Tambah vendor atau reseller di sini. Sistem akan track commission dan bayaran.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Claims Module
  static const claims = TooltipData(
    moduleKey: 'claims',
    title: 'Urus Tuntutan',
    message: 'Bila vendor jual produk anda, buat tuntutan di sini. Sistem akan kira commission automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const claimsEmpty = TooltipData(
    moduleKey: 'claims_empty',
    title: 'Belum Ada Tuntutan',
    message: 'Buat tuntutan baru bila vendor jual produk anda. Sistem akan kira commission automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Suppliers Module
  static const suppliers = TooltipData(
    moduleKey: 'suppliers',
    title: 'Senarai Pembekal',
    message: 'Simpan maklumat semua pembekal anda di sini. Senang untuk contact dan buat purchase order.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const suppliersEmpty = TooltipData(
    moduleKey: 'suppliers_empty',
    title: 'Tambah Pembekal Pertama',
    message: 'Tambah pembekal yang supply bahan kepada anda. Selepas tambah, boleh buat purchase order.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Purchase Orders Module
  static const purchaseOrders = TooltipData(
    moduleKey: 'purchase_orders',
    title: 'Purchase Order',
    message: 'Buat order kepada pembekal di sini. Track status dan stok akan update automatik bila delivered.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const purchaseOrdersEmpty = TooltipData(
    moduleKey: 'purchase_orders_empty',
    title: 'Belum Ada PO',
    message: 'Klik "PO Baru" untuk buat purchase order pertama. Stok akan update automatik bila delivered.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Shopping List Module
  static const shoppingList = TooltipData(
    moduleKey: 'shopping_list',
    title: 'Shopping List',
    message: 'Sistem akan suggest barang bila stok rendah. Tambah manual atau convert ke purchase order.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const shoppingListEmpty = TooltipData(
    moduleKey: 'shopping_list_empty',
    title: 'Shopping List Kosong',
    message: 'Sistem akan suggest barang bila stok rendah. Anda juga boleh tambah manual.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Production Module
  static const production = TooltipData(
    moduleKey: 'production',
    title: 'Planning Production',
    message: 'Plan production berdasarkan recipe. Track bahan dan hasil. Stok akan update automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const productionEmpty = TooltipData(
    moduleKey: 'production_empty',
    title: 'Mula Planning',
    message: 'Buat production plan dan rekod production. Stok finished products akan update automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Recipes Module
  static const recipes = TooltipData(
    moduleKey: 'recipes',
    title: 'Recipe & Bahan',
    message: 'Simpan semua recipe produk anda di sini. Sistem akan kira kos production automatik.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const recipesEmpty = TooltipData(
    moduleKey: 'recipes_empty',
    title: 'Tambah Recipe Pertama',
    message: 'Tambah recipe untuk produk anda. Set bahan dan kuantiti, sistem akan kira kos automatik.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Planner Module
  static const planner = TooltipData(
    moduleKey: 'planner',
    title: 'Task & Planner',
    message: 'Urus semua task dan planning perniagaan di sini. Buat task, set deadline, dan track progress.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const plannerEmpty = TooltipData(
    moduleKey: 'planner_empty',
    title: 'Mula Planning',
    message: 'Tambah task pertama anda. Set deadline dan priority untuk organize kerja harian.',
    triggerCondition: TriggerCondition.emptyState,
  );

  // Deliveries Module
  static const deliveries = TooltipData(
    moduleKey: 'deliveries',
    title: 'Urus Penghantaran',
    message: 'Hantar produk kepada vendor di sini. Track status penghantaran dan terima balik produk yang tidak terjual.',
    triggerCondition: TriggerCondition.firstVisit,
  );

  static const deliveriesEmpty = TooltipData(
    moduleKey: 'deliveries_empty',
    title: 'Belum Ada Penghantaran',
    message: 'Buat penghantaran pertama kepada vendor. Klik "Penghantaran Baru" untuk mula.',
    triggerCondition: TriggerCondition.emptyState,
  );
}

/// Tooltip data model
class TooltipData {
  final String moduleKey;
  final String title;
  final String message;
  final TriggerCondition triggerCondition;

  const TooltipData({
    required this.moduleKey,
    required this.title,
    required this.message,
    required this.triggerCondition,
  });
}

/// Trigger conditions untuk tooltip
enum TriggerCondition {
  firstVisit, // Show sekali je, first time masuk module
  emptyState, // Show bila tak ada data
  firstAction, // Show sebelum first action
}
