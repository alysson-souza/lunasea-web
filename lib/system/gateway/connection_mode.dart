enum LunaConnectionMode {
  direct('direct'),
  gateway('gateway');

  final String key;
  const LunaConnectionMode(this.key);

  static LunaConnectionMode fromKey(String? key) {
    switch (key) {
      case 'gateway':
        return LunaConnectionMode.gateway;
      case 'direct':
      default:
        return LunaConnectionMode.direct;
    }
  }
}
