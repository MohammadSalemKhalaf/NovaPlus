# Production Activation Code Flow - Implementation Reference

## Quick Code Snippets

### 1. Auto-Generate 8-Character Code

```dart
import 'dart:math';

String _generateCode() {
  final random = Random();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
}

// Usage in initState
@override
void initState() {
  super.initState();
  _generatedCode = _generateCode();
  _code.text = _generatedCode;
}
```

### 2. Copy to Clipboard

```dart
import 'package:flutter/services.dart';

Future<void> _copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1F7A4D),
      ),
    );
}
```

### 3. Clean Request Body (No Empty Strings)

```dart
Future<void> _submit() async {
  final codeValue = _code.text.trim();
  final noteValue = _note.text.trim();

  // Only include non-empty fields
  final body = {
    "duration_months": durationMonths,
    "sold_by_user_id": currentUserId,
  };

  if (codeValue.isNotEmpty) body["code"] = codeValue;
  if (noteValue.isNotEmpty) body["note"] = noteValue;

  // Send body - guaranteed no empty strings
  await cubit.createActivationCode(
    durationMonths: durationMonths,
    code: codeValue.isNotEmpty ? codeValue : null,
    note: noteValue.isNotEmpty ? noteValue : null,
  );
}
```

### 4. Loading State in Button

```dart
SizedBox(
  height: 48,
  child: ElevatedButton(
    onPressed: state.submitting ? null : _submit,  // Disable during submit
    child: state.submitting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Text(
            'Create Code',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
  ),
)
```

### 5. Success Dialog with Code Display

```dart
void _showSuccessDialog(String code) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF121225),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Activation Code Created',
        style: TextStyle(color: Color(0xFFF2F2FF), fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2B2B43)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Color(0xFFF2F2FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _copyToClipboard(code),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Color(0xFF7B61FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
```

### 6. Auto-Fill from Cubit State

```dart
void _prefillFields() {
  final cubit = context.read<SalesAgentCubit>();
  final state = cubit.state;

  // Pre-fill code from last created activation code
  if (_code.text.isEmpty && state.lastActivationCode?.code != null) {
    _code.text = state.lastActivationCode!.code;
  }

  // Pre-fill tenant_id from last onboarding
  if (_tenantId.text.isEmpty && state.lastOnboarding?.tenantId != null) {
    _tenantId.text = state.lastOnboarding!.tenantId.toString();
  }
}

@override
void initState() {
  super.initState();
  _prefillFields();
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _prefillFields();
}
```

### 7. Display Auto-Generated Code Field

```dart
Widget _buildCodeField() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Code (Auto-generated)',
        style: TextStyle(color: Color(0xFFABABCA), fontSize: 13),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF15152A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2B2B43)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _code.text,
                      style: const TextStyle(
                        color: Color(0xFFF2F2FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Copy button
                  GestureDetector(
                    onTap: () => _copyToClipboard(_code.text),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B61FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF7B61FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Refresh button
          GestureDetector(
            onTap: () {
              setState(() {
                _generatedCode = _generateCode();
                _code.text = _generatedCode;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF15152A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2B2B43)),
              ),
              child: const Icon(
                Icons.refresh,
                size: 18,
                color: Color(0xFF7B61FF),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
```

### 8. Dynamic Button Text Based on Prefill

```dart
ElevatedButton(
  onPressed: state.submitting ? null : _submit,
  child: state.submitting
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(),
        )
      : Text(
          state.lastActivationCode?.code != null && _tenantId.text.isNotEmpty
              ? 'Activate Subscription'  // Pre-filled
              : 'Redeem Code',            // Manual entry
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
)
```

### 9. Pre-Filled Status Info Banner

```dart
if (state.lastActivationCode?.code != null ||
    state.lastOnboarding?.tenantId != null) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1F7A4D).withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFF1F7A4D).withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle,
          size: 16,
          color: Color(0xFF1F7A4D),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.lastActivationCode?.code != null &&
                    state.lastOnboarding?.tenantId != null
                ? 'Ready to activate subscription for tenant ${state.lastOnboarding?.tenantId}'
                : 'Auto-filled from previous step',
            style: const TextStyle(
              color: Color(0xFF1F7A4D),
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  ),
],
```

### 10. Form Validation

```dart
Widget _field({
  required TextEditingController controller,
  required String label,
  TextInputType? keyboardType,
  bool required = true,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: Color(0xFFF2F2FF)),
    decoration: _decoration(label),
    validator: (value) {
      if (!required) return null;
      
      if (value == null || value.trim().isEmpty) {
        return '$label is required';
      }
      
      if (label == 'Duration Months') {
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed <= 0) {
          return 'Duration must be positive';
        }
      }
      
      if (label == 'Tenant ID') {
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed <= 0) {
          return 'Tenant ID must be positive';
        }
      }
      
      return null;
    },
  );
}
```

## Key Points

✅ **Auto-Generation:** Always generate fresh code in `initState()`  
✅ **No Empty Strings:** Check `.isNotEmpty` before adding to request body  
✅ **Loading State:** Conditional button behavior via `state.submitting`  
✅ **Copy Feature:** Use `Clipboard.setData()` with feedback toast  
✅ **Success Dialog:** Show code prominently, offer copy inside dialog  
✅ **Smart Prefill:** Check `state.lastXXX` fields in `didChangeDependencies()`  
✅ **Dynamic UI:** Change button text and info based on which fields are pre-filled  
✅ **Validation:** Prevent empty/invalid inputs before submission  
✅ **Error Handling:** Show red snackbar with error message, allow retry  
✅ **User Feedback:** Toast for clipboard, snackbars for errors, dialogs for success  

## Files Modified

1. `lib/features/sales_agent/presentation/screens/sales_agent_activation_code_screen.dart`
2. `lib/features/sales_agent/presentation/screens/sales_agent_redeem_subscription_screen.dart`

## State Management

Cubit already stores:
- `lastActivationCode` → code string for redeem screen to use
- `lastOnboarding` → tenant_id from previous onboarding step
- `lastRedeemResult` → final subscription status

No additional state needed!
