/// Interface für die Positionsverfolgung.
abstract class TrackingController {
  /// Status-Stream des Trackings.
  Stream<TrackingState> get state;

  Future<void> start();

  Future<void> stop();
}

/// Art des Tracking-Zustands.
enum TrackingStateKind { stopped, running, error }

/// Zustand des Trackings.
///
/// - [TrackingState.stopped] / [TrackingState.running]: ohne Details.
/// - [TrackingState.error]: [message] enthält eine deutsche Fehlermeldung
///   für die UI (z. B. entzogene Standortberechtigung).
class TrackingState {
  const TrackingState.stopped()
      : kind = TrackingStateKind.stopped,
        message = null;

  const TrackingState.running()
      : kind = TrackingStateKind.running,
        message = null;

  const TrackingState.error(this.message)
      : kind = TrackingStateKind.error;

  final TrackingStateKind kind;

  /// Fehlermeldung (nur bei [TrackingStateKind.error]).
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is TrackingState && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() =>
      message == null ? 'TrackingState($kind)' : 'TrackingState($kind: $message)';
}
