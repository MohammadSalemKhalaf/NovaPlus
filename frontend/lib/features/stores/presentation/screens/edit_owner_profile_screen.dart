import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/image_helper.dart';
import '../controllers/edit_owner_profile_controller.dart';
import '../theme/owner_theme.dart';

class EditOwnerProfileScreen extends StatefulWidget {
  const EditOwnerProfileScreen({super.key, required this.controller});

  final EditOwnerProfileController controller;

  @override
  State<EditOwnerProfileScreen> createState() => _EditOwnerProfileScreenState();
}

class _EditOwnerProfileScreenState extends State<EditOwnerProfileScreen> {
  Color get _colorPrimary => OwnerTheme.palette(context).primary;
  Color get _colorError => OwnerTheme.palette(context).error;
  Color get _colorBackground => OwnerTheme.palette(context).background;
  Color get _colorSurface => OwnerTheme.palette(context).surface;
  Color get _colorText => OwnerTheme.palette(context).onSurface;
  Color get _colorTextSecondary => OwnerTheme.palette(context).onSurfaceMuted;
  static const List<({String label, String dialCode})> _whatsAppPrefixes = [
    (label: 'Palestine', dialCode: '+970'),
    (label: 'Israel', dialCode: '+972'),
    (label: 'Jordan', dialCode: '+962'),
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _storeImageController;
  late final FocusNode _nameFocus;
  late final FocusNode _whatsappFocus;
  late final FocusNode _passwordFocus;
  late final FocusNode _confirmPasswordFocus;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedWhatsAppPrefix = '+970';
  XFile? _selectedStoreImage;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickStoreImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedStoreImage = picked;
      _storeImageController.text = '';
    });
  }

  void _clearSelectedStoreImage() {
    setState(() {
      _selectedStoreImage = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _whatsappController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _storeImageController = TextEditingController();

    _nameFocus = FocusNode();
    _whatsappFocus = FocusNode();
    _passwordFocus = FocusNode();
    _confirmPasswordFocus = FocusNode();

    widget.controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeImageController.dispose();
    _nameFocus.dispose();
    _whatsappFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    widget.controller.removeListener(_onControllerStateChanged);
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (mounted && widget.controller.isUnauthorized) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final whatsappLocalRaw = _whatsappController.text.trim();
    final whatsappLocal = whatsappLocalRaw.replaceAll(RegExp(r'\D'), '');
    final whatsapp = whatsappLocal.isEmpty
        ? ''
        : '$_selectedWhatsAppPrefix$whatsappLocal';
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final storeImageRaw = _storeImageController.text.trim();
    final hasPickedStoreImage = _selectedStoreImage != null;

    // At least one field must be filled
    if (name.isEmpty &&
        whatsapp.isEmpty &&
        password.isEmpty &&
        storeImageRaw.isEmpty &&
        !hasPickedStoreImage) {
      widget.controller.errorMessage = 'Please fill at least one field';
      return;
    }

    // Validate name format if provided
    if (name.isNotEmpty) {
      if (name.length < 2) {
        widget.controller.errorMessage = 'Name must be at least 2 characters';
        return;
      }
    }

    // Validate WhatsApp format if provided
    if (whatsappLocalRaw.isNotEmpty && whatsappLocal.length < 7) {
      widget.controller.errorMessage = 'WhatsApp number is too short';
      return;
    }

    // Validate password if provided
    if (password.isNotEmpty) {
      if (password.length < 8) {
        widget.controller.errorMessage =
            'Password must be at least 8 characters';
        return;
      }
      // If password is provided, confirm password is required
      if (confirmPassword.isEmpty) {
        widget.controller.errorMessage = 'Please confirm your password';
        return;
      }
      if (password != confirmPassword) {
        widget.controller.errorMessage = 'Passwords do not match';
        return;
      }
    }

    // Only require confirm password if password is provided
    if (confirmPassword.isNotEmpty && password.isEmpty) {
      widget.controller.errorMessage = 'Please enter a password to confirm it';
      return;
    }

    final success = await widget.controller.updateProfile(
      name: name.isEmpty ? null : name,
      tenantWhatsappNumber: whatsapp.isEmpty ? null : whatsapp,
      tenantStoreImage: storeImageRaw.isEmpty ? null : storeImageRaw,
      tenantStoreImageFilePath: _selectedStoreImage?.path,
      password: password.isEmpty ? null : password,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorBackground,
      appBar: AppBar(
        backgroundColor: _colorBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: _colorText),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: _colorText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message
                  if (widget.controller.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _colorError.withValues(alpha: 0.1),
                        border: Border.all(color: _colorError),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: _colorError,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.controller.errorMessage!,
                              style: TextStyle(
                                color: _colorError,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: _colorError,
                              size: 20,
                            ),
                            onPressed: widget.controller.clearError,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.controller.errorMessage != null)
                    const SizedBox(height: 16),

                  // Info text
                  Text(
                    'Update only the fields you want to change',
                    style: TextStyle(
                      color: _colorTextSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  const _FormLabel(label: 'Name (Optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    enabled: !widget.controller.isSubmitting,
                    style: TextStyle(color: _colorText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Leave empty to keep current name',
                      hintStyle: TextStyle(
                        color: _colorTextSecondary,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: _colorSurface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) {
                      _nameFocus.unfocus();
                      FocusScope.of(context).requestFocus(_whatsappFocus);
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // WhatsApp number field
                  const _FormLabel(label: 'WhatsApp Number (Optional)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 146,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedWhatsAppPrefix,
                          isExpanded: true,
                          dropdownColor: _colorSurface,
                          iconEnabledColor: _colorTextSecondary,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _colorSurface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorSurface,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorSurface,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                          style: TextStyle(
                            color: _colorText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _whatsAppPrefixes
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option.dialCode,
                                  child: Text(
                                    '${option.label} ${option.dialCode}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: widget.controller.isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(
                                    () => _selectedWhatsAppPrefix = value,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _whatsappController,
                          focusNode: _whatsappFocus,
                          enabled: !widget.controller.isSubmitting,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          style: TextStyle(
                            color: _colorText,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            hintStyle: TextStyle(
                              color: _colorTextSecondary,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: _colorSurface,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorSurface,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorSurface,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _colorPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                          onFieldSubmitted: (_) {
                            _whatsappFocus.unfocus();
                            FocusScope.of(context).requestFocus(_passwordFocus);
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _FormLabel(label: 'Store Image (Optional)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.controller.isSubmitting ? null : _pickStoreImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _selectedStoreImage == null
                                ? 'Upload From Gallery'
                                : 'Change Selected Image',
                          ),
                        ),
                      ),
                      if (_selectedStoreImage != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: widget.controller.isSubmitting ? null : _clearSelectedStoreImage,
                          icon: Icon(Icons.close_rounded, color: _colorTextSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      if (_selectedStoreImage != null) {
                        return Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            color: _colorSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.file(
                            File(_selectedStoreImage!.path),
                            fit: BoxFit.cover,
                          ),
                        );
                      }

                      final imageUrl = ImageHelper.build(_storeImageController.text);
                      if (imageUrl == null) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        width: double.infinity,
                        height: 130,
                        decoration: BoxDecoration(
                          color: _colorSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: _colorTextSecondary,
                              size: 28,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password field (optional)
                  const _FormLabel(label: 'New Password (Optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    enabled: !widget.controller.isSubmitting,
                    style: TextStyle(color: _colorText, fontSize: 14),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Leave empty to keep current password',
                      hintStyle: TextStyle(
                        color: _colorTextSecondary,
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _colorTextSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      filled: true,
                      fillColor: _colorSurface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) {
                      _passwordFocus.unfocus();
                      FocusScope.of(
                        context,
                      ).requestFocus(_confirmPasswordFocus);
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Confirm password field
                  const _FormLabel(label: 'Confirm Password (Optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    enabled: !widget.controller.isSubmitting,
                    style: TextStyle(color: _colorText, fontSize: 14),
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Required only if setting a new password',
                      hintStyle: TextStyle(
                        color: _colorTextSecondary,
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: _colorTextSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      filled: true,
                      fillColor: _colorSurface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorSurface,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _colorPrimary,
                          width: 2,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) {
                      _confirmPasswordFocus.unfocus();
                    },
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.controller.isSubmitting
                          ? null
                          : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorPrimary,
                        disabledBackgroundColor: _colorPrimary.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: widget.controller.isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _colorText,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: TextStyle(
                                color: _colorText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
