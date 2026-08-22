import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flipped to true the moment any API call comes back with API_SPEC.md's
/// `403 not_allowlisted`. There is no dedicated "check allowlist" endpoint —
/// this is how `AuthGate` finds out reactively (see `dioProvider` in
/// dio_client.dart, which sets this from a Dio error interceptor).
final notAllowlistedProvider = StateProvider<bool>((ref) => false);
