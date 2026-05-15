import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/modules.dart';

enum BIOSPreferences<T> with BackendPreference<T> {
  BOOT_MODULE<LunaModule>(LunaModule.DASHBOARD),
  FIRST_BOOT<bool>(true);

  @override
  BackendPreferenceGroup get table => BackendPreferenceGroup.bios;

  @override
  final T fallback;

  const BIOSPreferences(this.fallback);

  @override
  dynamic export() {
    BIOSPreferences db = this;
    switch (db) {
      case BIOSPreferences.BOOT_MODULE:
        return BIOSPreferences.BOOT_MODULE.read().key;
      default:
        return super.export();
    }
  }

  @override
  void import(dynamic value) {
    BIOSPreferences db = this;
    dynamic result;

    switch (db) {
      case BIOSPreferences.BOOT_MODULE:
        result = LunaModule.fromKey(value.toString());
        break;
      default:
        result = value;
        break;
    }

    return super.import(result);
  }
}
