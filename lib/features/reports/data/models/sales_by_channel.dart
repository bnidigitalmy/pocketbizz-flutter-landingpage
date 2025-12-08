/// Sales by Channel Model
class SalesByChannel {
  final String channel;
  final String channelLabel;
  final double revenue;
  final double percentage;
  final int transactionCount;

  SalesByChannel({
    required this.channel,
    required this.channelLabel,
    required this.revenue,
    required this.percentage,
    required this.transactionCount,
  });

  factory SalesByChannel.fromJson(Map<String, dynamic> json) {
    return SalesByChannel(
      channel: json['channel'] as String,
      channelLabel: json['channelLabel'] as String? ?? json['channel_label'] as String? ?? json['channel'],
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ??
          (json['transaction_count'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'channelLabel': channelLabel,
        'revenue': revenue,
        'percentage': percentage,
        'transactionCount': transactionCount,
      };
}

