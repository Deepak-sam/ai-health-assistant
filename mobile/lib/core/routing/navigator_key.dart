import 'package:flutter/widgets.dart';

/// Root navigator key, shared by [AppRouter] (as `GoRouter.navigatorKey`) and
/// by anything that needs to push a full-screen route without already
/// holding a `BuildContext` — notably `GarminProvider.connect()`, which is
/// invoked from provider/business-logic code, not directly from a widget's
/// `build` method.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
