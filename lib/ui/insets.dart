import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const _gapAboveBar = 8.0;

EdgeInsets withBottomInset(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);

EdgeInsets clearOfTheBar(BuildContext context, EdgeInsets padding) => padding.copyWith(
      bottom: math.max(padding.bottom, MediaQuery.paddingOf(context).bottom + _gapAboveBar),
    );
