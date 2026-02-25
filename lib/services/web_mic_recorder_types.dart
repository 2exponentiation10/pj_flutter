class WebMicLiveStats {
  final double levelNorm;
  final double pitchHz;

  const WebMicLiveStats({
    required this.levelNorm,
    required this.pitchHz,
  });
}

typedef OnWebMicLiveStats = void Function(WebMicLiveStats stats);
