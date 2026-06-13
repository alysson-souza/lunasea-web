import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';

/// Presents a bottom sheet listing service instances and returns the
/// selected instance's [id], or `null` when the sheet is dismissed without a
/// selection.
///
/// When [instances] contains exactly one entry the sheet is NOT shown and that
/// entry's [id] is returned immediately, making single-instance setups
/// seamless.
///
/// Typical usage in a consolidated view:
/// ```dart
/// final id = await LunaInstancePickerSheet().show(instances: instances);
/// if (id != null) SomeRoutes.ACTION.goInstance(instanceId: id);
/// ```
class LunaInstancePickerSheet {
  Future<String?> show({required List<LunaServiceInstance> instances}) async {
    if (instances.isEmpty) return null;
    if (instances.length == 1) return instances.first.id;
    final result = await LunaBottomModalSheet().show(
      builder: (context) => _InstancePickerContent(instances: instances),
    );
    return result as String?;
  }
}

class _InstancePickerContent extends StatelessWidget {
  final List<LunaServiceInstance> instances;

  const _InstancePickerContent({required this.instances});

  @override
  Widget build(BuildContext context) {
    return LunaListViewModal(
      children: [
        LunaHeader(text: 'lunasea.SelectInstance'.tr()),
        for (final instance in instances)
          LunaBlock(
            title: instance.displayName,
            trailing: const LunaIconButton.arrow(),
            onTap: () => Navigator.of(context).pop(instance.id),
          ),
      ],
    );
  }
}
