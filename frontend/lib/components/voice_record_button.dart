import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordButton extends StatefulWidget {
  final Future<void> Function(String audioPath) onAudioRecorded;
  final String tooltip;

  const VoiceRecordButton({
    super.key,
    required this.onAudioRecorded,
    this.tooltip = 'Hold to record audio',
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final AudioRecorder _record = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;

  Future<String> _nextFilePath() async {
    final dir = await getTemporaryDirectory();
    final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${dir.path}/$filename';
  }

  Future<void> _startRecording() async {
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }

    final path = await _nextFilePath();
    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (mounted) {
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _record.stop();
    if (mounted) {
      setState(() => _isRecording = false);
    }

    if (path == null || path.isEmpty) return;

    if (mounted) {
      setState(() => _isUploading = true);
    }
    try {
      await widget.onAudioRecorded(path);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _stopRecording(),
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          color: _isRecording
              ? Colors.red.shade400
              : Theme.of(context).colorScheme.primary,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isUploading ? null : () {},
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
