import 'package:flutter/material.dart';

import 'internal_review/performance_tracking/tracking_review_screen.dart';

/// Synthetic-only internal review; unreachable from production entrypoints.
/// flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4196
///   --no-pub -t lib/main_performance_tracking_review_preview.dart
void main() => runApp(const TrackingReviewApp());
