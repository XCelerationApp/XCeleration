# Changes from flutter_nearby_connections 1.1.2

Copied from pub.dev (BSD 2-Clause, see LICENSE) with one change:

- iOS: `stateChanged` and `messageReceived` call the platform channel on the
  main thread. MultipeerConnectivity reports on background queues, and Flutter
  can drop a message or crash when a channel is used off the main thread.

The example app, tests and screenshots were left out.
