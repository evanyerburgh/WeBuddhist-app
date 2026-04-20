import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_pecha/core/config/locale/locale_notifier.dart';
import 'package:flutter_pecha/features/notifications/data/channels/notification_channels.dart';
import 'package:flutter_pecha/features/notifications/presentation/providers/notification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  static const String routeName = '/notifications';

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isSchedulingTest = false;
  bool _batteryExempt = true; // assume ok until checked

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    final exempt = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) setState(() => _batteryExempt = exempt);
  }

  Future<void> _requestBatteryExemption() async {
    final granted =
        await ref.read(notificationServiceProvider).requestBatteryOptimizationExemption();
    if (mounted) setState(() => _batteryExempt = granted);
  }

  Future<void> _scheduleTestNotification() async {
    final service = ref.read(notificationServiceProvider);
    if (!service.isInitialized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification service not ready')),
      );
      return;
    }

    setState(() => _isSchedulingTest = true);

    try {
      const testId = 9999;
      await service.notificationsPlugin.cancel(testId);

      final scheduledTime = tz.TZDateTime.now(tz.local).add(
        const Duration(minutes: 4),
      );

      await service.notificationsPlugin.zonedSchedule(
        testId,
        'Routine Notification Test',
        'Custom sound test — scheduled ${_hhmm(scheduledTime)}',
        scheduledTime,
        NotificationChannels.routineBlockDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test notification scheduled for ${_hhmm(scheduledTime)}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSchedulingTest = false);
    }
  }

  String _hhmm(tz.TZDateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final hasPermission = state.hasPermission;

    final localizations = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final titleFontSize = languageCode == 'bo' ? 20.0 : 16.0;
    final subtitleFontSize = languageCode == 'bo' ? 18.0 : 14.0;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.notification_settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Notification permission card ──────────────────────────
            if (!hasPermission) ...[
              Card(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Theme.of(context).colorScheme.error,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.notification_enable_message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: subtitleFontSize),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final granted = await ref
                              .read(notificationServiceProvider)
                              .requestPermission();
                          if (granted) {
                            ref
                                .read(notificationProvider.notifier)
                                .checkPermissionStatus();
                          } else {
                            await openAppSettings();
                          }
                        },
                        child: Text(
                          localizations.enable_notification,
                          style: TextStyle(fontSize: titleFontSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (hasPermission) ...[
              // ── Notifications enabled ────────────────────────────────
              Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Notifications are enabled',
                          style: TextStyle(fontSize: subtitleFontSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Battery optimisation warning (Android only) ──────────
              if (Platform.isAndroid && !_batteryExempt) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.battery_alert,
                                color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Battery Optimization Active',
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'On many Android devices (Samsung, OnePlus, Xiaomi…) '
                          'battery optimization can prevent notifications from '
                          'firing when the app is closed. Tap below to exempt '
                          'WeBuddhist from battery optimization.',
                          style: TextStyle(
                            fontSize: subtitleFontSize - 1,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestBatteryExemption,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.battery_charging_full),
                            label: Text(
                              'Disable Battery Optimization',
                              style: TextStyle(fontSize: subtitleFontSize),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Battery optimization OK ──────────────────────────────
              if (Platform.isAndroid && _batteryExempt) ...[
                Card(
                  color: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.battery_charging_full,
                            color: Colors.green, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Battery optimization is disabled — notifications will fire even when the app is closed.',
                            style: TextStyle(fontSize: subtitleFontSize),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Test notification ────────────────────────────────────
              Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Notification',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fires in 4 minutes. Close the app completely after tapping to test terminated-state delivery.',
                        style: TextStyle(
                          fontSize: subtitleFontSize - 1,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSchedulingTest
                              ? null
                              : _scheduleTestNotification,
                          icon: _isSchedulingTest
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.notifications_active),
                          label: Text(
                            _isSchedulingTest
                                ? 'Scheduling…'
                                : 'Schedule Test (4 min)',
                            style: TextStyle(fontSize: subtitleFontSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (state.isLoading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
