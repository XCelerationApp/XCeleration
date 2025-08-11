import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'ui_record.dart';
import '../utils/timing_data_converter.dart';

class ChunkCacher {
  // Tracks the hash codes of cached chunks and the order in which they were cached
  final List<int> _hashedChunks = [];
  // Encode chunks for later uncaching
  final Map<int, String> _encodedChunks = {};

  // Main caching tracker
  final Map<int, UIChunk> _cachedChunks = {};

  int startingPlace = 0;

  bool get isEmpty => _hashedChunks.isEmpty;

  List<UIChunk> get cachedChunks =>
      _hashedChunks.map((hash) => _cachedChunks[hash]!).toList();

  void cacheChunk(TimingChunk chunk) {
    final hashCode = chunk.hashCode;
    if (_encodedChunks.containsKey(hashCode)) {
      throw Exception('Chunk is already cached');
    }
    // Use current startingPlace for this chunk, then update to ending place
    final int chunkStartingPlace = startingPlace == 0 ? 1 : startingPlace;
    _encodedChunks[hashCode] = chunk.encode();
    UIChunk uiChunk =
        TimingDataConverter.convertToUIChunk(chunk, chunkStartingPlace);
    _cachedChunks[hashCode] = uiChunk;
    _hashedChunks.add(hashCode);
    startingPlace = uiChunk.endingPlace;
  }

  TimingChunk? restoreLastChunkFromCache() {
    // Guard against empty cache to avoid RangeError on removeLast
    if (_hashedChunks.isEmpty) {
      return null;
    }
    try {
      // Get the last cached chunk
      final int hashCode = _hashedChunks.removeLast();
      // Remove from caches
      _cachedChunks.remove(hashCode);
      final String encodedChunk = _encodedChunks.remove(hashCode)!;

      // Update starting place to the end of the last remaining cached chunk
      if (_hashedChunks.isNotEmpty) {
        final int lastRemainingHash = _hashedChunks.last;
        startingPlace = _cachedChunks[lastRemainingHash]!.endingPlace;
      } else {
        startingPlace = 0; // Reset if no chunks remain
      }

      // return decoded chunk
      final TimingChunk decoded = TimingChunk.decode(encodedChunk);
      return decoded;
    } catch (e) {
      return null;
    }
  }

  void clear() {
    _encodedChunks.clear();
    _cachedChunks.clear();
    _hashedChunks.clear();
    startingPlace = 0;
  }
}
