import 'package:flutter/material.dart';
import 'package:race_timing_app/screens/races_screen.dart';
import 'package:race_timing_app/screens/timing_screen.dart';
import 'package:race_timing_app/screens/bib_number_screen.dart';
import 'package:race_timing_app/constants.dart';

void changeRole(BuildContext context, currentRole) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      height: 150,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Coach'),
            onTap: () {
              Navigator.pop(context);
              if (currentRole == 'coach') return;
              Navigator.push(context, 
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const RacesScreen(),
                )
              );
            },
            trailing: currentRole == 'coach' ? Icon(Icons.check) : null,
          ),
          ListTile(
            leading: Icon(Icons.timer),
            title: Text('Timer'),
            onTap: () {
              Navigator.pop(context);
              if (currentRole == 'timer') return;
              Navigator.push(context, 
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const TimingScreen(),
                )
              );
            },
            trailing: currentRole == 'timer' ? Icon(Icons.check) : null,
          ),
          ListTile(
            leading: Icon(Icons.numbers),
            title: Text('Record Bib #s'),
            onTap: () {
              Navigator.pop(context);
              if (currentRole == 'bib recorder') return;
              Navigator.push(context, 
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const BibNumberScreen(),
              )
              );
            },
            trailing: currentRole == 'record bib #s' ? Icon(Icons.check) : null,
          ),
        ],
      ),
    ),
  );
}

Widget buildRoleBar(BuildContext context, currentRole, title) {
  return Container(
    padding: EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          width: 1,
          color: AppColors.darkColor,
        ),
      ),
    ),
    child: Row(
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: AppColors.navBarColor,
              ),
            ),
          ),
        ),
        Spacer(),
        ElevatedButton(
          onPressed: () => changeRole(context, currentRole),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navBarColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          ),
          child: Text(
            currentRole[0].toUpperCase() + currentRole.substring(1),
            style: TextStyle(color: AppColors.backgroundColor),
          ),
        ),
      ],
    ),
  );
}