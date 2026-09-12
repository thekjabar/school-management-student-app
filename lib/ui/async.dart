import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';

String errorText(Object? e) => e is OfflineException
    ? t('common.offline')
    : e is ApiException
        ? e.message
        : t('common.loadFailed');

final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

class Loader<T> extends StatefulWidget {
  const Loader({
    super.key,
    required this.load,
    required this.builder,
    this.empty,
    this.isEmpty,
    this.tint,
    this.watch,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 28),
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  final String? empty;
  final bool Function(T data)? isEmpty;

  final Color? tint;

  /// What the load depends on. A Loader that stays mounted while this changes
  /// refetches; without it the first future is kept and the screen shows the
  /// data it opened with.
  final Object? watch;

  final EdgeInsets padding;

  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> with RouteAware {
  late Future<T> _future;
  Lang _loadedIn = AppLocale.current.value;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
    AppLocale.current.addListener(_languageChanged);
  }

  @override
  void dispose() {
    AppLocale.current.removeListener(_languageChanged);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Loader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.watch != oldWidget.watch) reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => reload();

  void _languageChanged() {
    if (!mounted) return;
    if (AppLocale.current.value == _loadedIn) return;
    _loadedIn = AppLocale.current.value;
    reload();
  }

  Future<void> reload({bool quiet = false}) async {
    if (!mounted) return;
    _loadedIn = AppLocale.current.value;

    if (quiet) {
      try {
        final value = await widget.load();
        if (!mounted) return;
        setState(() {
          _future = SynchronousFuture<T>(value);
        });
      } catch (_) {
      }
      return;
    }

    setState(() {
      _future = widget.load();
    });
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
            if (!snap.hasData) return _scrollable(const _Waiting());
          }

          if (snap.hasError) {
            final error = snap.error;
            return _scrollable(
              _Failed(
                message: errorText(error),
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
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          height: i == 0 ? 96 : 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.neutralSoft,
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
              Expanded(
                child: Text(
                  t('common.didNotLoad'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: AppTheme.textMuted, height: 1.45, fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: tint),
              child: Text(t('common.tryAgain')),
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
          Icon(Icons.inbox_rounded, size: 34, color: AppTheme.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

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
