# What phones send each other

Coaches, Timers, Bib Recorders and spectators pass data between phones, and
they do not all update the app at the same time. So everything one phone
sends another is a contract: today's app must read what every earlier
release sent, and must never change what it sends by accident.

Each folder here is one release: what that version sent, made from the
sample data in `test/contract/wire_samples.dart`.

| File | Sent by | To |
| --- | --- | --- |
| `race_to_timer.txt` | Coach | Timer (wirelessly) |
| `race_to_bib_recorder.txt` | Coach | Bib Recorder, and any phone by QR code |
| `times_to_coach.txt` | Timer | Coach |
| `bibs_to_coach.txt` | Bib Recorder | Coach |
| `results_to_spectators.txt` | Coach | Spectators |
| `packets.txt` | Any phone | Any phone (the transfer's own packets) |

Also part of the contract, tested in `test/contract/wire_formats_test.dart`:
the names phones announce (`getDeviceWireName`), which are also the text
before the `:` in a QR code.

## Rules

- **Never edit or delete a saved release.** Phones in the field still send
  those bytes.
- `wire_formats_test.dart` reads every saved release with today's code, and
  checks today's code still sends what the newest release saved.
- **Changing a format on purpose:** keep reading the old one, bump the
  version in `pubspec.yaml`, then save the new version's formats:

  ```sh
  flutter test test/contract/generate_wire_fixtures.dart
  ```

  The old folders stay and must keep passing.
- Changing on-screen wording never needs any of this. Keep display text
  (`getDeviceNameString`) separate from what is sent (`getDeviceWireName`).

1.1.0 sent the same formats as 1.1.1, except that 1.1.1 phones announced the
Timer as `Timer` instead of `Race Timer` (fixed after 1.1.1; both are read).
