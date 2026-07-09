import 'protocol.dart';

class AdaptationRecommendation {
  const AdaptationRecommendation({
    required this.protocol,
    required this.score,
  });

  final Protocol protocol;
  final int score;
}
