import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/Sequences.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

Future<void> main() async {
  runApp(IBusTracker());
  BusSequences sequences = BusSequences.fromCSV(await rootBundle.loadString("assets/bus-sequences.csv"));
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

  late BusRoute? route = null;

  bool isBusStopping = false;

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

      floatingActionButton: Builder(

        builder: (context) => Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            FloatingActionButton(

              onPressed: () {

                setState(() {

                  widget.isBusStopping = !widget.isBusStopping;

                });

              },

              child: Icon(Icons.stop_sharp),

            ),

            SizedBox(
              width: 10
            ),

            FloatingActionButton(

              onPressed: () {

                Scaffold.of(context).openDrawer();

              },

              child: Icon(Icons.menu),

            )

          ],

        ),

      ),

      drawer: Container(

        width: 500,

        child: Drawer(

          child: Container(

            child: FutureBuilder(

              future: rootBundle.loadString("assets/bus-sequences.csv"),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {

                if (snapshot.hasData){

                  BusSequences sequences = BusSequences.fromCSV(snapshot.data!);

                  return CustomDropdown(

                    items: sequences.routes,
                    hintText: "Select for a route",


                    onChanged: (value) {

                      print("Set route to $value");

                      setState(() {
                        widget.route = value;
                      });

                    },

                  );

                } else {
                  return const Text("Error 404");
                }

              },


            )

          ),

        ),
      ),

      body: (widget.route == null) ? DotMatrix(

        Top: "LEA INTERCHANGE",
        Bottom: widget.isBusStopping ? "BUS STOPPING" : "${DateTime.now().hour}:${DateTime.now().minute}",

      ) : DotMatrix(

        Top: "${widget.route!.routeNumber} to ${beautifyString(widget.route!.busStops.last.stopName)}",
        Bottom: /* Current Time HH:MM */ "${DateTime.now().hour}:${DateTime.now().minute}",
      ),


    );
  }
}

const List<String> _phraseBlacklist = [

  "Bus Station",
  "Station",

];

String beautifyString(String input) {
  // Remove special characters (<>, #) and split the input string into words
  List<String> words = input.replaceAll(RegExp('[<>#]'), '').split(' ');

  // Remove empty spaces
  words = words.where((word) => word.isNotEmpty && !word.contains('/')).toList();

  // Capitalize the first letter of each word
  words = words.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).toList();

  // Join the words into a single string
  String beautifiedString = words.join(' ');

  // Remove blacklisted phrases
  for (String phrase in _phraseBlacklist) {
    beautifiedString = beautifiedString.replaceAll(phrase, '');
  }

  return beautifiedString;
}


class DotMatrix extends StatefulWidget {

  late String Top;

  late String Bottom;

  double fontSize = 60;

  DotMatrix({this.Top = "Hello", this.Bottom = "World"});

  @override
  State<DotMatrix> createState() => _DotMatrixState();
}

class _DotMatrixState extends State<DotMatrix> {




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
                  widget.Top,
                  style: TextStyle(
                    fontFamily: "IBus",
                    fontSize: widget.fontSize
                  ),
                ),

                Text(
                  widget.Bottom,
                  style: TextStyle(
                      fontFamily: "IBus",
                      fontSize: widget.fontSize
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