import 'package:flutter/material.dart';
import 'package:flutter_pecha/core/error/failures.dart';
import 'package:flutter_pecha/core/extensions/context_ext.dart';
import 'package:flutter_pecha/core/l10n/generated/app_localizations.dart';
import 'package:flutter_pecha/core/theme/app_colors.dart';
import 'package:flutter_pecha/core/utils/app_logger.dart';
import 'package:flutter_pecha/features/notifications/data/services/notification_service.dart';
import 'package:flutter_pecha/features/practice/data/models/routine_model.dart';
import 'package:flutter_pecha/features/practice/data/models/session_selection.dart';
import 'package:flutter_pecha/features/practice/data/utils/routine_api_mapper.dart';
import 'package:flutter_pecha/features/practice/data/utils/routine_time_utils.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/practice_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/providers/routine_api_providers.dart';
import 'package:flutter_pecha/features/practice/presentation/screens/select_session_screen.dart';
import 'package:flutter_pecha/features/practice/presentation/widgets/routine_time_block.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
final _logger = AppLogger('EditRoutineScreen');

class _EditableBlock {
  String id;
  String? apiTimeBlockId;
  TimeOfDay time;
  bool notificationEnabled;
  List<RoutineItem> items;

  _EditableBlock({
    String? id,
    this.apiTimeBlockId,
    required this.time,
    required this.notificationEnabled,
    List<RoutineItem>? items,
  })  : id = id ?? _uuid.v4(),
        items = items ?? [];
}

class EditRoutineScreen extends ConsumerStatefulWidget {
  const EditRoutineScreen({super.key});

  @override
  ConsumerState<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends ConsumerState<EditRoutineScreen> {
  late List<_EditableBlock> _blocks;

  /// Server routine id once loaded or after first create.
  String? _apiRoutineId;

  /// Time block ids that existed when the screen opened (for DELETE on save).
  Set<String> _initialApiTimeBlockIds = {};

  bool _hydratedFromApi = false;

  bool get _isLastBlockEmpty =>
      _blocks.isNotEmpty && _blocks.last.items.isEmpty;

  bool get _hasEmptyBlocks => _blocks.any((b) => b.items.isEmpty);

  @override
  void initState() {
    super.initState();
    _blocks = [
      _EditableBlock(
        time: const TimeOfDay(hour: 12, minute: 0),
        notificationEnabled: true,
      ),
    ];
  }

  // ─── Hydration ───

  /// Populates local editable state from the API response (already mapped
  /// to [RoutineData] by [userRoutineProvider] — no mapper calls in UI).
  void _applyInitialData(RoutineData? routineData) {
    _apiRoutineId = routineData?.apiRoutineId;
    _initialApiTimeBlockIds = {
      if (routineData != null)
        ...routineData.blocks
            .map((b) => b.apiTimeBlockId)
            .whereType<String>(),
    };

    if (routineData != null && routineData.blocks.isNotEmpty) {
      _blocks = routineData.blocks
          .map(
            (b) => _EditableBlock(
              id: b.id,
              apiTimeBlockId: b.apiTimeBlockId,
              time: b.time,
              notificationEnabled: b.notificationEnabled,
              items: List.from(b.items),
            ),
          )
          .toList();
    } else {
      _blocks = [
        _EditableBlock(
          time: const TimeOfDay(hour: 12, minute: 0),
          notificationEnabled: true,
        ),
      ];
    }
  }

  // ─── Helpers ───

  RoutineBlock _toRoutineBlock(_EditableBlock b) {
    return RoutineBlock(
      id: b.id,
      time: b.time,
      notificationEnabled: b.notificationEnabled,
      apiTimeBlockId: b.apiTimeBlockId,
      items: b.items,
    );
  }

  Future<void> _syncNotifications() async {
    final blocks = _blocks.map(_toRoutineBlock).toList();
    await ref.read(routineNotificationServiceProvider).syncNotifications(blocks);
  }

  // ─── Error handling ───

  /// Maps any thrown value to a user-facing error message.
  /// Handles both [Failure] objects (from use cases) and legacy exception types.
  String _mapError(Object e) {
    if (e is Failure) return e.message;
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return 'Something went wrong. Please try again.';
  }

  // ─── Server sync ───

  /// Deletes all remaining server-side time blocks when the user clears the
  /// entire routine.
  Future<void> _syncEmptyRoutineToServer() async {
    final routineId = _apiRoutineId;
    if (routineId == null) return;

    final deleteUseCase = ref.read(deleteTimeBlockUseCaseProvider);
    for (final blockId in _initialApiTimeBlockIds) {
      final result = await deleteUseCase(routineId, blockId);
      result.fold((failure) => throw failure, (_) {});
    }
  }

  /// Syncs the current [_blocks] state to the server.
  ///
  /// - If no routine exists yet: creates the routine with the first block,
  ///   then creates all remaining blocks.
  /// - If a routine already exists: deletes removed blocks, then
  ///   creates/updates each remaining block.
  Future<void> _persistBlocksToServer() async {
    var routineId = _apiRoutineId;

    final createRoutineUseCase =
        ref.read(createRoutineWithTimeBlockUseCaseProvider);
    final createBlockUseCase = ref.read(createTimeBlockUseCaseProvider);
    final updateBlockUseCase = ref.read(updateTimeBlockUseCaseProvider);
    final deleteBlockUseCase = ref.read(deleteTimeBlockUseCaseProvider);

    if (routineId == null) {
      // ── First save: create the routine ──
      final firstEditable = _blocks.first;
      final createResult = await createRoutineUseCase(
        routineBlockToRequest(_toRoutineBlock(firstEditable)),
      );
      createResult.fold(
        (failure) => throw failure,
        (created) {
          routineId = created.routineId;
          _apiRoutineId = routineId;
          firstEditable.apiTimeBlockId = created.timeBlockId;
          firstEditable.id = created.timeBlockId;
        },
      );

      // Create any additional blocks beyond the first
      for (var i = 1; i < _blocks.length; i++) {
        final editable = _blocks[i];
        final blockResult = await createBlockUseCase(
          routineId!,
          routineBlockToRequest(_toRoutineBlock(editable)),
        );
        blockResult.fold(
          (failure) => throw failure,
          (timeBlockId) {
            editable.apiTimeBlockId = timeBlockId;
            editable.id = timeBlockId;
          },
        );
      }
    } else {
      // ── Subsequent saves: diff and sync ──

      // 1. Delete blocks that were removed during editing
      final currentApiIds =
          _blocks.map((b) => b.apiTimeBlockId).whereType<String>().toSet();
      for (final oldId in _initialApiTimeBlockIds) {
        if (!currentApiIds.contains(oldId)) {
          final result = await deleteBlockUseCase(routineId, oldId);
          result.fold((failure) => throw failure, (_) {});
        }
      }

      // 2. Create new blocks / update existing ones
      for (final editable in _blocks) {
        final block = _toRoutineBlock(editable);
        final apiId = editable.apiTimeBlockId;
        if (apiId != null) {
          final result = await updateBlockUseCase(
            routineId,
            apiId,
            routineBlockToRequest(block),
          );
          result.fold((failure) => throw failure, (_) {});
        } else {
          final result = await createBlockUseCase(
            routineId,
            routineBlockToRequest(block),
          );
          result.fold(
            (failure) => throw failure,
            (timeBlockId) {
              editable.apiTimeBlockId = timeBlockId;
              editable.id = timeBlockId;
            },
          );
        }
      }
    }

    // Track new canonical set of API ids for any further saves in this session
    _initialApiTimeBlockIds = {
      for (final b in _blocks)
        if (b.apiTimeBlockId != null) b.apiTimeBlockId!,
    };
  }

  // ─── Save flow ───

  Future<void> _saveAndPop() async {
    if (_hasEmptyBlocks) {
      final shouldDelete = await _showEmptyBlockDialog();
      if (!mounted) return;

      if (shouldDelete == true) {
        setState(() => _blocks.removeWhere((b) => b.items.isEmpty));

        if (_blocks.isEmpty) {
          try {
            await _syncEmptyRoutineToServer();
            await _syncNotifications();
            ref.invalidate(userRoutineProvider);
            if (mounted) Navigator.of(context).pop();
          } catch (e, st) {
            _logger.error('Failed to clear routine', e, st);
            if (mounted) _showErrorSnackBar(_mapError(e));
          }
          return;
        }
      } else {
        return; // User chose to add items instead
      }
    }

    try {
      await _persistBlocksToServer();
      await _syncNotifications();
      ref.invalidate(userRoutineProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      _logger.error('Failed to save routine', e, st);
      if (mounted) _showErrorSnackBar(_mapError(e));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── Dialogs ───

  Future<bool?> _showEmptyBlockDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyCount = _blocks.where((b) => b.items.isEmpty).length;
    final hasMultipleEmpty = emptyCount > 1;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            hasMultipleEmpty ? 'Empty Time Blocks' : 'Empty Time Block',
          ),
          content: Text(
            hasMultipleEmpty
                ? 'You have $emptyCount time blocks without any items. '
                    'Would you like to add items or delete these blocks?'
                : 'This time block has no items. '
                    'Would you like to add an item or delete the block?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Add Items',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(
                hasMultipleEmpty ? 'Delete Empty Blocks' : 'Delete Block',
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Block operations ───

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _blocks[index].time,
    );
    if (picked != null) {
      final otherTimes = _blocks
          .asMap()
          .entries
          .where((e) => e.key != index)
          .map((e) => e.value.time)
          .toList();
      final adjusted = adjustTimeForMinimumGap(picked, otherTimes);

      if (adjusted == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.noTimeSlot),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _blocks[index].time = adjusted;
        _sortBlocks();
      });
      if (adjusted != picked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Adjusted to ${formatRoutineTime(adjusted)} '
              '($kMinBlockGapMinutes-min minimum gap)',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _sortBlocks() {
    _blocks.sort(
      (a, b) => timeToMinutes(a.time).compareTo(timeToMinutes(b.time)),
    );
  }

  Future<void> _toggleNotification(int index) async {
    if (_blocks[index].notificationEnabled) {
      setState(() => _blocks[index].notificationEnabled = false);
      return;
    }

    final enabled = await NotificationService().areNotificationsEnabled();
    if (!enabled && mounted) {
      final granted = await _showNotificationPermissionModal();
      if (granted != true) return;
    }

    if (mounted) {
      setState(() => _blocks[index].notificationEnabled = true);
    }
  }

  Future<bool?> _showNotificationPermissionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 48,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Make Prayer Daily',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Allow notifications to receive your reminder to pray.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final granted =
                          await NotificationService().requestPermission();
                      if (!granted) await openAppSettings();
                      final nowEnabled =
                          await NotificationService().areNotificationsEnabled();
                      nav.pop(nowEnabled);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : AppColors.textPrimaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteBlock(int index) async {
    final block = _blocks[index];
    final routineBlock = RoutineBlock(
      id: block.id,
      time: block.time,
      notificationEnabled: block.notificationEnabled,
      apiTimeBlockId: block.apiTimeBlockId,
      items: List.from(block.items),
    );
    await ref
        .read(routineNotificationServiceProvider)
        .cancelBlockNotification(routineBlock);

    setState(() => _blocks.removeAt(index));
  }

  bool get _isAtMaxBlocks => !canAddBlock(_blocks.length);
  bool get _shouldShowAddButton => !_isLastBlockEmpty && !_isAtMaxBlocks;

  int _calculateListItemCount() {
    return _shouldShowAddButton ? _blocks.length + 1 : _blocks.length;
  }

  void _addBlock() {
    if (_isAtMaxBlocks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.maxBlocks(kMaxBlocks)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final otherTimes = _blocks.map((b) => b.time).toList();
    final adjusted =
        adjustTimeForMinimumGap(const TimeOfDay(hour: 12, minute: 0), otherTimes);

    if (adjusted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.noTimeSlot),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _blocks.add(_EditableBlock(time: adjusted, notificationEnabled: false));
      _sortBlocks();
    });
  }

  void _onReorderItems(int blockIndex, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _blocks[blockIndex].items.removeAt(oldIndex);
      _blocks[blockIndex].items.insert(newIndex, item);
    });
  }

  void _onDeleteItem(int blockIndex, int itemIndex) {
    final block = _blocks[blockIndex];
    final wasNotEmpty = block.items.isNotEmpty;

    setState(() => _blocks[blockIndex].items.removeAt(itemIndex));

    // Cancel notification when the block becomes empty
    if (wasNotEmpty && _blocks[blockIndex].items.isEmpty) {
      final routineBlock = RoutineBlock(
        id: block.id,
        time: block.time,
        notificationEnabled: block.notificationEnabled,
        apiTimeBlockId: block.apiTimeBlockId,
        items: const [],
      );
      ref
          .read(routineNotificationServiceProvider)
          .cancelBlockNotification(routineBlock);
    }
  }

  ({Set<String> planIds, Set<String> recitationIds}) _collectRoutineItemIds() {
    final planIds = <String>{};
    final recitationIds = <String>{};
    for (final block in _blocks) {
      for (final item in block.items) {
        if (item.type == RoutineItemType.plan) planIds.add(item.id);
      }
    }
    return (planIds: planIds, recitationIds: recitationIds);
  }

  bool _isSelectingSession = false;

  Future<void> _navigateToSelectSession(int blockIndex) async {
    if (_isSelectingSession) return;
    _isSelectingSession = true;

    try {
      final excluded = _collectRoutineItemIds();
      final result = await Navigator.of(context).push<SessionSelection>(
        MaterialPageRoute(
          builder: (_) =>
              SelectSessionScreen(excludedPlanIds: excluded.planIds),
        ),
      );

      if (result != null && mounted) {
        final (newItemId, newItemType) = switch (result) {
          PlanSessionSelection(:final plan) => (plan.id, RoutineItemType.plan),
          RecitationSessionSelection(:final recitation) => (
              recitation.textId,
              RoutineItemType.recitation,
            ),
        };

        final isDuplicate = _blocks[blockIndex].items.any(
          (item) => item.id == newItemId && item.type == newItemType,
        );

        if (isDuplicate) {
          _logger.warning('Duplicate item prevented: $newItemId');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.duplicateItem),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        setState(() {
          switch (result) {
            case PlanSessionSelection(:final plan):
              _blocks[blockIndex].items.add(
                RoutineItem(
                  id: plan.id,
                  title: plan.title,
                  imageUrl: plan.coverImageUrl,
                  type: RoutineItemType.plan,
                  enrolledAt: DateTime.now(),
                ),
              );
            case RecitationSessionSelection(:final recitation):
              _blocks[blockIndex].items.add(
                RoutineItem(
                  id: recitation.textId,
                  title: recitation.title,
                  type: RoutineItemType.recitation,
                ),
              );
          }
        });
      }
    } finally {
      _isSelectingSession = false;
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final routineAsync = ref.watch(userRoutineProvider);

    // Show loading/error until the API data is hydrated into local editable state.
    if (!_hydratedFromApi) {
      return routineAsync.when(
        loading: () => _buildLoadingScaffold(localizations),
        error: (e, _) => _buildErrorScaffold(e, localizations),
        data: (routineData) {
          // Use a post-frame callback to avoid calling setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydratedFromApi) return;
            setState(() {
              _hydratedFromApi = true;
              _applyInitialData(routineData);
            });
          });
          return _buildLoadingScaffold(localizations);
        },
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _DoneButton(
                  onTap: _saveAndPop,
                  isDark: isDark,
                  label: localizations.done,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.routine_edit_title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: _calculateListItemCount(),
                    separatorBuilder: (_, index) {
                      final isLastItem = index == _blocks.length - 1 ||
                          (_shouldShowAddButton && index == _blocks.length);
                      if (isLastItem) return const SizedBox(height: 16);
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      );
                    },
                    itemBuilder: (context, index) {
                      if (_shouldShowAddButton && index == _blocks.length) {
                        return _AddBlockButton(onTap: _addBlock, isDark: isDark);
                      }
                      final block = _blocks[index];
                      return RoutineTimeBlock(
                        time: block.time,
                        notificationEnabled: block.notificationEnabled,
                        items: block.items,
                        onTimeChanged: () => _pickTime(index),
                        onNotificationToggle: () =>
                            _toggleNotification(index),
                        onDelete: () => _deleteBlock(index),
                        onAddSession: () => _navigateToSelectSession(index),
                        onReorderItems: (oldIdx, newIdx) =>
                            _onReorderItems(index, oldIdx, newIdx),
                        onDeleteItem: (itemIdx) =>
                            _onDeleteItem(index, itemIdx),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScaffold(AppLocalizations localizations) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  localizations.routine_edit_title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(Object e, AppLocalizations localizations) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(userRoutineProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Private widgets ───

class _DoneButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final String label;

  const _DoneButton({
    required this.onTap,
    required this.isDark,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AddBlockButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _AddBlockButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.grey100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Time Block',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
