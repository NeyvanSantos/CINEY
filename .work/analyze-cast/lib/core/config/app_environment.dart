class AppEnvironment {
  static bool isTv = false;

  static String assetPath(String path) {
    return isTv ? 'packages/cinemax/$path' : path;
  }
}
