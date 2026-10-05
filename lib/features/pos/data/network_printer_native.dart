import 'dart:io';

Future<bool> sendBytesToNetworkPrinter(String ip, int port, List<int> bytes) async {
  try {
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
    socket.add(bytes);
    await socket.flush();
    await socket.close();
    return true;
  } catch (e) {
    return false;
  }
}
