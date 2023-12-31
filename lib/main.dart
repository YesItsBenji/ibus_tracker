import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/bus_datasets.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'IBusControlPanel.dart';
import 'IBusDotMatrix.dart';

Future<void> main() async {
  runApp(IBusTracker());
  IBus();
}

class IBusTracker extends StatefulWidget {

  @override
  State<IBusTracker> createState() => _IBusTrackerState();
}

class _IBusTrackerState extends State<IBusTracker> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();


  }

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

    Permission.storage.request();
    Permission.camera.request();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    // Hide the notification bar and the navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);


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



                IBus().clearAudioQueue();
                IBus().isPlayingAudio = false;

                if (kDebugMode){

                  String pth = ("${IBus().announcementDirectory}/${IBus().nearestBusStop!.getAudioFileName()}");

                  Source audio = DeviceFileSource(pth);

                  // IBus().queueAnnouncement(IBusAnnouncementEntry(
                  //     message: "Next stop: ${IBus().nearestBusStop!.stopName}",
                  //     audio: [audio]
                  // ));

                }





              },

              child: const Icon(Icons.bug_report),

            ),

            const SizedBox(
                width: 10
            ),

            FloatingActionButton(

              onPressed: () async {

                if (!IBus().isBusStopping){

                  AudioPlayer().play(AssetSource("assets/audio/envirobell.mp3"));

                  Future.delayed(Duration(seconds: 3), () {
                    IBus().announceDestination(withAudio: true);
                    IBus().isBusStopping = false;
                  });

                }

                IBus().isBusStopping = !IBus().isBusStopping;




              },

              child: const Icon(Icons.notifications_active),

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

        color: Colors.black,

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

// const List<String> _phraseBlacklist = [
//
//   "Bus Station",
//
// ];
//
// const Map<String, String> _phraseWhitelist = {
//
//   "ctr": "Centre",
//   "stn": "Station",
//   "tn": "Town",
//
// };
//
// String getShortTime(){
//
//   // return the HH:MM with AM and PM and make sure that the hour is 12 hour format and it always double digits. IE 01, 02 etc
//   DateTime now = DateTime.now();
//   String formatted = DateFormat('hh:mm a').format(now);
//   return formatted;
// }
//
// String getLongTime() {
//   DateTime now = DateTime.now();
//   String formattedTime = DateFormat('HH:mm:ss  dd.MM.yyyy').format(now);
//   return formattedTime;
// }
//
//
//
// String beautifyString(String input) {
//   // Remove special characters (<>, #) and split the input string into words
//   List<String> words = input.replaceAll(RegExp('[<>#]'), '').split(' ');
//
//   // Replace whitelisted phrases, whether they match case or not
//   for (String phrase in _phraseWhitelist.keys) {
//     words = words.map((word) => word.replaceAll(RegExp(phrase, caseSensitive: false), _phraseWhitelist[phrase]!)).toList();
//   }
//
//   // Remove parentheses and their contents
//   words = words.map((word) => word.replaceAll(RegExp(r'\(.*\)'), '')).toList();
//
//   // Remove Square Brackets and their contents
//   words = words.map((word) => word.replaceAll(RegExp(r'\[.*\]'), '')).toList();
//
//   // Remove empty spaces
//   words = words.where((word) => word.isNotEmpty).toList();
//
//   // Remove lol
//   words = words.where((word) => word != 'Lol').toList();
//
//   // Capitalize the first letter of each word
//   words = words.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).toList();
//
//   // Join the words into a single string
//   String beautifiedString = words.join(' ');
//
//   return beautifiedString;
// }
//
// String beautifyStringWithBlacklist(String input) {
//   // Remove special characters (<>, #) and split the input string into words
//   List<String> words = input.replaceAll(RegExp('[<>#]'), '').split(' ');
//
//   // Replace whitelisted phrases
//   for (String phrase in _phraseWhitelist.keys) {
//     words = words.map((word) => word.replaceAll(phrase, _phraseWhitelist[phrase]!)).toList();
//   }
//
//   // Remove empty spaces
//   words = words.where((word) => word.isNotEmpty && !word.contains('/')).toList();
//
//   // Remove parentheses and their contents
//   words = words.map((word) => word.replaceAll(RegExp(r'\(.*\)'), '')).toList();
//
//   // Remove Square Brackets and their contents
//   words = words.map((word) => word.replaceAll(RegExp(r'\[.*\]'), '')).toList();
//
//   // Capitalize the first letter of each word
//   words = words.map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase()).toList();
//
//   // Join the words into a single string
//   String beautifiedString = words.join(' ');
//
//   // Remove blacklisted phrases
//   for (String phrase in _phraseBlacklist) {
//     beautifiedString = beautifiedString.replaceAll(phrase, '');
//   }
//
//   return beautifiedString;
// }