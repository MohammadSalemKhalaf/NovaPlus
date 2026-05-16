import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../categories/data/datasources/categories_remote_data_source.dart';
import '../../../categories/data/repositories/categories_repository_impl.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../offers/data/datasources/offers_remote_data_source.dart';
import '../../../offers/data/repositories/offers_repository_impl.dart';
import '../../../offers/domain/entities/offer_entity.dart';
import '../../../offers/domain/repositories/offers_repository.dart';
import '../../../stores/presentation/theme/owner_theme.dart';
import '../../data/datasources/items_remote_data_source.dart';
import '../../data/repositories/items_repository_impl.dart';
import '../../domain/entities/create_item_input_entity.dart';
import '../../domain/entities/create_item_result_entity.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/entities/set_active_price_input_entity.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/entities/upload_item_image_input_entity.dart';

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({
    super.key,
    this.item,
    this.isEdit = false,
    this.initialCategoryId,
    this.editItemId,
    this.editItemData,
  });

  final ItemEntity? item;
  final bool isEdit;
  final int? initialCategoryId;
  final int? editItemId;
  final ItemEntity? editItemData;

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  static const List<String> _itemTypes = <String>['product', 'service'];
  static const List<String> _statuses = <String>['draft', 'active', 'archived'];
  static const List<String> _visibilities = <String>['public', 'hidden'];

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _shortDescriptionController = TextEditingController();
  final TextEditingController _longDescriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController();

  late final ItemsRepository _itemsRepository;
  late final OffersRepository _offersRepository;
  late final CategoriesRepository _categoriesRepository;
  late final Future<List<CategoryEntity>> _categoriesFuture;
  late final Future<List<OfferEntity>> _offersFuture;

  String? _itemType;
  String? _status;
  String? _visibility;
  int? _selectedCategoryId;
  final Set<int> _selectedOfferIds = <int>{};

  bool _isSubmitting = false;
  bool _slugTouchedByUser = false;
  XFile? _selectedImage;
  String? _existingImagePath;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);

    final itemsRemoteDataSource = ItemsRemoteDataSource(apiClient: apiClient);
    _itemsRepository = ItemsRepositoryImpl(remoteDataSource: itemsRemoteDataSource);
    _offersRepository = OffersRepositoryImpl(
      remoteDataSource: OffersRemoteDataSource(apiClient: apiClient),
    );

    final categoriesRemoteDataSource = CategoriesRemoteDataSource(apiClient: apiClient);
    _categoriesRepository = CategoriesRepositoryImpl(remoteDataSource: categoriesRemoteDataSource);
    _categoriesFuture = _categoriesRepository.getCategories();
    _offersFuture = _offersRepository.getOffers(perPage: 100);

    _selectedCategoryId = widget.initialCategoryId;

    final isEditing = widget.isEdit || widget.editItemId != null || widget.item != null || widget.editItemData != null;
    final sourceItem = widget.item ?? widget.editItemData;

    // If editing, pre-fill the form
    if (isEditing && sourceItem != null) {
      final item = sourceItem;
      _nameController.text = item.name;
      _slugController.text = item.slug.trim().isNotEmpty ? item.slug : _slugify(item.name);
      _shortDescriptionController.text = item.shortDescription ?? '';
      _longDescriptionController.text = item.longDescription ?? '';
      final inferredType = item.name.toLowerCase().contains('service')
          ? 'service'
          : 'product';
      _itemType = _normalizeStringDropdownValue(inferredType, _itemTypes) ?? _itemTypes.first;
      _status = _normalizeStringDropdownValue(item.status, _statuses) ?? _statuses.first;
      _visibility = _visibilities.first;
      final firstPrice = item.prices.isNotEmpty ? item.prices.first.basePriceAmount : null;
      final directPrice = item.price?.toString();
      _priceController.text = (directPrice != null && directPrice.isNotEmpty)
          ? directPrice
          : ((firstPrice != null && firstPrice.isNotEmpty) ? firstPrice : '');
      _selectedCategoryId = item.categoryId;
      _selectedOfferIds
        ..clear()
        ..addAll(item.offerIds);
      _existingImagePath = _resolveExistingImagePath(item);
      _slugTouchedByUser = true; // Don't auto-generate slug when editing
    }

    _nameController.addListener(_syncSlugFromName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncSlugFromName);
    _nameController.dispose();
    _slugController.dispose();
    _shortDescriptionController.dispose();
    _longDescriptionController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _syncSlugFromName() {
    if (_slugTouchedByUser) {
      return;
    }

    final generated = _slugify(_nameController.text);
    _slugController.value = TextEditingValue(
      text: generated,
      selection: TextSelection.collapsed(offset: generated.length),
    );
  }

  String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return normalized;
  }

  String? _normalizeStringDropdownValue(String? value, List<String> allowedValues) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final allowed in allowedValues) {
      if (allowed.toLowerCase() == normalized) {
        return allowed;
      }
    }

    return null;
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    if (_itemType == null || _status == null || _visibility == null) {
      _showSnackBar('Please fill all required fields');
      return;
    }

    final sortOrder = int.tryParse(_sortOrderController.text.trim());
    if (sortOrder == null || sortOrder < 0) {
      _showSnackBar('sort_order must be an integer greater than or equal to 0');
      return;
    }

    final rawPrice = _priceController.text.trim();
    if (rawPrice.isEmpty) {
      _showSnackBar('base_price_amount is required');
      return;
    }

    final parsedPrice = double.tryParse(rawPrice);
    if (parsedPrice == null || parsedPrice < 0) {
      _showSnackBar('base_price_amount must be a valid non-negative number');
      return;
    }
    final normalizedPrice = parsedPrice.toStringAsFixed(2);
    final isEditMode = widget.isEdit || widget.editItemId != null;
    final editId = widget.editItemId ?? widget.item?.id ?? widget.editItemData?.id;

    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // If editing, update the item
      if (isEditMode) {
        if (editId == null) {
          throw Exception('Missing item id for edit mode');
        }

        await _itemsRepository.updateItem(
          id: editId,
          categoryId: _selectedCategoryId,
          name: _nameController.text.trim(),
          shortDescription: _shortDescriptionController.text.trim().isEmpty
              ? null
              : _shortDescriptionController.text.trim(),
          longDescription: _longDescriptionController.text.trim().isEmpty
              ? null
              : _longDescriptionController.text.trim(),
          itemType: _itemType!,
          status: _status!,
          visibility: _visibility!,
          sortOrder: sortOrder,
          offerIds: _selectedOfferIds.toList(growable: false),
        );

        final selectedImage = _selectedImage;
        if (selectedImage != null) {
          await _uploadAndAttachPrimaryImage(editId, selectedImage.path);
        }

        if (!mounted) {
          return;
        }

        Navigator.pop<bool>(context, true);
        return;
      }

      // Create new item
      final requestedSlug = _slugController.text.trim();

      final existingItems = await _itemsRepository.getItems();
      final duplicateExists = existingItems.any(
        (item) =>
            item.slug.trim().toLowerCase() == requestedSlug.toLowerCase() &&
            item.status.trim().toLowerCase() == 'active',
      );

      if (duplicateExists) {
        _showSnackBar('Item already exists');
        return;
      }

      Future<CreateItemResultEntity> createItemWithSlug(String slug) {
        return _itemsRepository.createItem(
          CreateItemInputEntity(
            categoryId: _selectedCategoryId,
            name: _nameController.text.trim(),
            slug: slug,
            shortDescription: _shortDescriptionController.text.trim().isEmpty
                ? null
                : _shortDescriptionController.text.trim(),
            longDescription: _longDescriptionController.text.trim().isEmpty
                ? null
                : _longDescriptionController.text.trim(),
            itemType: _itemType!,
            status: _status!,
            visibility: _visibility!,
            primaryImageId: null,
            sortOrder: sortOrder,
          ),
        );
      }

      final result = await createItemWithSlug(requestedSlug);

      final createdItemId = result.itemId;
      if (createdItemId == null) {
        throw Exception('Item created but response did not include item id');
      }
      debugPrint('ITEM ID: $createdItemId');

      final selectedImage = _selectedImage;
      if (selectedImage != null) {
        await _uploadAndAttachPrimaryImage(createdItemId, selectedImage.path);
      }

      if (_selectedOfferIds.isNotEmpty) {
        await _itemsRepository.updateItem(
          id: createdItemId,
          offerIds: _selectedOfferIds.toList(growable: false),
        );
      }

      try {
        debugPrint('SETTING PRICE...');
        await _itemsRepository.setActivePrice(
          SetActivePriceInputEntity(
            itemId: createdItemId,
            currencyCode: 'USD',
            basePriceAmount: normalizedPrice,
            compareAtPriceAmount: null,
            effectiveFrom: _formatDateTimeForApi(DateTime.now()),
            effectiveTo: null,
          ),
        );
      } catch (error) {
        debugPrint('Set active price failed: $error');
        _showSnackBar('Failed to set item price');
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.pop<bool>(context, true);
    } on DioException catch (e) {
      debugPrint('Submit error (dio): ${e.message}');
      debugPrint('Submit error response: ${e.response?.data}');
      debugPrint('Submit error status: ${e.response?.statusCode}');
      if (!mounted) return;
      final responseData = e.response?.data;
      final message = responseData is Map
          ? (responseData['message'] as String? ?? 'Operation failed')
          : (e.message ?? 'Operation failed');
      _showSnackBar(message);
    } catch (error, stackTrace) {
      debugPrint('UPDATE ERROR: $error');
      debugPrint('UPDATE STACK: $stackTrace');
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

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
    });
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _uploadAndAttachPrimaryImage(int itemId, String imagePath) async {
    try {
      final uploaded = await _itemsRepository.uploadItemImage(
        UploadItemImageInputEntity(
          itemId: itemId,
          imagePath: imagePath,
        ),
      );

      final imageId = uploaded.imageId;
      if (imageId == null) {
        debugPrint('Image uploaded but imageId missing; skipping primary attach');
        return;
      }

      await _itemsRepository.updateItem(
        id: itemId,
        primaryImageId: imageId,
      );
      _existingImagePath = uploaded.storagePath ?? _existingImagePath;
      _selectedImage = null;
    } catch (error) {
      debugPrint('Upload/attach image failed: $error');
      _showSnackBar('Failed to upload image');
    }
  }

  String? _resolveExistingImagePath(ItemEntity item) {
    final directImage = (item.image ?? '').trim();
    if (directImage.isNotEmpty) {
      return directImage;
    }

    final primaryImage = (item.primaryImage?.url ?? '').trim();
    if (primaryImage.isNotEmpty) {
      return primaryImage;
    }

    if (item.images.isNotEmpty) {
      final fallback = item.images.first.storagePath.trim();
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEdit || widget.editItemId != null;
    final palette = OwnerTheme.palette(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        elevation: 0,
        title: Text(isEditing ? 'Edit Item' : 'Create Item'),
      ),
      body: FutureBuilder<List<CategoryEntity>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          final hasCategoryError = snapshot.hasError;
          final categories = snapshot.data ?? const <CategoryEntity>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeroCard(
                    palette: palette,
                    isEditing: isEditing,
                    categoryCount: categories.length,
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    palette: palette,
                    title: 'Required Fields',
                    subtitle: 'The core details that define this item.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _textField(
                          controller: _nameController,
                          label: 'name',
                          icon: Icons.sell_rounded,
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'name is required';
                            if (text.length > 255) return 'name max length is 255';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _slugController,
                          label: 'slug',
                          icon: Icons.link_rounded,
                          readOnly: isEditing,
                          onChanged: (_) {
                            _slugTouchedByUser = true;
                          },
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'slug is required';
                            if (text.length > 255) return 'slug max length is 255';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _dropdown<String>(
                          label: 'item_type',
                          value: _itemType,
                          items: _itemTypes,
                          itemLabel: (value) => value,
                          icon: Icons.category_outlined,
                          onChanged: (value) => setState(() => _itemType = value),
                        ),
                        const SizedBox(height: 12),
                        _statusToggle(),
                        const SizedBox(height: 12),
                        _dropdown<String>(
                          label: 'visibility',
                          value: _visibility,
                          items: _visibilities,
                          itemLabel: (value) => value,
                          icon: Icons.visibility_outlined,
                          onChanged: (value) => setState(() => _visibility = value),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _sortOrderController,
                          label: 'sort_order',
                          icon: Icons.sort_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'sort_order is required';
                            final parsed = int.tryParse(text);
                            if (parsed == null || parsed < 0) {
                              return 'sort_order must be integer >= 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _priceController,
                          label: 'base_price_amount',
                          icon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'base_price_amount is required';
                            final parsed = double.tryParse(text);
                            if (parsed == null || parsed < 0) {
                              return 'base_price_amount must be a valid non-negative number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    palette: palette,
                    title: 'Optional Fields',
                    subtitle: 'Add details, categories, offers, and media.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasCategoryError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Failed to load categories. You can keep category_id empty.',
                              style: TextStyle(color: palette.warning),
                            ),
                          ),
                        _categoryDropdown(categories),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _shortDescriptionController,
                          label: 'short_description',
                          icon: Icons.short_text_rounded,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _longDescriptionController,
                          label: 'long_description',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        _offerSelector(),
                        const SizedBox(height: 12),
                        _imageUploadSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionFooter(
                    palette: palette,
                    isSubmitting: _isSubmitting,
                    label: isEditing ? 'Update Item' : 'Create Item',
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _offerSelector() {
    final palette = OwnerTheme.palette(context);
    return FutureBuilder<List<OfferEntity>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const <OfferEntity>[];
        final hasError = snapshot.hasError;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading offers...',
                  style: TextStyle(color: palette.onSurfaceMuted),
                ),
              ],
            ),
          );
        }

        if (hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              'Offers list is not available right now.',
              style: TextStyle(color: palette.warning),
            ),
          );
        }

        if (offers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              'No offers created yet.',
              style: TextStyle(color: palette.onSurfaceMuted),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.surfaceElevated, palette.surface],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Select offers for this item',
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final checked = _selectedOfferIds.contains(offer.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            if (checked) {
                              _selectedOfferIds.remove(offer.id);
                            } else {
                              _selectedOfferIds.add(offer.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: checked ? palette.primary : palette.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: checked ? palette.primary : palette.surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: checked ? palette.primary : palette.border,
                                  ),
                                ),
                                child: Icon(
                                  checked ? Icons.check_rounded : Icons.add_rounded,
                                  size: 14,
                                  color: checked ? Colors.white : palette.onSurfaceMuted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      offer.title,
                                      style: TextStyle(
                                        color: palette.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      offer.status,
                                      style: TextStyle(
                                        color: palette.onSurfaceMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusToggle() {
    final palette = OwnerTheme.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'status',
          style: TextStyle(color: palette.onSurfaceMuted, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _statuses.map((status) {
            final selected = _status == status;
            return ChoiceChip(
              label: Text(status.toUpperCase()),
              selected: selected,
              onSelected: (_) => setState(() => _status = status),
              labelStyle: TextStyle(
                color: selected ? Colors.white : palette.onSurfaceMuted,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: palette.primary,
              backgroundColor: palette.surface,
              side: BorderSide(color: selected ? palette.primary : palette.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _categoryDropdown(List<CategoryEntity> categories) {
    final availableCategoryIds = categories.map((category) => category.id).toSet();
    final selectedValue = availableCategoryIds.contains(_selectedCategoryId)
        ? _selectedCategoryId
        : null;

    final dropdownItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('No category')),
      ...categories.map(
        (category) => DropdownMenuItem<int?>(
          value: category.id,
          child: Text('${category.name} (#${category.id})'),
        ),
      ),
    ];

    return DropdownButtonFormField<int?>(
      initialValue: selectedValue,
      items: dropdownItems,
      onChanged: (value) => setState(() => _selectedCategoryId = value),
      decoration: _inputDecoration(context, 'category_id'),
      dropdownColor: OwnerTheme.palette(context).surfaceAlt,
      style: TextStyle(color: OwnerTheme.palette(context).onSurface),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T value) itemLabel,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
        decoration: _inputDecoration(context, label, icon: icon),
      dropdownColor: OwnerTheme.palette(context).surfaceAlt,
      style: TextStyle(color: OwnerTheme.palette(context).onSurface),
      validator: (selected) {
        if (selected == null) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: OwnerTheme.palette(context).onSurface),
      decoration: _inputDecoration(context, label, icon: icon),
    );
  }

  Widget _sectionLabel(String text) {
    final palette = OwnerTheme.palette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: palette.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _imageUploadSection() {
    final palette = OwnerTheme.palette(context);
    final image = _selectedImage;
    final existingImageUrl = ImageHelper.build(_existingImagePath);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.surfaceElevated, palette.surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'image upload (optional)',
            style: TextStyle(color: palette.onSurfaceMuted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text(
                'Pick Image',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (image != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(image.path),
                height: 190,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.onSurfaceMuted, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _removeSelectedImage,
                  child: Text(
                    'Remove',
                    style: TextStyle(color: palette.error, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ] else if (existingImageUrl != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                existingImageUrl,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: palette.surfaceAlt,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.onSurfaceSoft,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    IconData? icon,
  }) {
    final palette = OwnerTheme.palette(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.onSurfaceMuted),
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: icon == null ? null : Icon(icon, color: palette.primary, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.primary),
      ),
    );
  }

  String _formatDateTimeForApi(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    final year = value.year.toString();
    final month = twoDigits(value.month);
    final day = twoDigits(value.day);
    final hour = twoDigits(value.hour);
    final minute = twoDigits(value.minute);
    final second = twoDigits(value.second);

    return '$year-$month-$day $hour:$minute:$second';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.palette,
    required this.isEditing,
    required this.categoryCount,
  });

  final OwnerPalette palette;
  final bool isEditing;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary, palette.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Item' : 'Create Item',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Build a polished item page with prices, offers and image.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(label: 'Categories', value: categoryCount.toString()),
              const SizedBox(height: 8),
              _MiniStat(label: 'Mode', value: isEditing ? 'Edit' : 'New'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final OwnerPalette palette;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.onSurfaceMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.palette,
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
  });

  final OwnerPalette palette;
  final bool isSubmitting;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.surfaceElevated, palette.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready to save?',
            style: TextStyle(
              color: palette.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review the fields above, then create or update this item.',
            style: TextStyle(
              color: palette.onSurfaceMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
