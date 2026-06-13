import 'package:lunasea/database/models/service_instance.dart';

/// Wraps an item from a specific service instance, carrying source metadata
/// needed for consolidated views that merge multiple instances of the same kind.
class LunaConsolidatedItem<T> {
  final LunaServiceInstance instance;
  final T item;

  const LunaConsolidatedItem({
    required this.instance,
    required this.item,
  });
}
