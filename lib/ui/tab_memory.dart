/// Which tab each shell was showing, kept outside the widget tree.
///
/// Exists for one reason: a theme change rebuilds the app from scratch.
///
/// The palette is static getters over a global flag, so a widget only picks up
/// a new colour when it rebuilds — and Flutter skips rebuilding a `const`
/// widget, because the instance it would rebuild with is the identical
/// canonicalised one. The only way to be sure every page repaints is to give
/// the subtree a new key and let the whole tree remount.
///
/// That works, and it would land the person back on the home tab. Toggling dark
/// mode in your profile and finding yourself on the home screen reads as the
/// app having crashed and restarted. So the shells read their opening tab from
/// here and write it back as it changes, and the remount is invisible.
///
/// Deliberately not persisted to disk. This survives a rebuild, not a restart:
/// an app opened fresh tomorrow morning should open on home, which is what a
/// parent wants at seven o'clock.
class TabMemory {
  TabMemory._();

  static int parent = 0;
  static int teacher = 0;
  static int driver = 0;

  /// Forgotten when the session ends, so the next person to sign in on this
  /// handset does not open on a tab they never chose.
  static void reset() {
    parent = 0;
    teacher = 0;
    driver = 0;
  }
}
