import 'package:flutter/material.dart';

import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../items/presentation/screens/create_item_screen.dart';
import '../../controllers/owner_add_controller.dart';
import '../../theme/owner_theme.dart';

class OwnerAddTab extends StatefulWidget {
  const OwnerAddTab({
    super.key,
    required this.controller,
    required this.onItemCreated,
    required this.onUnauthorized,
  });

  final OwnerAddController controller;
  final VoidCallback onItemCreated;
  final VoidCallback onUnauthorized;

  @override
  State<OwnerAddTab> createState() => _OwnerAddTabState();
}

class _OwnerAddTabState extends State<OwnerAddTab> {
  final TextEditingController _categoryNameController = TextEditingController();
  String _categoryStatus = 'active';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant OwnerAddTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _categoryNameController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    if (widget.controller.isUnauthorized) {
      widget.controller.clearUnauthorized();
      widget.onUnauthorized();
      return;
    }

    final message = widget.controller.errorMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      widget.controller.clearError();
    }
  }

  Future<void> _submitCategory() async {
    final success = await widget.controller.createCategory(
      name: _categoryNameController.text,
      status: _categoryStatus,
    );

    if (!success || !mounted) {
      return;
    }

    _categoryNameController.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Category created successfully')),
      );
  }

  Future<void> _openCreateItemFlow() async {
    final currentTheme = Theme.of(context);
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => Theme(
          data: currentTheme,
          child: const CreateItemScreen(),
        ),
      ),
    );

    if (created == true && mounted) {
      widget.onItemCreated();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Item created successfully')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            Text(
              'Add',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      title: 'Add Category',
                      selected: controller.section == OwnerAddSection.category,
                      onTap: () => controller.setSection(OwnerAddSection.category),
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      title: 'Add Item',
                      selected: controller.section == OwnerAddSection.item,
                      onTap: () => controller.setSection(OwnerAddSection.item),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (controller.section == OwnerAddSection.category)
              _CategorySection(
                isLoading: controller.isLoading,
                isSubmitting: controller.isSubmittingCategory,
                categories: controller.categories,
                nameController: _categoryNameController,
                status: _categoryStatus,
                onStatusChanged: (value) => setState(() => _categoryStatus = value),
                onSubmit: _submitCategory,
                onReload: controller.load,
              )
            else
              _ItemSection(
                categories: controller.categories,
                onOpenCreateItem: _openCreateItemFlow,
              ),
          ],
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : palette.onSurfaceMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.isLoading,
    required this.isSubmitting,
    required this.categories,
    required this.nameController,
    required this.status,
    required this.onStatusChanged,
    required this.onSubmit,
    required this.onReload,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<CategoryEntity> categories;
  final TextEditingController nameController;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSubmit;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Category',
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: TextStyle(color: palette.onSurface),
                decoration: InputDecoration(
                  hintText: 'Category name',
                  hintStyle: TextStyle(color: palette.onSurfaceMuted),
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('active')),
                  DropdownMenuItem(value: 'archived', child: Text('archived')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                ),
                dropdownColor: palette.surface,
                style: TextStyle(color: palette.onSurface),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Category'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Existing Categories',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onReload,
              icon: Icon(Icons.refresh_rounded, color: palette.onSurfaceMuted),
            ),
          ],
        ),
        if (isLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: palette.primary),
          )
        else if (categories.isEmpty)
          const _SimpleStateCard(message: 'No categories yet')
        else
          ...categories.map(
            (category) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: TextStyle(
                            color: palette.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.slug,
                          style: TextStyle(
                            color: palette.onSurfaceMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: category.status == 'active'
                          ? palette.successSoft
                          : palette.errorSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.status,
                      style: TextStyle(
                        color: category.status == 'active'
                            ? palette.success
                            : palette.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemSection extends StatelessWidget {
  const _ItemSection({
    required this.categories,
    required this.onOpenCreateItem,
  });

  final List<CategoryEntity> categories;
  final VoidCallback onOpenCreateItem;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Item',
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the existing multi-step flow to create item, upload image, and set active price.',
                style: TextStyle(
                  color: palette.onSurfaceMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenCreateItem,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Open Add Item Flow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Available Categories',
          style: TextStyle(
            color: palette.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const _SimpleStateCard(message: 'No categories available')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: palette.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _SimpleStateCard extends StatelessWidget {
  const _SimpleStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: palette.onSurfaceMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}
