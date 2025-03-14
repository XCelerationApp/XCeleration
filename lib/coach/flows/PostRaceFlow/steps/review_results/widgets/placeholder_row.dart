import 'package:flutter/material.dart';

/// A placeholder row to display when no actual runner data is available
class PlaceholderRow extends StatelessWidget {
  /// The position number to display
  final int position;

  const PlaceholderRow({
    super.key, 
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(position.toString()),
          ),
          Expanded(
            flex: 3,
            child: Text('Runner $position'),
          ),
          Expanded(
            flex: 2,
            child: Text('${(position * 15.5).toStringAsFixed(2)}s'),
          ),
        ],
      ),
    );
  }
}
