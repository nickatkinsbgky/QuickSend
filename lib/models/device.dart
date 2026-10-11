class NearbyDevice {
  final String id;
  final String name;
  final String address; // IP address
  final int port;
  final String platform; // iOS, Android, etc.

  NearbyDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    this.platform = 'Unknown',
  });

  @override
  String toString() => '$name ($address:$port)';
}
