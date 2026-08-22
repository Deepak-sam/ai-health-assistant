import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart' as db;
import '../../core/theme/app_theme.dart';
import '../../shared/repositories/health_repository.dart';
import '../../shared/services/sync_service.dart';
import '../auth/auth_state.dart';

/// Settings tab: connection status for Health Connect/Garmin, notification
/// prefs, units, and a plain-language privacy statement. Calm/minimal —
/// no gamified "streak" or achievement UI anywhere here.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _units = 'metric';
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final dao = ref.read(db.appDatabaseProvider).settingsDao;
    final units = await dao.getValue(userId: userId, key: 'units');
    final notifications = await dao.getValue(userId: userId, key: 'notifications_enabled');
    if (!mounted) return;
    setState(() {
      _units = units ?? 'metric';
      _notificationsEnabled = notifications != 'false';
    });
  }

  Future<void> _setUnits(String value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(db.appDatabaseProvider).settingsDao.setValue(userId: userId, key: 'units', jsonValue: value);
    setState(() => _units = value);
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref
        .read(db.appDatabaseProvider)
        .settingsDao
        .setValue(userId: userId, key: 'notifications_enabled', jsonValue: value.toString());
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Connections'),
          if (userId != null) _HealthConnectTile(userId: userId),
          if (userId != null && AppConfig.garminEnabled) _GarminTile(userId: userId),
          const _SectionHeader('Alerts'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Manage alerts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/alerts'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Push notifications'),
            value: _notificationsEnabled,
            onChanged: _setNotificationsEnabled,
          ),
          const _SectionHeader('Units'),
          RadioListTile<String>(
            title: const Text('Metric (kg, km)'),
            value: 'metric',
            groupValue: _units,
            onChanged: (v) => _setUnits(v!),
          ),
          RadioListTile<String>(
            title: const Text('Imperial (lb, mi)'),
            value: 'imperial',
            groupValue: _units,
            onChanged: (v) => _setUnits(v!),
          ),
          const _SectionHeader('Privacy'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Your health data lives on this device and is never uploaded to a server '
              'database. When you log a meal with a photo, the picture is sent once for '
              'analysis and is never saved — not on your phone, not on our servers, not in '
              'any log. Only the calorie/macro estimate it produces is kept.',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _HealthConnectTile extends ConsumerWidget {
  const _HealthConnectTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(_connectionStatusProvider((userId: userId, provider: 'health_connect')));
    return ListTile(
      leading: const Icon(Icons.favorite_outline),
      title: const Text('Health Connect'),
      subtitle: Text(connectionAsync.value?.status ?? 'Not connected'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.chipRadius))),
        onPressed: () async {
          final provider = ref.read(healthConnectProviderInstanceProvider);
          await provider.connect();
          await ref.read(syncServiceProvider).syncAll(userId);
        },
        child: const Text('Connect'),
      ),
    );
  }
}

class _GarminTile extends ConsumerWidget {
  const _GarminTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(_connectionStatusProvider((userId: userId, provider: 'garmin')));
    return ListTile(
      leading: const Icon(Icons.watch_outlined),
      title: const Text('Garmin'),
      subtitle: Text(connectionAsync.value?.status ?? 'Not connected'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.chipRadius))),
        onPressed: () async {
          final provider = ref.read(garminProviderInstanceProvider);
          if (provider == null) return;
          try {
            await provider.connect();
            await ref.read(syncServiceProvider).syncAll(userId);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Garmin connection failed: $e')));
            }
          }
        },
        child: const Text('Connect'),
      ),
    );
  }
}

final _connectionStatusProvider =
    StreamProvider.family<db.DeviceConnection?, ({String userId, String provider})>((ref, args) {
  return ref.watch(db.appDatabaseProvider).deviceConnectionsDao.watchConnections(args.userId).map((list) {
    for (final c in list) {
      if (c.provider == args.provider) return c;
    }
    return null;
  });
});
