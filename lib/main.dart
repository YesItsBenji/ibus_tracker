import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/Sequences.dart';

void main() {

  BusSequences sequences = BusSequences.fromCSV(File("C:\\Users\\bench\\Downloads\\bus-sequences.csv"));

  runApp(IBusTracker());
}

class IBusTracker extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(

      home: HomePage()

    );
  }

}

class HomePage extends StatefulWidget {

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();


    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);

  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(

      body: DotMatrix(),

    );
  }
}


class DotMatrix extends StatelessWidget {

  String Top = "SL1 to Walthamstow Central";

  String Bottom = "Bus Stopping";

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(

      alignment: Alignment.center,

      child: FittedBox(

        fit: BoxFit.fill,

        child: Stack(

          children: [

            Column(

              children: [

                Text(
                  Top,
                  style: TextStyle(
                    fontFamily: "DotMatrix",
                    fontSize: 60
                  ),
                ),

                Text(
                  Bottom,
                  style: TextStyle(
                      fontFamily: "DotMatrix",
                      fontSize: 60
                  ),
                )

              ],

            )

          ],

        ),
      )

    );
  }


}