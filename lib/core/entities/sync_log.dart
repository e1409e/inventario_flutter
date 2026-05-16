class SyncLog {
  final String id;
  final DateTime lastSyncAt;
  final bool success;
  final String? errorMessage;
  final int recordsSynced;

  SyncLog({
    required this.id,
    required this.lastSyncAt,
    this.success = true,
    this.errorMessage,
    this.recordsSynced = 0,
  });
}