import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import 'shimmer_widget.dart';

/// Skeleton loader for Hero Section
class HeroSectionSkeleton extends StatelessWidget {
  const HeroSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Header skeleton
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonBox(width: 140, height: 20),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 180, height: 24),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 120, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SkeletonCircle(size: 40),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Metrics skeleton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildMetricSkeleton()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricSkeleton()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMetricSkeleton()),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick actions skeleton
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: _buildActionSkeleton()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionSkeleton()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionSkeleton()),
                  const SizedBox(width: 10),
                  const SkeletonBox(width: 44, height: 44, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSkeleton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 28, height: 28, borderRadius: 8),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          const SkeletonBox(width: 50, height: 12),
          const SizedBox(height: 6),
          const SkeletonBox(width: 70, height: 20),
        ],
      ),
    );
  }

  Widget _buildActionSkeleton() {
    return const SkeletonBox(height: 44, borderRadius: 12);
  }
}

/// Skeleton loader for Alert Bar
class AlertBarSkeleton extends StatelessWidget {
  const AlertBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 36, height: 36, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 14),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SkeletonBox(width: 32, height: 24, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for Tab Content (Ringkasan)
class TabRingkasanSkeleton extends StatelessWidget {
  const TabRingkasanSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Column(
        children: [
          // Weekly cashflow skeleton
          _buildCardSkeleton(
            height: 200,
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 100, height: 18),
                ],
              ),
              const SizedBox(height: 20),
              _buildCashflowRowSkeleton(),
              const SizedBox(height: 12),
              _buildCashflowRowSkeleton(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonBox(width: 50, height: 16),
                  const SkeletonBox(width: 100, height: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Top products skeleton
          _buildCardSkeleton(
            height: 220,
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 160, height: 18),
                ],
              ),
              const SizedBox(height: 16),
              _buildProductRowSkeleton(),
              _buildProductRowSkeleton(),
              _buildProductRowSkeleton(),
              const SizedBox(height: 12),
              Center(child: SkeletonBox(width: 150, height: 36, borderRadius: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton({required double height, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCashflowRowSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SkeletonBox(width: 60, height: 14),
            const SkeletonBox(width: 80, height: 14),
          ],
        ),
        const SizedBox(height: 6),
        SkeletonBox(height: 8, borderRadius: 4),
      ],
    );
  }

  Widget _buildProductRowSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SkeletonCircle(size: 28),
          const SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 16, borderRadius: 4)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 50, height: 12, borderRadius: 4),
              const SizedBox(height: 4),
              SkeletonBox(width: 70, height: 14, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for Tab Content (Jualan)
class TabJualanSkeleton extends StatelessWidget {
  const TabJualanSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Column(
        children: [
          // Sales by channel skeleton
          _buildCardSkeleton(
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const Expanded(child: SkeletonBox(height: 18)),
                  const SkeletonBox(width: 60, height: 14),
                ],
              ),
              const SizedBox(height: 16),
              _buildChannelRowSkeleton(),
              _buildChannelRowSkeleton(),
              _buildChannelRowSkeleton(),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonBox(width: 60, height: 16),
                  const SkeletonBox(width: 100, height: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Upcoming bookings skeleton
          _buildCardSkeleton(
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 160, height: 18),
                ],
              ),
              const SizedBox(height: 16),
              _buildBookingRowSkeleton(),
              const SizedBox(height: 10),
              _buildBookingRowSkeleton(),
              const SizedBox(height: 10),
              _buildBookingRowSkeleton(),
              const SizedBox(height: 12),
              Center(child: SkeletonBox(width: 160, height: 36, borderRadius: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildChannelRowSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              const SkeletonCircle(size: 8),
              const SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 14, borderRadius: 4)),
              const SkeletonBox(width: 40, height: 14),
              const SizedBox(width: 12),
              const SkeletonBox(width: 70, height: 14),
            ],
          ),
          const SizedBox(height: 6),
          SkeletonBox(height: 6, borderRadius: 3),
        ],
      ),
    );
  }

  Widget _buildBookingRowSkeleton() {
    return Row(
      children: [
        SkeletonBox(width: 4, height: 28, borderRadius: 2),
        const SizedBox(width: 12),
        Expanded(child: SkeletonBox(height: 16, borderRadius: 4)),
        const SkeletonBox(width: 80, height: 24, borderRadius: 8),
        const SizedBox(width: 12),
        const SkeletonBox(width: 70, height: 14),
      ],
    );
  }
}

/// Skeleton loader for Tab Content (Stok)
class TabStokSkeleton extends StatelessWidget {
  const TabStokSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Column(
        children: [
          // Stock status skeleton
          _buildCardSkeleton(
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 100, height: 18),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatusRowSkeleton(),
              const SizedBox(height: 10),
              _buildStatusRowSkeleton(),
              const SizedBox(height: 10),
              _buildStatusRowSkeleton(),
            ],
          ),
          const SizedBox(height: 16),
          // Purchase suggestions skeleton
          _buildCardSkeleton(
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  const SizedBox(width: 12),
                  const SkeletonBox(width: 120, height: 18),
                ],
              ),
              const SizedBox(height: 16),
              _buildSuggestionRowSkeleton(),
              _buildSuggestionRowSkeleton(),
              _buildSuggestionRowSkeleton(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 44, borderRadius: 8)),
                  const SizedBox(width: 10),
                  Expanded(child: SkeletonBox(height: 44, borderRadius: 8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStatusRowSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 20),
          const SizedBox(width: 10),
          Expanded(child: SkeletonBox(height: 16, borderRadius: 4)),
          const SkeletonBox(width: 70, height: 24, borderRadius: 12),
        ],
      ),
    );
  }

  Widget _buildSuggestionRowSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SkeletonBox(width: 20, height: 20, borderRadius: 4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, borderRadius: 4),
                const SizedBox(height: 4),
                SkeletonBox(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonBox(width: 50, height: 20, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Skeleton loader for Tab Content (Insight)
class TabInsightSkeleton extends StatelessWidget {
  const TabInsightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 36, height: 36, borderRadius: 8),
                const SizedBox(width: 12),
                const SkeletonBox(width: 140, height: 18),
                const Spacer(),
                SkeletonBox(width: 60, height: 14, borderRadius: 4),
              ],
            ),
          ),
          // Insight cards
          _buildInsightCardSkeleton(),
          _buildInsightCardSkeleton(),
          _buildInsightCardSkeleton(),
        ],
      ),
    );
  }

  Widget _buildInsightCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 36, height: 36, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 18, borderRadius: 4)),
              const SkeletonCircle(size: 18),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonBox(height: 14, borderRadius: 4),
          const SizedBox(height: 6),
          SkeletonBox(width: 200, height: 14, borderRadius: 4),
          const SizedBox(height: 14),
          SkeletonBox(height: 44, borderRadius: 10),
        ],
      ),
    );
  }
}
