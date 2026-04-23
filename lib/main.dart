import 'package:flutter/material.dart';

import 'models/voice_recording_result.dart';
import 'widgets/voice_recorder_widget.dart';

void main() {
  runApp(const VoiceRecorderDemoApp());
}

class VoiceRecorderDemoApp extends StatelessWidget {
  const VoiceRecorderDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const VoiceRecorderDemoPage(),
    );
  }
}

class VoiceRecorderDemoPage extends StatefulWidget {
  const VoiceRecorderDemoPage({super.key});

  @override
  State<VoiceRecorderDemoPage> createState() => _VoiceRecorderDemoPageState();
}

class _VoiceRecorderDemoPageState extends State<VoiceRecorderDemoPage> {
  final List<VoiceRecordingResult> _recordings = [];

  void _onRecorded(VoiceRecordingResult result) {
    setState(() => _recordings.insert(0, result));
  }

  String _formatDuration(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _recordings.isEmpty
                  ? _EmptyState(color: cs.onSurfaceVariant)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _recordings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = _recordings[i];
                        return Card(
                          elevation: 0,
                          color: cs.surfaceContainer,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Icon(
                                Icons.audiotrack_rounded,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            title: Text('Xabar #${_recordings.length - i}'),
                            subtitle: Text(
                              '${_formatDuration(r.duration)}  ·  ${r.filePath.split('/').last}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: VoiceRecorderWidget(onRecorded: _onRecorded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none_rounded, size: 56, color: color),
          const SizedBox(height: 12),
          Text(
            'Hali ovozli xabar yo\'q',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
