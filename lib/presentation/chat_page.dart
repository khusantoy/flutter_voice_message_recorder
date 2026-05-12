import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/voice_message.dart';
import '../domain/waveform.dart';
import 'voice_message_bubble.dart';
import 'voice_recorder_widget.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ValueNotifier<List<VoiceMessage>> _messages;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Demo seed: keshlashni sinab ko'rish uchun bitta ochiq sample audio.
    // Server odatda waveform metadata'ni xabar bilan birga yuboradi (Telegram uslubi)
    // — shu yerda uni simulyatsiya qilamiz, shunda bubble darhol "haqiqiy ko'rinishli"
    // to'lqinlarni ko'rsatadi, yuklab olish kutilmaydi.
    _messages = ValueNotifier<List<VoiceMessage>>([
      VoiceMessage.remote(
        url: 'https://samplelib.com/mp3/sample-15s.mp3',
        duration: const Duration(seconds: 15),
        waveform: _fakeServerWaveform(seed: 42, count: 80),
      ),
    ]);
  }

  Waveform _fakeServerWaveform({required int seed, required int count}) {
    final rng = Random(seed);
    return Waveform(
      List<double>.generate(count, (_) => 0.15 + rng.nextDouble() * 0.85),
    );
  }

  @override
  void dispose() {
    _messages.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onRecorded(VoiceMessage message) {
    _messages.value = [..._messages.value, message];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: const BackButton(),
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: cs.primaryContainer,
              child: Text(
                'A',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alisher',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'online',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () {},
            tooltip: 'Video qo\'ng\'iroq',
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () {},
            tooltip: 'Qo\'ng\'iroq',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<VoiceMessage>>(
              valueListenable: _messages,
              builder: (context, messages, _) {
                if (messages.isEmpty) return _EmptyState(cs: cs);
                return ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + mq.padding.bottom / 2,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) =>
                      VoiceMessageBubble(message: messages[i]),
                );
              },
            ),
          ),
          _InputBar(onRecorded: _onRecorded, bottomPadding: mq.padding.bottom),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.onRecorded, required this.bottomPadding});

  final ValueChanged<VoiceMessage> onRecorded;
  final double bottomPadding;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final ValueNotifier<bool> _showRecorder = ValueNotifier(false);

  @override
  void dispose() {
    _showRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(100), width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + widget.bottomPadding),
      child: ValueListenableBuilder<bool>(
        valueListenable: _showRecorder,
        builder: (context, show, _) {
          if (show) {
            return VoiceRecorderWidget(
              onRecorded: (r) {
                _showRecorder.value = false;
                widget.onRecorded(r);
              },
              onCancelled: () => _showRecorder.value = false,
            );
          }
          return _TextRow(onMicTap: () => _showRecorder.value = true);
        },
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.onMicTap});
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Xabar...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withAlpha(120),
                  ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: cs.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onMicTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.mic_rounded, color: cs.onPrimary, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 52,
            color: cs.onSurfaceVariant.withAlpha(120),
          ),
          const SizedBox(height: 12),
          Text(
            'Hali xabar yo\'q',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant.withAlpha(160),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mikrofon tugmasini bosib ovozli xabar yuboring',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withAlpha(120),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
