import 'package:flutter/foundation.dart';

class ChatPresence {
  ChatPresence._();

  static final ValueNotifier<bool> isGuestChatOpen = ValueNotifier<bool>(false);
}
