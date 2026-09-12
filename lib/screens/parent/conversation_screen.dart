import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/screen_kit.dart';

const _maxRecording = Duration(minutes: 3);

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.thread});

  final ThreadSummary thread;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ThreadMessage>>>();
  final _text = TextEditingController();
  final _recorder = AudioRecorder();

  bool _sending = false;
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  String? _clipPath;

  @override
  void initState() {
    super.initState();
    unawaited(_markRead());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _text.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ParentApi.instance.markThreadRead(widget.thread.id);
    } on ApiException {
      return;
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) showNote(context, t('voice.noMic'), bad: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
      _clipPath = path;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed >= _maxRecording) unawaited(_stopRecording(send: true));
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _ticker?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    final clip = path ?? _clipPath;
    if (!send || clip == null) {
      if (clip != null) unawaited(File(clip).delete().catchError((_) => File(clip)));
      return;
    }
    if (_elapsed.inMilliseconds < 1000) {
      showNote(context, t('voice.tooShort'), bad: true);
      unawaited(File(clip).delete().catchError((_) => File(clip)));
      return;
    }
    await _send(clipPath: clip, clipMs: _elapsed.inMilliseconds);
  }

  Future<void> _send({String? clipPath, int? clipMs}) async {
    final body = _text.text.trim();
    if (body.isEmpty && clipPath == null) return;
    setState(() => _sending = true);
    try {
      String? assetId;
      if (clipPath != null) {
        final bytes = await File(clipPath).readAsBytes();
        assetId = await ParentApi.instance.uploadFile(
          bytes: bytes,
          filename: clipPath.split('/').last,
          mime: 'audio/mp4',
          kind: 'VOICE_NOTE',
          studentId: widget.thread.studentId,
          durationMs: clipMs,
        );
        unawaited(File(clipPath).delete().catchError((_) => File(clipPath)));
      }
      await ParentApi.instance.replyToThread(
        widget.thread.id,
        body: body.isEmpty ? null : body,
        voiceNoteAssetId: assetId,
      );
      if (!mounted) return;
      _text.clear();
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: widget.thread.subject,
              subtitle: widget.thread.studentName,
            ),
            Expanded(
              child: Loader<List<ThreadMessage>>(
                key: _loaderKey,
                tint: tint,
                empty: t('conv.nothingYet'),
                isEmpty: (rows) => rows.isEmpty,
                load: () => ParentApi.instance.threadMessages(widget.thread.id),
                builder: (context, rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final m in rows) ...[
                      _Bubble(threadId: widget.thread.id, message: m, tint: tint),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            if (!widget.thread.resolved)
              _Composer(
                controller: _text,
                tint: tint,
                sending: _sending,
                recording: _recording,
                elapsed: _elapsed,
                onSend: () => _send(),
                onStartRecording: _startRecording,
                onStopRecording: ({required bool send}) =>
                    _stopRecording(send: send),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.tint,
    required this.sending,
    required this.recording,
    required this.elapsed,
    required this.onSend,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final TextEditingController controller;
  final Color tint;
  final bool sending;
  final bool recording;
  final Duration elapsed;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final void Function({required bool send}) onStopRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: recording
          ? Row(
              children: [
                Icon(Icons.fiber_manual_record_rounded,
                    color: AppTheme.rose, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${t('voice.recording')}  ${_mmss(elapsed)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => onStopRecording(send: false),
                  child: Text(t('common.cancel')),
                ),
                const SizedBox(width: 4),
                _RoundButton(
                  icon: Icons.send_rounded,
                  tint: tint,
                  onTap: () => onStopRecording(send: true),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: t('conv.writeSomething'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.mic_rounded,
                  tint: tint,
                  onTap: sending ? null : onStartRecording,
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Icons.send_rounded,
                  tint: tint,
                  onTap: sending ? null : onSend,
                ),
              ],
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tint, this.onTap});

  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppTheme.border : tint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.threadId, required this.message, required this.tint});

  final String threadId;
  final ThreadMessage message;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromFamily;
    if (message.systemNote) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            message.body ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: mine ? tint.withValues(alpha: 0.12) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Text(
                    message.authorName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
                if (message.withdrawn)
                  Text(
                    t('conv.withdrawn'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textMuted,
                    ),
                  )
                else ...[
                  if (message.voice != null)
                    _VoiceBubble(
                      threadId: threadId,
                      messageId: message.id,
                      voice: message.voice!,
                      tint: tint,
                    ),
                  if ((message.body ?? '').isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: message.voice != null ? 6 : 0),
                      child: Text(
                        message.body!,
                        style: TextStyle(fontSize: 13.5, color: AppTheme.text),
                      ),
                    ),
                ],
                const SizedBox(height: 4),
                Text(
                  message.sentAt == null ? '' : _hhmm(message.sentAt!),
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    required this.threadId,
    required this.messageId,
    required this.voice,
    required this.tint,
  });

  final String threadId;
  final String messageId;
  final VoiceNote voice;
  final Color tint;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      if (mounted) setState(() {});
      return;
    }
    if (_player.audioSource != null) {
      unawaited(_player.play());
      setState(() {});
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await ParentApi.instance
          .voiceUrl(widget.threadId, widget.messageId);
      if (url == null) {
        if (mounted) showNote(context, t('voice.unavailable'), bad: true);
        return;
      }
      await _player.setUrl(url);
      unawaited(_player.play());
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } catch (_) {
      if (mounted) showNote(context, t('voice.unavailable'), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.voice.ready) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            t('voice.checking'),
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      );
    }
    final playing = _player.playing;
    return InkWell(
      onTap: _busy ? null : _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: widget.tint, shape: BoxShape.circle),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.graphic_eq_rounded, size: 18, color: widget.tint),
          const SizedBox(width: 6),
          Text(
            _mmss(widget.voice.length),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _mmss(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
