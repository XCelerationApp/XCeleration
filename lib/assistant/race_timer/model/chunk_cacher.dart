import 'package:xceleration/core/utils/logger.dart';
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
    startingPlace++;
    _encodedChunks[hashCode] = chunk.encode();
    UIChunk uiChunk =
        TimingDataConverter.convertToUIChunk(chunk, startingPlace);
    _cachedChunks[hashCode] = uiChunk;
    startingPlace = uiChunk.endingPlace;
  }

  TimingChunk? restoreLastChunkFromCache() {
    try {
      // Get the last chached chunk
      final int hashCode = _hashedChunks.removeLast();
      // update starting place
      startingPlace = _cachedChunks.remove(hashCode)!.endingPlace;
      // return decoded chunk
      return TimingChunk.decode(_encodedChunks.remove(hashCode)!);
    } catch (e) {
      Logger.e(e.toString());
      return null;
    }
  }

  void clear() {
    _encodedChunks.clear();
    _cachedChunks.clear();
    _hashedChunks.clear();
  }
}
