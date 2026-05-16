import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/admin_dashboard_data_entity.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key, required this.data});

  final AdminDashboardDataEntity data;

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  String _range = 'Week';

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  List<int> get _stores => _range == 'Week'
      ? widget.data.weeklyStoresActivity
      : widget.data.monthlyStoresActivity;

  List<int> get _owners => _range == 'Week'
      ? widget.data.weeklyOwnersActivity
      : widget.data.monthlyOwnersActivity;

  double get _growth {
    final week = widget.data.weeklyStoresActivity.fold<int>(0, (sum, item) => sum + item);
    final month = widget.data.monthlyStoresActivity.fold<int>(0, (sum, item) => sum + item);
    if (month == 0) {
      return 0;
    }
    final baseline = month / 4;
    if (baseline == 0) {
      return 0;
    }
    return ((week - baseline) / baseline) * 100;
  }

  List<_AllocationEntry> get _allocation {
    final source = widget.data.businessTypeDistribution.toList(growable: false);
    if (source.isEmpty) {
      return const <_AllocationEntry>[];
    }

    final colors = <Color>[
      const Color(0xFF5C8DFF),
      const Color(0xFF66E2B8),
      const Color(0xFFA56BFF),
      const Color(0xFFFFB454),
      const Color(0xFF4DD0E1),
      const Color(0xFFFF7D9C),
      const Color(0xFF8BC34A),
      const Color(0xFF7E57C2),
    ];

    final total = source.fold<int>(0, (sum, item) => sum + item.count);
    return List<_AllocationEntry>.generate(source.length, (index) {
      final item = source[index];
      final percent = total == 0 ? 0 : ((item.count / total) * 100).round();
      return _AllocationEntry(
        label: item.name,
        count: item.count,
        percent: percent,
        color: colors[index % colors.length],
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final allocation = _allocation;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Total Revenue',
                    style: TextStyle(
                      color: Color(0xFFB4B6D5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _GrowthTag(value: _growth),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatMoney(widget.data.revenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(
                    child: _ActionButton(
                      label: 'View Reports',
                      icon: Icons.insights_rounded,
                      primary: true,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Manage Stores',
                      icon: Icons.storefront_outlined,
                      primary: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                title: 'Stores',
                value: _formatCount(widget.data.totalStores),
                accent: const Color(0xFF6D7DFF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                title: 'Owners',
                value: _formatCount(widget.data.totalOwners),
                accent: const Color(0xFF56D4B0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                title: 'Subscriptions',
                value: _formatCount(widget.data.activeSubscriptions),
                accent: const Color(0xFFFFB454),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Platform Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7B8DFF),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Stores vs Owners Activity',
                style: TextStyle(color: Color(0xFFA3A6CC), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatCount(_stores.fold<int>(0, (sum, item) => sum + item))} events',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  _LegendItem(color: Color(0xFF6D7DFF), label: 'Stores'),
                  SizedBox(width: 14),
                  _LegendItem(color: Color(0xFF56D4B0), label: 'Owners'),
                ],
              ),
              const SizedBox(height: 10),
              _PeriodToggle(
                value: _range,
                onChanged: (value) {
                  setState(() => _range = value);
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 138,
                child: _BarsChart(
                  stores: _stores,
                  owners: _owners,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Business Type Distribution',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Real-time',
                    style: TextStyle(color: Color(0xFF7F83B4), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (allocation.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No business type data available',
                      style: TextStyle(color: Color(0xFFA3A6CC)),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 340;
                    final donut = SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(150, 150),
                            painter: _DonutPainter(entries: allocation),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: Color(0xFF9CA0C7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatCount(
                                  widget.data.businessTypeDistribution.fold<int>(
                                    0,
                                    (sum, item) => sum + item.count,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Stores',
                                style: TextStyle(
                                  color: Color(0xFF9CA0C7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    final list = Column(
                      children: allocation
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AllocationTile(entry: entry),
                            ),
                          )
                          .toList(growable: false),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          donut,
                          const SizedBox(height: 14),
                          list,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        donut,
                        const SizedBox(width: 14),
                        Expanded(child: list),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161A3A), Color(0xFF10132B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2E58), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GrowthTag extends StatelessWidget {
  const _GrowthTag({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive ? const Color(0xFF36D091) : const Color(0xFFFF5A6D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : ''}${value.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
  });

  final String label;
  final IconData icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: primary
            ? const LinearGradient(
                colors: [Color(0xFF4A74FF), Color(0xFF6A79FF)],
              )
            : null,
        color: primary ? null : const Color(0xFF24284B),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget buildPill(String item) {
      final selected = item == value;
      return GestureDetector(
        onTap: () => onChanged(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B3F66) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            item,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF8A8FB8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF23274A),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildPill('Week'),
            buildPill('Month'),
          ],
        ),
      ),
    );
  }
}

class _BarsChart extends StatelessWidget {
  const _BarsChart({required this.stores, required this.owners});

  final List<int> stores;
  final List<int> owners;

  @override
  Widget build(BuildContext context) {
    final count = min(stores.length, owners.length);
    if (count == 0) {
      return const Center(
        child: Text(
          'No chart data',
          style: TextStyle(color: Color(0xFF8E93BD)),
        ),
      );
    }

    final merged = <int>[];
    merged.addAll(stores);
    merged.addAll(owners);
    final maxValue = max(1, merged.fold<int>(0, (prev, item) => max(prev, item)));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (index) {
        final storeRatio = stores[index] / maxValue;
        final ownerRatio = owners[index] / maxValue;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 6,
                  height: 16 + (62 * storeRatio),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D7DFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 16 + (62 * ownerRatio),
                  decoration: BoxDecoration(
                    color: const Color(0xFF56D4B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              labels[index % labels.length],
              style: const TextStyle(
                color: Color(0xFF8A8FB8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _AllocationEntry {
  const _AllocationEntry({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  final String label;
  final int count;
  final int percent;
  final Color color;
}

class _AllocationTile extends StatelessWidget {
  const _AllocationTile({required this.entry});

  final _AllocationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: entry.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC6C9E8),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          '${entry.percent}% • ${entry.count}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.entries});

  final List<_AllocationEntry> entries;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = min(size.width, size.height) / 2;
    const stroke = 12.0;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF262A4E)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - (stroke / 2), basePaint);

    final total = entries.fold<int>(0, (sum, item) => sum + item.percent);
    if (total <= 0) {
      return;
    }

    var start = -pi / 2;
    for (final entry in entries) {
      final sweep = (entry.percent / total) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = entry.color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (stroke / 2)),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep + 0.018;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161A3A), Color(0xFF10132B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2E58), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFB1B5D7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9EA3CB),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
