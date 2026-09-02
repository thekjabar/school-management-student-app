import 'package:flutter/material.dart';

/// The one way this app opens a bottom sheet.
///
/// Always on the ROOT navigator. The parent app keeps a navigator per tab so
/// the back gesture unwinds the tab rather than the app, and a sheet opened
/// through one of those landed inside it: the header and the bottom bar sat
/// bright and untouched above and below the scrim, and a modal that leaves
/// half the screen live is not a modal. The child picker in the header was the
/// only sheet that got this right, because the shell opened it from its own
/// context, so every sheet now goes the way that one does.
///
/// Never taller than three quarters of the screen. A sheet that reaches the
/// status bar has stopped being a sheet: the page it came from is completely
/// hidden, so there is nothing left to show that this is a layer on top of
/// something, and the only way back is a button somewhere inside it. Leaving a
/// quarter of the page visible above it is what makes the scrim and the drag
/// handle mean anything. Sheets whose content is taller scroll inside that
/// height, which they already do.
///
/// Set here rather than per sheet because it was per sheet, and the numbers had
/// already drifted to 0.92, 0.92 and 0.76 in three files.
const double _maxSheetHeightFraction = 0.75;

/// Sheets that need the keyboard pad themselves by `viewInsets.bottom`: at the
/// root there is no Scaffold above the sheet to shrink for it.
///
/// Popping from inside the sheet — `Navigator.of(context).pop(result)` — still
/// closes the sheet, because the sheet's own context is under the root
/// navigator now. What must NOT be done from inside is pushing a page: it would
/// cover the tab bar. Pop first, then push from the caller's context.
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
