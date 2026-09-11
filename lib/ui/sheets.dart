import 'package:flutter/material.dart';

const double _maxSheetHeightFraction = 0.75;

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * _maxSheetHeightFraction,
    ),
    builder: builder,
  );
}
