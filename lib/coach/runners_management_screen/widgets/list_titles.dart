import 'package:flutter/material.dart';

class ListTitles extends StatelessWidget {
  const ListTitles({super.key});

  @override
  Widget build(BuildContext context) {
    const double fontSize = 14;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text('Name',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text('Team',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text('Gr.',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text('Bib',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
          ),
        ),
      ],
    );
  }
}
