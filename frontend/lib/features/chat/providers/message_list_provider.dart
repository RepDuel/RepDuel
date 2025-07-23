// frontend/lib/features/chat/providers/message_list_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/models/message.dart';
import 'package:frontend/core/providers/api_providers.dart';

final messageListProvider = StateNotifierProvider.family<MessageListNotifier,
    AsyncValue<List<Message>>, String>((ref, channelId) {
  final api = ref.read(messageApiProvider);
  return MessageListNotifier(api: api, channelId: channelId);
});

class MessageListNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final dynamic api;
  final String channelId;

  MessageListNotifier({required this.api, required this.channelId})
      : super(const AsyncLoading()) {
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    try {
      final messages = await api.getMessages(channelId);
      state = AsyncData(messages);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void addMessage(Message newMessage) {
    final current = state.value ?? [];
    state = AsyncData([...current, newMessage]);
  }

  void prependMessages(List<Message> olderMessages) {
    final current = state.value ?? [];
    state = AsyncData([...olderMessages, ...current]);
  }

  void clear() {
    state = const AsyncData([]);
  }
}
