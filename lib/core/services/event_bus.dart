import 'dart:async';

/// A typed event that can be published on the [EventBus]
class Event {
  /// The unique type name for this event
  final String type;

  /// Optional data payload associated with this event
  final dynamic data;

  /// Constructor
  Event(this.type, [this.data]);

  @override
  String toString() => 'Event($type${data != null ? ', $data' : ''})';
}

/// A simple event bus implementation using streams
///
/// Allows components to communicate without having direct dependencies on each other.
/// Components can publish events and subscribe to specific event types.
class EventBus {
  /// Singleton instance
  static final EventBus _instance = EventBus._internal();

  /// Getter for the singleton instance
  static EventBus get instance => _instance;

  /// Private constructor
  EventBus._internal();

  /// Stream controller for the event bus
  final StreamController<Event> _eventController =
      StreamController<Event>.broadcast();

  /// Stream of events
  Stream<Event> get stream => _eventController.stream;

  /// Publish an event to the event bus
  void publish(Event event) {
    _eventController.add(event);
  }

  /// Publish an event by type and optional data
  void fire(String eventType, [dynamic data]) {
    publish(Event(eventType, data));
  }

  /// Subscribe to all events
  StreamSubscription<Event> listen(void Function(Event event) onData) {
    return stream.listen(onData);
  }

  /// Subscribe to a specific event type
  StreamSubscription<Event> on<T>(
      String eventType, void Function(Event event) onData) {
    return stream.where((event) => event.type == eventType).listen(onData);
  }

  /// Dispose of the event bus
  void dispose() {
    _eventController.close();
  }
}

/// Predefined event types used throughout the app
class EventTypes {
  // Race events
  static const String raceCreated = 'race.created';
  static const String raceUpdated = 'race.updated';
  static const String raceDeleted = 'race.deleted';
  static const String raceFlowStateChanged = 'race.flowState.changed';

  // Results events
  static const String resultsUpdated = 'results.updated';

  // Runner events
  static const String runnerAdded = 'runner.added';
  static const String runnerRemoved = 'runner.removed';
  static const String runnerUpdated = 'runner.updated';

  // Navigation events
  static const String tabChanged = 'tab.changed';
  static const String screenChanged = 'screen.changed';

  // Device connection events
  static const String deviceConnected = 'device.connected';
  static const String deviceDisconnected = 'device.disconnected';
  static const String dataReceived = 'device.dataReceived';
}
