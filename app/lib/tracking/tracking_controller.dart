/// Interface für die Positionsverfolgung.
///
/// Die eigentliche Hintergrund-Verfolgung (Foreground Service, Sampler,
/// Batch-Upload) ist ein Folge-Task; Screens hängen nur an diesem Interface.
abstract class TrackingController {
  /// Status-Stream des Trackings.
  Stream<TrackingState> get state;

  Future<void> start();

  Future<void> stop();
}

/// Zustände des Trackings.
enum TrackingState { stopped, running, error }
