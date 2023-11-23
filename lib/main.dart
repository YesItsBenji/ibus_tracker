import 'dart:async';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/Sequences.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:glass/glass.dart';
import 'package:intl/intl.dart';
import 'package:text_scroll/text_scroll.dart';

import 'IBusControlPanel.dart';

Future<void> main() async {
  runApp(IBusTracker());
  IBus.instance;
}

class IBusTracker extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(

      home: HomePage(),

      theme: ThemeData(
        brightness: Brightness.dark
      ),

    );
  }

}

class HomePage extends StatefulWidget {

  @override
  State<HomePage> createState() => HomePageState();

  late BusRoute? route = null;
}

class HomePageState extends State<HomePage> {

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

                if (!IBus.instance.isBusStopping){
                  AssetsAudioPlayer.newPlayer().open(
                    Audio("assets/audio/envirobell.mp3"),
                    autoStart: true,
                    showNotification: true
                  );
                }

                setState(() {

                  IBus.instance.isBusStopping = !IBus.instance.isBusStopping;

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

        width: 600,

        child: Drawer(

          child: true ? Container(

            margin: EdgeInsets.all(5),

            alignment: Alignment.center,

            child: Transform(

              alignment: Alignment.center,

              transform: Transform.scale(
                scale: 0.9,
              ).transform,
              child: ControlPanel(),

            ),

          ) : Column(
            children: [
              Container(

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

              ElevatedButton(

                onPressed: () {

                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => ControlPanelTestApp()));

                },

                child: Text("Open Control Panel Tester")

              )

            ],
          ),

        ),
      ),

      body: Container(
        alignment: Alignment.center,
        child: Container(

          height: 150,
          width: 900,

          padding: EdgeInsets.all(10),

          child: Transform(

            transform: Transform.translate(
              offset: Offset(0, 10)
            ).transform,

              child: DotMatrix()
          ),
          color: Colors.black,
          alignment: Alignment.center,
        ),

      ),


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



  double fontSize = 60;

  DotMatrix();

  @override
  State<DotMatrix> createState() => _DotMatrixState();
}

class _DotMatrixState extends State<DotMatrix> {

  Color textColor = Colors.orange;

  List<Shadow> textShadow = [
    Shadow(
      blurRadius: 7,
      color: Colors.orange.withOpacity(0.5),
      offset: Offset(0, 0)
    )
  ];

  late Text bottom = Text(
      getShortTime(),
      style: const TextStyle(
        fontFamily: "IBus",
        fontSize: 60,
        height: 1,
        color: Colors.orange,
      )
  );

  void refreshWidget(){

    if (IBus.instance.isBusStopping){
      setState(() {
        bottom = Text(
          "Bus Stopping",
          style: TextStyle(
            fontFamily: "IBus",
            fontSize: 60,
            height: 1,
            color: textColor,
            shadows: textShadow
          )
        );
        print ("Bus Stopping");
      });
    } else {
      setState(() {
        bottom = Text(
          getShortTime(),
          style: TextStyle(
            fontFamily: "IBus",
            fontSize: 60,
            height: 1,
            color: textColor,
            shadows: textShadow
          )
        );
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    IBus.instance.addRefresher(refreshWidget);

    bottom = Text(
      getShortTime(),
      style: TextStyle(
        fontFamily: "IBus",
        fontSize: 60,
        height: 1,
        color: textColor,
        shadows: textShadow
      )
    );


    print("object");
    Timer.periodic(Duration(seconds: 20), (timer) {
      setState(() {
        print("Refreshed time");

        if (!IBus.instance.isBusStopping){
          bottom = Text(
            getShortTime(),
            style: TextStyle(
              fontFamily: "IBus",
              fontSize: 60,
              height: 1,
              color: textColor,
              shadows: textShadow
            )
          );
        } else {
          bottom = Text(
            "Bus Stopping",
            style: TextStyle(
              fontFamily: "IBus",
              fontSize: 60,
              height: 1,
              color: textColor,
              shadows: textShadow
            )
          );
          print ("Bus Stopping");
        }


      });
    });
  }

  @override
  Widget build(BuildContext context) {



    // TODO: implement build
    return Container(

      alignment: Alignment.center,

      child: Stack(

        children: [

          Column(

            children: [

              TextScroll(
                IBus.instance.CurrentMessage.length <= 40 ? "${IBus.instance.CurrentMessage}" : "${IBus.instance.CurrentMessage}                                                                           ",
                style: TextStyle(
                  fontFamily: "IBus",
                  fontSize: widget.fontSize,
                  height: 1,
                  color: textColor,
                  shadows: textShadow
                ),
                mode: TextScrollMode.endless,
                velocity: Velocity(pixelsPerSecond: Offset(200, 0)),
              ),

              SizedBox(
                height: 2,
              ),

              bottom

            ],

          )

        ],

      )

    );
  }
}