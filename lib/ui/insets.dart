import 'package:flutter/widgets.dart';

EdgeInsets withBottomInset(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(bottom: padding.bottom + MediaQuery.paddingOf(context).bottom);
