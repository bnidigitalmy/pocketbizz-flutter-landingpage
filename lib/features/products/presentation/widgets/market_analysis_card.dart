import 'package:flutter/material.dart';
import '../../../../core/utils/market_analysis_calculator.dart';
import '../../../../data/models/competitor_price.dart';
import '../../../../data/models/product.dart';
import 'competitor_price_dialog.dart';
import 'competitor_prices_list_dialog.dart';

/// Market Analysis Card Widget
/// Displays market analysis and pricing recommendations
class MarketAnalysisCard extends StatefulWidget {
  final Product product;
  final List<CompetitorPrice> competitorPrices;

  const MarketAnalysisCard({
    super.key,
    required this.product,
    required this.competitorPrices,
  });

  @override
  State<MarketAnalysisCard> createState() => _MarketAnalysisCardState();
}

class _MarketAnalysisCardState extends State<MarketAnalysisCard> {
  MarketAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _calculateAnalysis();
  }

  @override
  void didUpdateWidget(MarketAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competitorPrices != widget.competitorPrices ||
        oldWidget.product.salePrice != widget.product.salePrice ||
        oldWidget.product.costPerUnit != widget.product.costPerUnit) {
      _calculateAnalysis();
    }
  }

  void _calculateAnalysis() {
    setState(() {
      _analysis = MarketAnalysisCalculator.analyze(
        competitorPrices: widget.competitorPrices,
        yourPrice: widget.product.salePrice,
        costPerUnit: widget.product.costPerUnit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_analysis == null) {
      return const SizedBox.shrink();
    }

    final analysis = _analysis!;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Analisis Pasaran',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showInfoDialog(),
                  tooltip: 'Maklumat',
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (!analysis.statistics.hasData)
              _buildNoDataState()
            else
              ..._buildAnalysisContent(analysis),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Column(
      children: [
        Icon(
          Icons.trending_up,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        const Text(
          'Tiada data harga pesaing',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tambah harga pesaing untuk analisis pasaran',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showAddCompetitorPriceDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Harga Pesaing'),
        ),
      ],
    );
  }

  List<Widget> _buildAnalysisContent(MarketAnalysis analysis) {
    return [
      // Market Statistics
      _buildStatRow(
        'Harga Purata Pasaran',
        'RM${analysis.statistics.averagePrice.toStringAsFixed(2)}',
        Icons.trending_up,
        Colors.blue,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildStatRow(
              'Terendah',
              'RM${analysis.statistics.minPrice.toStringAsFixed(2)}',
              Icons.arrow_downward,
              Colors.green,
              isSmall: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatRow(
              'Tertinggi',
              'RM${analysis.statistics.maxPrice.toStringAsFixed(2)}',
              Icons.arrow_upward,
              Colors.orange,
              isSmall: true,
            ),
          ),
        ],
      ),
      const Divider(height: 32),

      // Your Price Position
      _buildPricePosition(analysis),
      const SizedBox(height: 20),

      // Profit Margin Comparison
      if (analysis.yourProfitMargin != null) _buildProfitMargin(analysis),
      const SizedBox(height: 20),

      // Competitiveness Score
      _buildCompetitivenessScore(analysis),
      const SizedBox(height: 20),

      // Recommendations
      _buildRecommendations(analysis),
      const SizedBox(height: 20),

      // Actions
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showCompetitorPricesList(),
              icon: const Icon(Icons.list),
              label: const Text('Lihat Semua'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddCompetitorPriceDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isSmall = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isSmall ? 20 : 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmall ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePosition(MarketAnalysis analysis) {
    final position = analysis.position;
    final percentage = analysis.positionPercentage;
    Color color;
    IconData icon;
    String label;

    switch (position) {
      case MarketPosition.belowMarket:
        color = Colors.green;
        icon = Icons.arrow_downward;
        label = 'Di Bawah Pasaran';
        break;
      case MarketPosition.atMarket:
        color = Colors.blue;
        icon = Icons.trending_flat;
        label = 'Dalam Pasaran';
        break;
      case MarketPosition.aboveMarket:
        color = Colors.orange;
        icon = Icons.arrow_upward;
        label = 'Di Atas Pasaran';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Harga Anda: RM${analysis.yourPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$label (${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitMargin(MarketAnalysis analysis) {
    final yourMargin = analysis.yourProfitMargin!;
    final marketMargin = analysis.estimatedMarketProfitMargin ?? 0;

    final isBetter = yourMargin > marketMargin;
    final difference = yourMargin - marketMargin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perbandingan Profit Margin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Margin Anda',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${yourMargin.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Purata Pasaran',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${marketMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isBetter ? Icons.check_circle : Icons.info,
                color: isBetter ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBetter
                      ? 'Margin anda ${difference.toStringAsFixed(1)}% lebih baik daripada pasaran'
                      : 'Margin anda ${(-difference).toStringAsFixed(1)}% lebih rendah daripada pasaran',
                  style: TextStyle(
                    fontSize: 12,
                    color: isBetter ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitivenessScore(MarketAnalysis analysis) {
    final score = analysis.competitivenessScore;
    Color color;
    String label;

    if (score >= 90) {
      color = Colors.green;
      label = 'Sangat Kompetitif';
    } else if (score >= 80) {
      color = Colors.blue;
      label = 'Kompetitif';
    } else if (score >= 70) {
      color = Colors.orange;
      label = 'Sederhana';
    } else {
      color = Colors.red;
      label = 'Tidak Kompetitif';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Skor Daya Saing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          '${score.toStringAsFixed(0)}/100',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(MarketAnalysis analysis) {
    final rec = analysis.recommendation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Cadangan Harga',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecommendationRow('Minimum', rec.minPrice, Colors.green),
          const SizedBox(height: 8),
          _buildRecommendationRow('Optimal', rec.optimalPrice, Colors.blue, isBold: true),
          const SizedBox(height: 8),
          _buildRecommendationRow('Maksimum', rec.maxPrice, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildRecommendationRow(String label, double price, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'RM${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showAddCompetitorPriceDialog() async {
    final result = await showDialog<CompetitorPrice>(
      context: context,
      builder: (context) => CompetitorPriceDialog(
        productId: widget.product.id,
      ),
    );

    if (result != null && mounted) {
      // Return result to parent for handling
      Navigator.of(context, rootNavigator: true).pop(result);
    }
  }

  Future<void> _showCompetitorPricesList() async {
    await showDialog(
      context: context,
      builder: (context) => CompetitorPricesListDialog(
        product: widget.product,
        competitorPrices: widget.competitorPrices,
      ),
    );
  }

  Future<void> _showInfoDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maklumat Analisis Pasaran'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Analisis ini membantu anda:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Bandingkan harga dengan pesaing'),
              Text('• Tentukan kedudukan harga dalam pasaran'),
              Text('• Analisis profit margin vs pasaran'),
              Text('• Dapatkan cadangan harga yang kompetitif'),
              SizedBox(height: 16),
              Text(
                'Kedudukan Pasaran:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('⬇️ Di Bawah: Harga < 90% purata pasaran'),
              Text('➡️ Dalam Pasaran: 90-110% purata pasaran'),
              Text('⬆️ Di Atas: Harga > 110% purata pasaran'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

