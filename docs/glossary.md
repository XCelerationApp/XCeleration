# Glossary

- Bib: Unique runner identifier printed on a race bib.
- Timing Datum: A single timing record (timestamp or delta) captured during a race.
- Timing Chunk: A group of timing data that may include a conflict record.
- Conflict: A mismatch or ambiguity requiring user resolution (e.g., confirm runner order).
- LWW (Last-Write-Wins): Conflict resolution policy using `updated_at` timestamps.
- UUID: Universally unique identifier; used to match records across devices and remote.
- Nearby Connections: A local peer-to-peer transport used for device discovery and data transfer.
- Advertiser/Browser: Roles in Nearby; advertiser offers a connection, browser discovers.
- Coach: App role used to manage races and results.
- Race Timer: App role used to capture finish times.
- Bib Recorder: App role used to capture bib order at finish.
