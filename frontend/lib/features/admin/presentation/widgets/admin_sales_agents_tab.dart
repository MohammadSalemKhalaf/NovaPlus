import 'package:flutter/material.dart';

import '../../domain/entities/admin_sales_agent_entity.dart';
import '../../domain/entities/admin_sales_agent_overview_entity.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
abstract final class _C {
  // Backgrounds
  static const bg0 = Color(0xFF09090F);
  static const bg1 = Color(0xFF0F0F1A);
  static const bg2 = Color(0xFF141424);
  static const bg3 = Color(0xFF1C1C30);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceHover = Color(0xFF21213A);

  // Brand
  static const accent = Color(0xFF6C63FF);
  static const accentSoft = Color(0xFF8B85FF);
  static const accentGlow = Color(0x336C63FF);
  static const accentDim = Color(0x1A6C63FF);

  // Semantic
  static const green = Color(0xFF22C55E);
  static const greenDim = Color(0x2022C55E);
  static const greenText = Color(0xFF4ADE80);
  static const red = Color(0xFFEF4444);
  static const redDim = Color(0x20EF4444);
  static const redText = Color(0xFFFCA5A5);
  static const amber = Color(0xFFF59E0B);

  // Text
  static const textPrimary = Color(0xFFF1F0FF);
  static const textSecondary = Color(0xFF9B99CC);
  static const textMuted = Color(0xFF5C5A80);
  static const textDisabled = Color(0xFF3A3860);

  // Borders
  static const border = Color(0xFF252540);
  static const borderSubtle = Color(0xFF1C1C35);
  static const borderAccent = Color(0x556C63FF);
}

abstract final class _R {
  static const card = 20.0;
  static const chip = 999.0;
  static const btn = 12.0;
  static const inner = 14.0;
}

// ─────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────
class AdminSalesAgentsTab extends StatefulWidget {
  const AdminSalesAgentsTab({
    super.key,
    required this.agents,
    required this.overviewById,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onCreate,
    required this.onRefresh,
  });

  final List<AdminSalesAgentEntity> agents;
  final Map<int, AdminSalesAgentOverviewEntity> overviewById;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<AdminSalesAgentEntity> onEdit;
  final ValueChanged<AdminSalesAgentEntity> onToggle;
  final ValueChanged<AdminSalesAgentEntity> onDelete;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  State<AdminSalesAgentsTab> createState() => _AdminSalesAgentsTabState();
}

class _AdminSalesAgentsTabState extends State<AdminSalesAgentsTab>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _fabAnim;
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  String _normalize(String text) =>
      text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_searchQuery);
    final filteredAgents = widget.agents
        .where((agent) {
          final matchesStatus = widget.statusFilter.isEmpty ||
              agent.status.trim().toLowerCase() == widget.statusFilter;
          if (!matchesStatus) return false;
          if (query.isEmpty) return true;
          return _normalize(agent.name).contains(query) ||
              _normalize(agent.email).contains(query);
        })
        .toList(growable: false);

    final activeCount =
        widget.agents.where((a) => a.status.trim().toLowerCase() == 'active').length;
    final inactiveCount = widget.agents.length - activeCount;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _C.accentSoft,
      backgroundColor: _C.bg2,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Top Summary Bar ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SummaryRow(
                total: widget.agents.length,
                active: activeCount,
                inactive: inactiveCount,
              ),
            ),
          ),

          // ── Control Panel ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ControlPanel(
                searchController: _searchController,
                statusFilter: widget.statusFilter,
                resultCount: filteredAgents.length,
                isRefreshing: _isRefreshing,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onSearchClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                onStatusFilterChanged: widget.onStatusFilterChanged,
                onRefresh: _handleRefresh,
                onCreate: widget.onCreate,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Agent List or Empty ───────────────────────────────
          if (filteredAgents.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.separated(
                itemCount: filteredAgents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final agent = filteredAgents[index];
                  final overview = widget.overviewById[agent.id];
                  return _AgentCard(
                    agent: agent,
                    overview: overview,
                    onEdit: () => widget.onEdit(agent),
                    onToggle: () => widget.onToggle(agent),
                    onDelete: () => widget.onDelete(agent),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Summary Row
// ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.total,
    required this.active,
    required this.inactive,
  });

  final int total;
  final int active;
  final int inactive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(label: 'Total', value: '$total', color: _C.accentSoft),
        const SizedBox(width: 10),
        _SummaryChip(label: 'Active', value: '$active', color: _C.greenText),
        const SizedBox(width: 10),
        _SummaryChip(label: 'Inactive', value: '$inactive', color: _C.redText),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(_R.chip),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _C.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Control Panel
// ─────────────────────────────────────────────────────────────
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.searchController,
    required this.statusFilter,
    required this.resultCount,
    required this.isRefreshing,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusFilterChanged,
    required this.onRefresh,
    required this.onCreate,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final int resultCount;
  final bool isRefreshing;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(_R.card),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.accentDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  color: _C.accentSoft,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Agents',
                      style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Search, filter and manage agents',
                      style: TextStyle(
                        color: _C.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const _Divider(),
          const SizedBox(height: 16),

          // Search field
          _SearchField(
            controller: searchController,
            onChanged: onSearchChanged,
            onClear: onSearchClear,
          ),

          const SizedBox(height: 12),

          // Filter row
          Row(
            children: [
              Expanded(
                child: _FilterChipRow(
                  selected: statusFilter.isEmpty ? 'all' : statusFilter,
                  onChanged: (v) =>
                      onStatusFilterChanged(v == 'all' ? '' : v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.accentDim,
                  borderRadius: BorderRadius.circular(_R.chip),
                ),
                child: Text(
                  '$resultCount result${resultCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _C.accentSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _IconActionButton(
                icon: isRefreshing
                    ? Icons.hourglass_empty_rounded
                    : Icons.refresh_rounded,
                label: 'Refresh',
                onPressed: onRefresh,
              ),
              const SizedBox(width: 10),
              _PrimaryActionButton(
                label: 'New Agent',
                onPressed: onCreate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Search Field
// ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      cursorColor: _C.accentSoft,
      decoration: InputDecoration(
        hintText: 'Search by name or email…',
        hintStyle:
            const TextStyle(color: _C.textDisabled, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded,
            color: _C.textMuted, size: 20),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded,
                    color: _C.textMuted, size: 18),
                splashRadius: 16,
              ),
        filled: true,
        fillColor: _C.bg3,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_R.inner),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_R.inner),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_R.inner),
          borderSide: const BorderSide(color: _C.accentSoft, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Filter Chip Row  (replaces DropdownButtonFormField)
// ─────────────────────────────────────────────────────────────
class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('all', 'All'),
    ('active', 'Active'),
    ('inactive', 'Inactive'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (value, label) = opt;
        final isSelected = selected == value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _C.accentGlow : _C.bg3,
                borderRadius: BorderRadius.circular(_R.chip),
                border: Border.all(
                  color: isSelected ? _C.accentSoft : _C.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? _C.accentSoft : _C.textSecondary,
                  fontSize: 12.5,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Small action buttons
// ─────────────────────────────────────────────────────────────
class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(_R.btn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _C.bg3,
          borderRadius: BorderRadius.circular(_R.btn),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _C.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _C.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(_R.btn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
          ),
          borderRadius: BorderRadius.circular(_R.btn),
          boxShadow: const [
            BoxShadow(
              color: Color(0x406C63FF),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Agent Card
// ─────────────────────────────────────────────────────────────
class _AgentCard extends StatefulWidget {
  const _AgentCard({
    required this.agent,
    required this.overview,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminSalesAgentEntity agent;
  final AdminSalesAgentOverviewEntity? overview;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverAnim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _hoverAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _hoverAnim.dispose();
    super.dispose();
  }

  bool get _active =>
      widget.agent.status.trim().toLowerCase() == 'active';

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        _hoverAnim.forward();
      },
      onExit: (_) {
        setState(() => _hovering = false);
        _hoverAnim.reverse();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovering ? _C.surfaceHover : _C.surface,
          borderRadius: BorderRadius.circular(_R.card),
          border: Border.all(
            color: _hovering ? _C.borderAccent : _C.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? const Color(0x256C63FF)
                  : const Color(0x10000000),
              blurRadius: _hovering ? 24 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(agent: widget.agent, active: _active),
              const SizedBox(height: 14),
              _StatsRow(overview: widget.overview),
              const SizedBox(height: 16),
              _ActionRow(
                active: _active,
                onEdit: widget.onEdit,
                onToggle: widget.onToggle,
                onDelete: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Card sub-parts
// ─────────────────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.agent, required this.active});

  final AdminSalesAgentEntity agent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x406C63FF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              agent.name.isNotEmpty
                  ? agent.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Name + email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent.name,
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.alternate_email_rounded,
                      size: 11, color: _C.textMuted),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      agent.email,
                      style: const TextStyle(
                        color: _C.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),
        _StatusBadge(active: active, label: agent.status),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.overview});

  final AdminSalesAgentOverviewEntity? overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.bg1,
        borderRadius: BorderRadius.circular(_R.inner),
        border: Border.all(color: _C.borderSubtle),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                icon: Icons.business_center_rounded,
                label: 'Owners',
                value: '${overview?.ownersCount ?? 0}',
                color: _C.accentSoft,
              ),
            ),
            VerticalDivider(
              color: _C.border,
              thickness: 1,
              indent: 2,
              endIndent: 2,
              width: 28,
            ),
            Expanded(
              child: _StatCell(
                icon: Icons.storefront_rounded,
                label: 'Stores',
                value: '${overview?.storesCount ?? 0}',
                color: _C.greenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _C.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.active,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Edit button
        _CardButton(
          icon: Icons.edit_rounded,
          label: 'Edit',
          color: _C.textSecondary,
          bgColor: _C.bg3,
          borderColor: _C.border,
          onPressed: onEdit,
        ),
        const SizedBox(width: 8),

        // Toggle button
        Expanded(
          child: _CardButton(
            icon: active
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            label: active ? 'Deactivate' : 'Activate',
            color: active ? _C.amber : _C.greenText,
            bgColor: active
                ? const Color(0x20F59E0B)
                : const Color(0x1022C55E),
            borderColor:
                active ? const Color(0x40F59E0B) : const Color(0x4022C55E),
            onPressed: onToggle,
          ),
        ),
        const SizedBox(width: 8),

        // Delete button
        _CardIconButton(
          icon: Icons.delete_outline_rounded,
          color: _C.redText,
          bgColor: _C.redDim,
          borderColor: const Color(0x40EF4444),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onPressed,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget child = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(_R.btn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_R.btn),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? child : child;
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(_R.btn),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(_R.btn),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status Badge
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _C.greenDim : _C.redDim,
        borderRadius: BorderRadius.circular(_R.chip),
        border: Border.all(
          color:
              active ? const Color(0x4022C55E) : const Color(0x40EF4444),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? _C.greenText : _C.redText,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Active' : label,
            style: TextStyle(
              color: active ? _C.greenText : _C.redText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.accentDim,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              color: _C.accentSoft,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No agents found',
            style: TextStyle(
              color: _C.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search or status filter.',
            style: TextStyle(color: _C.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Divider helper
// ─────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _C.borderSubtle);
  }
}