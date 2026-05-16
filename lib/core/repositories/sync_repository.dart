import '../entities/sync_log.dart';

abstract class SyncRepository {
  Future<void> logSyncEvent(SyncLog log);
  Future<SyncLog?> getLastSync();
}