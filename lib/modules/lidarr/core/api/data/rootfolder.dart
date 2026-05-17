class LidarrRootFolder {
  int? id;
  String? path;
  int? freeSpace;

  factory LidarrRootFolder.empty() =>
      LidarrRootFolder(id: -1, path: '', freeSpace: 0);

  LidarrRootFolder({
    required this.id,
    required this.path,
    required this.freeSpace,
  });
}
