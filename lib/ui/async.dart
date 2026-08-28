import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';

/// Loads something, and shows the four states it can be in.
///
/// Written once because every screen in these three apps needs exactly the same
/// four — waiting, failed, nothing there, and here it is — and a screen that
/// forgets the third shows a blank panel that reads as a broken app rather than
/// as "no homework this week".
///
/// Pull-to-refresh comes with it. On a school connection things fail, and a
/// parent's first instinct with a stale screen is to drag it down.
class Loader<T> extends StatefulWidget {
  const Loader({
    super.key,
    required this.load,
    required this.builder,
    this.empty,
    this.isEmpty,
    this.tint,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 28),
  });

  /// Called on first build and on every pull-to-refresh.
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// What to say when the load succeeded and there is nothing in it.
  final String? empty;
  final bool Function(T data)? isEmpty;

  final Color? tint;
  final EdgeInsets padding;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  /// Re-runs the load. Called by pull-to-refresh, and by screens that have just
  /// changed something on the server and need the list to catch up.
  Future<void> reload() async {
    setState(() => _future = widget.load());
    await _future.catchError((_) => null as T);
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppTheme.violet;

    return RefreshIndicator(
      color: tint,
      onRefresh: reload,
      child: FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _scrollable(const _Waiting());
          }

          if (snap.hasError) {
            final error = snap.error;
            return _scrollable(
              _Failed(
                message: error is ApiException
                    ? error.message
                    : 'Something went wrong. Pull down to try again.',
                onRetry: reload,
                tint: tint,
              ),
            );
          }

          final data = snap.data as T;
          final blank = widget.isEmpty?.call(data) ?? false;
          if (blank && widget.empty != null) {
            return _scrollable(_Empty(text: widget.empty!));
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            children: [widget.builder(context, data)],
          );
        },
      ),
    );
  }

  /// Even the failure and empty states must scroll, or pull-to-refresh — the
  /// only way out of them — does not work.
  Widget _scrollable(Widget child) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: [child],
      );
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    // Grey blocks in the shape of the content, not a spinner. On a slow cell
    // a spinner says "wait"; this says "something is coming, and roughly what".
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          height: i == 0 ? 96 : 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEFF3),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry, required this.tint});

  final String message;
  final VoidCallback onRetry;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.wifi_off_rounded,
                color: AppTheme.rose,
                background: AppTheme.roseSoft,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'That did not load',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: AppTheme.textMuted, height: 1.45, fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: tint),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 34, color: AppTheme.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// A short message at the bottom of the screen. Errors linger; a message that
/// vanishes before it is read is not a message.
void showNote(BuildContext context, String text, {bool bad = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bad ? AppTheme.rose : AppTheme.text,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: bad ? 6 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      ),
    );
}
