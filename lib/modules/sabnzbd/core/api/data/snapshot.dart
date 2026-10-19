import 'package:lunasea/modules/sabnzbd/core/api/data/history.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/queue.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/status.dart';

class SABnzbdQueueSnapshot {
  final SABnzbdStatusData status;
  final List<SABnzbdQueueData> items;
  final int total;
  final int start;
  final int limit;

  SABnzbdQueueSnapshot({
    required this.status,
    required this.items,
    required this.total,
    required this.start,
    required this.limit,
  });
}

class SABnzbdHistoryPage {
  final List<SABnzbdHistoryData> items;
  final int total;
  final int start;
  final int limit;

  SABnzbdHistoryPage({
    required this.items,
    required this.total,
    required this.start,
    required this.limit,
  });
}
