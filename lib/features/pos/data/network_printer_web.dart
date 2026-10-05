Future<bool> sendBytesToNetworkPrinter(String ip, int port, List<int> bytes) async {
  // Web browser tidak mengizinkan raw TCP socket secara langsung
  return false;
}
