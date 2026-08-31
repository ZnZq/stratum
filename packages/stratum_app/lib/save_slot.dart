/// Where one save lives.
///
/// The autosave is a slot like any other so that loading, overwriting and
/// inspecting work the same for it; only the game decides which one it writes
/// on its own.
enum SaveSlot {
  auto('auto', 'Автозбереження'),
  one('1', 'Слот 1'),
  two('2', 'Слот 2'),
  three('3', 'Слот 3');

  const SaveSlot(this.key, this.label);

  final String key;
  final String label;

  String get fileName => 'stratum_save_$key.json';
}
