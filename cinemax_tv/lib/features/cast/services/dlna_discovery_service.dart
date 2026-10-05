import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import '../models/cast_device.dart';

class DlnaDiscoveryService {
  static final DlnaDiscoveryService instance = DlnaDiscoveryService._();
  DlnaDiscoveryService._();

  final List<CastDevice> _discoveredDevices = [];
  List<CastDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  RawDatagramSocket? _socket;
  Timer? _searchTimer;
  Timer? _timeoutTimer;
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));

  final _devicesStreamController = StreamController<List<CastDevice>>.broadcast();
  Stream<List<CastDevice>> get devicesStream => _devicesStreamController.stream;

  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 10)}) async {
    _discoveredDevices.clear();
    _notifyDevices();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 4;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _parseSsdpResponse(datagram);
          }
        }
      });

      _sendMSearch();
      _searchTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendMSearch());

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(timeout, () {
        stopDiscovery();
      });
    } catch (_) {}
  }

  void stopDiscovery() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _searchTimer?.cancel();
    _searchTimer = null;
    _socket?.close();
    _socket = null;
  }

  void _sendMSearch() {
    if (_socket == null) return;

    final targetAddress = InternetAddress('239.255.255.250');
    const port = 1900;

    final searchTargets = [
      'urn:schemas-upnp-org:device:MediaRenderer:1',
      'urn:schemas-upnp-org:service:AVTransport:1',
      'urn:dial-multiscreen-org:service:dial:1',
      'roku:ecp',
      'ssdp:all',
    ];

    for (final st in searchTargets) {
      final message =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: $st\r\n'
          '\r\n';

      try {
        _socket!.send(utf8.encode(message), targetAddress, port);
      } catch (_) {}
    }
  }

  void _parseSsdpResponse(Datagram datagram) {
    try {
      final response = utf8.decode(datagram.data);
      final lines = response.split('\r\n');
      final headers = <String, String>{};

      for (var line in lines) {
        final colonIndex = line.indexOf(':');
        if (colonIndex != -1) {
          final key = line.substring(0, colonIndex).trim().toUpperCase();
          final val = line.substring(colonIndex + 1).trim();
          headers[key] = val;
        }
      }

      final server = headers['SERVER'] ?? '';
      final location = headers['LOCATION'] ?? '';
      final usn = headers['USN'] ?? datagram.address.address;
      final ip = datagram.address.address;
      final port = datagram.port;

      if (_discoveredDevices.any((d) => d.ipAddress == ip)) return;

      CastDeviceType type = CastDeviceType.dlna;
      String name = 'Smart TV';

      final serverUpper = server.toUpperCase();
      if (serverUpper.contains('SAMSUNG') || serverUpper.contains('TIZEN')) {
        type = CastDeviceType.samsung;
        name = 'Samsung Smart TV';
      } else if (serverUpper.contains('LG') || serverUpper.contains('WEBOS')) {
        type = CastDeviceType.lg;
        name = 'LG webOS TV';
      } else if (serverUpper.contains('ROKU')) {
        type = CastDeviceType.roku;
        name = 'Roku TV';
      } else if (serverUpper.contains('AFT') || serverUpper.contains('FIRETV')) {
        type = CastDeviceType.fireTv;
        name = 'Amazon Fire TV';
      } else if (headers['ST']?.contains('dial') == true || serverUpper.contains('CHROMECAST')) {
        type = CastDeviceType.chromecast;
        name = 'Chromecast / Google TV';
      }

      final device = CastDevice(
        id: usn,
        name: name,
        type: type,
        ipAddress: ip,
        port: port,
        location: location,
      );

      _discoveredDevices.add(device);
      _notifyDevices();

      // Busca friendlyName real da TV via XML
      if (location.isNotEmpty) {
        _fetchDeviceFriendlyName(device);
      }
    } catch (_) {}
  }

  Future<void> _fetchDeviceFriendlyName(CastDevice device) async {
    if (device.location == null || device.location!.isEmpty) return;

    try {
      final res = await _dio.get<String>(device.location!);
      if (res.data != null) {
        final xml = res.data!;
        // Extrai <friendlyName>...</friendlyName>
        final match = RegExp(r'<friendlyName>([^<]+)</friendlyName>', caseSensitive: false).firstMatch(xml);
        if (match != null && match.group(1) != null) {
          final friendlyName = match.group(1)!.trim();
          final index = _discoveredDevices.indexWhere((d) => d.id == device.id);
          if (index != -1) {
            _discoveredDevices[index] = CastDevice(
              id: device.id,
              name: friendlyName,
              type: device.type,
              ipAddress: device.ipAddress,
              port: device.port,
              location: device.location,
            );
            _notifyDevices();
          }
        }
      }
    } catch (_) {}
  }

  void _notifyDevices() {
    _devicesStreamController.add(List.unmodifiable(_discoveredDevices));
  }
}
