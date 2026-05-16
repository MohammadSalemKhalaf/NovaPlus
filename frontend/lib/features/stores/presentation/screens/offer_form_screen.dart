import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../items/data/datasources/items_remote_data_source.dart';
import '../../../items/data/repositories/items_repository_impl.dart';
import '../../../items/domain/entities/item_entity.dart';
import '../../../items/domain/repositories/items_repository.dart';
import '../../../offers/data/datasources/offers_remote_data_source.dart';
import '../../../offers/data/repositories/offers_repository_impl.dart';
import '../../../offers/domain/entities/offer_entity.dart';
import '../../../offers/domain/repositories/offers_repository.dart';
import '../theme/owner_theme.dart';

class OfferFormScreen extends StatefulWidget {
  const OfferFormScreen({super.key, this.offer});

  final OfferEntity? offer;

  @override
  State<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends State<OfferFormScreen> {
  static const List<String> _statuses = <String>['draft', 'active', 'archived'];
  static const List<String> _discountTypes = <String>['none', 'percentage', 'fixed'];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _discountValueController = TextEditingController();
  final TextEditingController _startsAtController = TextEditingController();
  final TextEditingController _endsAtController = TextEditingController();

  late final OffersRepository _offersRepository;
  late final ItemsRepository _itemsRepository;
  late final Future<List<ItemEntity>> _itemsFuture;

  String _status = 'draft';
  String _discountType = 'none';
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isSubmitting = false;
  final Set<int> _selectedItemIds = <int>{};

  @override
  void initState() {
    super.initState();

    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    _offersRepository = OffersRepositoryImpl(
      remoteDataSource: OffersRemoteDataSource(apiClient: apiClient),
    );
    _itemsRepository = ItemsRepositoryImpl(
      remoteDataSource: ItemsRemoteDataSource(apiClient: apiClient),
    );
    _itemsFuture = _itemsRepository.getItems();

    final offer = widget.offer;
    if (offer != null) {
      _titleController.text = offer.title;
      _descriptionController.text = offer.description ?? '';
      _imageController.text = offer.image ?? '';
      _discountType = offer.discountType?.trim().isNotEmpty == true
          ? offer.discountType!.trim().toLowerCase()
          : 'none';
      _discountValueController.text = offer.discountValue?.toString() ?? '';
      _startsAt = offer.startsAt;
      _endsAt = offer.endsAt;
      _status = _normalizeStatus(offer.status) ?? 'draft';
      _selectedItemIds
        ..clear()
        ..addAll(offer.itemIds);
      _startsAtController.text = _formatDateLabel(_startsAt);
      _endsAtController.text = _formatDateLabel(_endsAt);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _discountValueController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  String? _normalizeStatus(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    for (final status in _statuses) {
      if (status == normalized) {
        return status;
      }
    }

    return null;
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatDateLabel(DateTime? value) {
    if (value == null) {
      return '';
    }

    final local = _dateOnly(value);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _sanitizeText(String value) {
    return value.trim();
  }

  Future<void> _pickStartDate() async {
    final initialDate = _startsAt ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _startsAt = _dateOnly(selected);
      _startsAtController.text = _formatDateLabel(_startsAt);
      if (_endsAt != null && _endsAt!.isBefore(_startsAt!)) {
        _endsAt = null;
        _endsAtController.clear();
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endsAt ?? _startsAt ?? DateTime.now();
    final firstDate = _startsAt ?? DateTime(2020);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endsAt = _dateOnly(selected);
      _endsAtController.text = _formatDateLabel(_endsAt);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_status.isEmpty) {
      _showSnackBar('Status is required');
      return;
    }

    if (_discountType != 'none' && _discountValueController.text.trim().isEmpty) {
      _showSnackBar('Discount value is required when a discount type is selected');
      return;
    }

    final discountValueText = _discountValueController.text.trim();
    num? discountValue;
    if (_discountType != 'none') {
      discountValue = num.tryParse(discountValueText);
      if (discountValue == null || discountValue < 0) {
        _showSnackBar('Discount value must be a valid non-negative number');
        return;
      }
    }

    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      _showSnackBar('End date must be after or equal to start date');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final title = _titleController.text.trim();
      final description = _sanitizeText(_descriptionController.text);
      final image = _sanitizeText(_imageController.text);
      final startsAt = _startsAt == null ? null : _formatDateLabel(_startsAt);
      final endsAt = _endsAt == null ? null : _formatDateLabel(_endsAt);
      final offer = widget.offer;

      if (offer == null) {
        await _offersRepository.createOffer(
          title: title,
          description: description,
          image: image,
          discountType: _discountType == 'none' ? null : _discountType,
          discountValue: _discountType == 'none' ? null : discountValue,
          startsAt: startsAt,
          endsAt: endsAt,
          status: _status,
          itemIds: _selectedItemIds.toList(growable: false),
        );
      } else {
        await _offersRepository.updateOffer(
          id: offer.id,
          title: title,
          description: description,
          image: image,
          discountType: _discountType == 'none' ? null : _discountType,
          discountValue: _discountType == 'none' ? null : discountValue,
          startsAt: startsAt,
          endsAt: endsAt,
          status: _status,
          itemIds: _selectedItemIds.toList(growable: false),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop<bool>(context, true);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map
          ? (responseData['message']?.toString() ?? error.message ?? 'Operation failed')
          : (error.message ?? 'Operation failed');
      _showSnackBar(message);
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final previewImageUrl = ImageHelper.build(_imageController.text);
    final palette = OwnerTheme.palette(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.onSurface,
        title: Text(offer == null ? 'Create Offer' : 'Edit Offer'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer details',
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create discounts and promotions for your store.',
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                if (previewImageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        previewImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: palette.surfaceAlt,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.local_offer_outlined,
                            color: palette.primary,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildFieldCard(
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'Summer Sale',
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Short description for the offer',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _imageController,
                      label: 'Image URL or storage path',
                      hint: 'https://... or /storage/...',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _discountType,
                      items: _discountTypes
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value == 'none' ? 'No discount' : value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _discountType = value;
                          if (value == 'none') {
                            _discountValueController.clear();
                          }
                        });
                      },
                      decoration: _inputDecoration('Discount type'),
                      dropdownColor: palette.surfaceAlt,
                      style: TextStyle(color: palette.onSurface),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _discountValueController,
                      label: 'Discount value',
                      hint: '10',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (_discountType == 'none') {
                          return null;
                        }
                        if ((value ?? '').trim().isEmpty) {
                          return 'Discount value is required';
                        }
                        final parsed = num.tryParse(value!.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid non-negative number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            controller: _startsAtController,
                            label: 'Starts at',
                            hint: 'Pick start date',
                            onTap: _pickStartDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateField(
                            controller: _endsAtController,
                            label: 'Ends at',
                            hint: 'Pick end date',
                            onTap: _pickEndDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _status,
                      items: _statuses
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _status = value;
                        });
                      },
                      decoration: _inputDecoration('Status'),
                      dropdownColor: palette.surfaceAlt,
                      style: TextStyle(color: palette.onSurface),
                    ),
                    const SizedBox(height: 12),
                    _itemSelector(),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(offer == null ? 'Create Offer' : 'Update Offer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({required List<Widget> children}) {
    final palette = OwnerTheme.palette(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final palette = OwnerTheme.palette(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.onSurfaceMuted),
      filled: true,
      fillColor: palette.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.primary),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    final palette = OwnerTheme.palette(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: palette.onSurface),
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: palette.onSurfaceSoft),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
  }) {
    final palette = OwnerTheme.palette(context);
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(color: palette.onSurface),
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: palette.onSurfaceSoft),
        suffixIcon: Icon(Icons.calendar_month_rounded, color: palette.onSurfaceMuted),
      ),
    );
  }

  Widget _itemSelector() {
    final palette = OwnerTheme.palette(context);
    return FutureBuilder<List<ItemEntity>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading items...',
                  style: TextStyle(color: palette.onSurfaceMuted, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Items list is not available right now.',
            style: TextStyle(color: palette.warning, fontSize: 12),
          );
        }

        final items = snapshot.data ?? const <ItemEntity>[];
        if (items.isEmpty) {
          return Text(
            'No items available to select.',
            style: TextStyle(color: palette.onSurfaceMuted, fontSize: 12),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Select items for this offer',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final checked = _selectedItemIds.contains(item.id);
                  return CheckboxListTile(
                    value: checked,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: palette.primary,
                    title: Text(
                      item.name,
                      style: TextStyle(color: palette.onSurface, fontSize: 13),
                    ),
                    subtitle: Text(
                      item.status,
                      style: TextStyle(color: palette.onSurfaceMuted, fontSize: 11),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedItemIds.add(item.id);
                        } else {
                          _selectedItemIds.remove(item.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}