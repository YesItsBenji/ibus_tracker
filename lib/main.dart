import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/Sequences.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:glass/glass.dart';
import 'package:intl/intl.dart';

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

              onPressed: () async {

                if (!widget.isBusStopping){
                  AssetsAudioPlayer.newPlayer().open(
                      Audio("assets/audio/envirobell.mp3"),
                      autoStart: true,
                      showNotification: true,
                      volume: 1000
                  );
                }

                setState(() {

                  widget.isBusStopping = !widget.isBusStopping;

                });



              },

              child: const Icon(Icons.stop_sharp),

            ),

            const SizedBox(
              width: 10
            ),

            FloatingActionButton(

              onPressed: () {

                Scaffold.of(context).openDrawer();

              },

              child: const Icon(Icons.menu),

            )

          ],

        ),

      ),

      drawer: Container(

        width: 584,

        child: Drawer(

          child: Container(

            child: true ? IBusPanel() : FutureBuilder(

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
        Bottom: widget.isBusStopping ? "BUS STOPPING" : getShortTime(),

      ) : DotMatrix(

        Top: "${widget.route!.routeNumber} to ${beautifyString(widget.route!.busStops.last.stopName)}",
        Bottom: /* Current Time HH:MM */ "${DateTime.now().hour}:${DateTime.now().minute}",
      ),


    );
  }
}

class IBusPanel extends StatelessWidget {

    @override
    Widget build(BuildContext context) {

      return Container(

        alignment: Alignment.center,

        child: Container(

          height: 400,


          margin: const EdgeInsets.all(20),

          // color: Colors.lightGreen.shade100,

          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            color: Colors.lightGreen.shade100
          ),

          child: Row(

            children: [

              Container(

                width: 241,

                child: Column(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(10),

                      width: double.infinity,

                      child: Column(

                        children: [

                          const Padding(
                            padding: EdgeInsets.only(
                              top: 15,
                              bottom: 10
                            ),
                            child: Text(
                              "--:--",
                              style: TextStyle(
                                fontSize: 40,
                                height: 1,
                                fontFamily: "LCD"

                              ),
                            ),
                          ),

                          const Row(
                            children: [
                              Text(
                                "234/123",

                                textAlign: TextAlign.start,

                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1,
                                  fontFamily: "LCD"
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Text(
                                getLongTime(),

                                textAlign: TextAlign.start,

                                style: const TextStyle(
                                  fontSize: 20,
                                  fontFamily: "LCD"
                                ),
                              ),
                            ],
                          ),

                        ],

                      )

                    ),



                    Container(
                      height: 3,
                      color: Colors.black,
                    ),

                  ],

                ),

              ),

              Container(
                width: 3,
                color: Colors.black,
              ),

              Column(

                children: [

                  Container(

                    height: 40,
                    width: 300,
                    
                    child: Container(

                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(9),
                        ),
                        color: Colors.black,
                      ),
                      


                      margin: EdgeInsets.all(3),

                    ),

                  ),

                  Container(
                    height: 3,
                    width: 300,
                    color: Colors.black,
                  ),

                  Container(

                    padding: EdgeInsets.all(3),
                    
                    height: 70,
                    width: 300,

                    child: Container(

                      color: Colors.black,

                      padding: EdgeInsets.all(8),

                      child: Text(
                        "Walthamstow Bus Station",
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: "LCD",
                          color: Colors.lightGreen.shade100
                        ),
                      ),

                    ),

                  ),

                  Container(
                    height: 3,
                    width: 300,
                    color: Colors.black,
                  ),

                  Container(

                    padding: EdgeInsets.all(3),

                    height: 70,
                    width: 300,

                    child: Container(

                      color: Colors.black,

                      padding: EdgeInsets.all(8),

                      child: Text(
                        "Walthamstow Market",
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: "LCD",
                            color: Colors.lightGreen.shade100
                        ),
                      ),

                    ),

                  ),

                  Container(
                    height: 3,
                    width: 300,
                    color: Colors.black,
                  ),

                  Container(

                    padding: EdgeInsets.all(3),

                    height: 70,
                    width: 300,

                    child: Container(

                      color: Colors.black,

                      padding: EdgeInsets.all(8),

                      child: Text(
                        "Jewel Road",
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: "LCD",
                            color: Colors.lightGreen.shade100
                        ),
                      ),

                    ),

                  ),

                  Container(
                    height: 3,
                    width: 300,
                    color: Colors.black,
                  ),

                  Container(

                    padding: EdgeInsets.all(3),

                    height: 70,
                    width: 300,

                    child: Container(

                      color: Colors.black,

                      padding: EdgeInsets.all(8),

                      child: Text(
                        "Forest Road / Bell Corner",
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: "LCD",
                            color: Colors.lightGreen.shade100
                        ),
                      ),

                    ),

                  ),

                  // Container(
                  //
                  //   color: Colors.black,
                  //
                  //   height: 80,
                  //   width: 300,
                  //
                  //
                  //
                  //   child: Container(
                  //
                  //
                  //
                  //     child: Text(
                  //       "NEW CROSS BUS GARAGE",
                  //       style: TextStyle(
                  //         fontSize: 20,
                  //         fontFamily: "LCD",
                  //         color: Colors.lightGreen.shade100
                  //       ),
                  //
                  //     ),
                  //   ),
                  //
                  // )

                ],

              )

            ],

          )

        ).asGlass(),
      );

    }
}

const List<String> _phraseBlacklist = [

  "Bus Station",

];

String getShortTime(){

  // return the HH:MM with AM and PM and make sure that the hour is 12 hour format and it always double digits. IE 01, 02 etc
  DateTime now = DateTime.now();
  String formatted = DateFormat('hh:mm a').format(now);
  return formatted;
}

String getLongTime() {
  DateTime now = DateTime.now();
  String formattedTime = DateFormat('HH:mm:ss  dd.MM.yyyy').format(now);
  return formattedTime;
}

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