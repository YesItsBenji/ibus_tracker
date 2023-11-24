
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ibus_tracker/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Sequences.dart';

Future<void> main() async {
  runApp(ControlPanelTestApp());
}

class ControlPanelTestApp extends StatefulWidget {



  @override
  State<ControlPanelTestApp> createState() => _ControlPanelTestAppState();
}

class _ControlPanelTestAppState extends State<ControlPanelTestApp> {

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
    return MaterialApp(

      home: Scaffold(

        body: Container(

          alignment: Alignment.center,

          margin: EdgeInsets.all(10),
          
          child: ControlPanel()

        ),

      )

    );
  }
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

class IBusLoginInformation {

  BusGarage? busGarage = null;

  BusRoute? busRoute = null;

  int routeVariant = -1;

  int operatingNumber = -1;

  int tripNumber = -1;

}

// IBus singleton
class IBus {

  static IBus? _instance;

  static IBus get instance {
    if (_instance == null){
      _instance = IBus();
      _instance?.announcementTimer();
    }

    return _instance!;
  }

  String announcementDirectory = "";

  IBus(){

    AudioCache.instance.prefix = "";



    SharedPreferences.getInstance().then((pref) {

      if (pref.containsKey("announcementDirectory")){
        announcementDirectory = pref.getString("announcementDirectory")!;
      } else {
        FilePicker.platform.getDirectoryPath().then((value) {
          announcementDirectory = value!;

          pref.setString("announcementDirectory", announcementDirectory);
        });
      }


    });


    rootBundle.loadString("assets/garage_codes.csv").then((value) {
      BusGarages.fromCSV(value);
      refresh();
    });


    rootBundle.loadString("assets/bus-sequences.csv").then((value) {
      BusSequences.fromCSV(value);
      refresh();
    });

    rootBundle.loadString("assets/bus-stops.csv").then((value) async {
      BusStops.fromCSV(value);

      // get device location
      Position devicePos = await _determinePosition();

      BusStop? nearestStop = BusStops().getNearestBusStop(devicePos.latitude, devicePos.longitude);

      if (nearestStop != nearestBusStop){
        nearestBusStop = nearestStop;

        CurrentMessage = beautifyString(nearestBusStop!.stopName);

        refresh();
      }

      refresh();
    });

  }

  // Audio loop queue
  List<IBusAnnouncementEntry> _audioQueue = [];
  bool isPlayingAudio = false;

  void clearAudioQueue(){
    _audioQueue.clear();
  }

  bool isNearestStopComputing = false;

  Timer announcementTimer() => Timer.periodic(
    Duration(milliseconds: 50),
    (Timer t) async {


      // print("Timer tick");
      print("Audio queue length: ${_audioQueue.length}");

      if (!isNearestStopComputing){
        isNearestStopComputing = true;

        // print("Computing nearest stop...");

        Position devicePos = await _determinePosition();

        BusStop? nearestStop = BusStops().getNearestBusStop(devicePos.latitude, devicePos.longitude);

        if (nearestStop != null && (nearestStop != nearestBusStop || nearestBusStop == null)){
          nearestBusStop = nearestStop;

          CurrentMessage = beautifyString(nearestBusStop!.stopName);

          print("Nearest stop: ${nearestBusStop!.stopName} updated!");


          String pth = ("${announcementDirectory}/${nearestStop.getAudioFileName()}");

          Source audio = DeviceFileSource(pth);

          // check if file exists
          if (!await File(pth).exists()){
            audio = AssetSource("assets/audio/nextstopclosed.wav");
          }



          print("Audio file: ${pth}");

          queueAnnouncement(IBusAnnouncementEntry(
            message: beautifyString(nearestBusStop!.stopName),
            audio: audio
          ));

          refresh();
        }

        // print("Done computing nearest stop");

        isNearestStopComputing = false;
      }


      if (_audioQueue.isNotEmpty && !isPlayingAudio){
        isPlayingAudio = true;

        print("Playing: ${_audioQueue[0].message}");

        CurrentMessage = _audioQueue[0].message;

        refresh();

        AudioPlayer player = AudioPlayer();

        IBusAnnouncementEntry entry = _audioQueue[0];

        player.play(
            entry.audio!,
        );

        player.onPlayerComplete.listen((event) {
          // player.stop();

          // If there is nothing else in the queue to play, then leave the announcement on the screen for 5 seconds and then change it back to the bus stop name.
          // If there is something else in the queue, then play the next announcement immediately.
          if (_audioQueue.length == 1){

            int QueueLength = _audioQueue.length;

            Future.delayed(Duration(seconds: 2), () {
              if (QueueLength == 1){
                CurrentMessage = beautifyString(nearestBusStop!.stopName);
                refresh();
              }
            });
          }

          _audioQueue.removeAt(0);
          isPlayingAudio = false;
          print("Popped audio queue");
        });



      }

    }
  );

  String CurrentMessage = "WALTHAMSTOW AVENUE";

  void queueAnnouncement(IBusAnnouncementEntry announcementEntry){

    _audioQueue.add(announcementEntry);

  }

  List<Function()> _refreshFunctions = [];

  void addRefresher(Function() refreshFunction){
    _refreshFunctions.add(refreshFunction);
    print("Added refresh function");
    refreshFunction();
  }

  void refresh(){
    _refreshFunctions.forEach((element) {
      element();
    });
  }

  bool _isBusStopping = false;

  // refresh on isBusStopping set
  set isBusStopping(bool value){
    _isBusStopping = value;
    refresh();
  }

  bool get isBusStopping => _isBusStopping;

  IBusLoginInformation? loginInformation;

  BusStop? nearestBusStop;

}

class IBusAnnouncementEntry {

  final String message;

  final Source? audio;

  IBusAnnouncementEntry({
    this.message = "*** NO MESSAGE ***",
    this.audio
  });

}

class ControlPanel extends StatelessWidget {


  String rightTitle = "";

  ControlPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(

      height: 384,

      padding: EdgeInsets.all(2),

      color: Colors.black,

      child: Container(

        color: Colors.lightGreen.shade100,

        child: IntrinsicHeight(
          child: Row(
          
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
          
            children: [
          
              Column(
                children: [
                  Container(

                    width: 225,


                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Container(

                          padding: EdgeInsets.all(10),

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              Container(

                                alignment: Alignment.center,

                                width: double.infinity,

                                child: const Text(
                                  "--:--",
                                  style: TextStyle(
                                    fontFamily: "LCD",
                                    color: Colors.black,
                                    fontSize: 40,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 60
                                      )
                                    ]
                                  ),
                                ),
                              ),

                              Text(
                                "121/234",
                                style: TextStyle(
                                  fontFamily: "LCD",
                                  color: Colors.black,
                                  fontSize: 25,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 60
                                      )
                                    ]
                                ),

                              ),

                              Text(
                                "00:00:00  00.00.0000",
                                style: TextStyle(
                                  fontFamily: "LCD",
                                  color: Colors.black,
                                  fontSize: 17,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 60
                                      )
                                    ]
                                ),
                              ),

                            ],

                          )

                        ),

                        Container(

                          color: Colors.black,

                          height: 2,

                        )

                      ],

                    ),

                  ),
                ],
              ),
          
              Container(
          
                color: Colors.black,
          
                width: 2,
          
              ),
          
          
          
              Container(

                alignment: Alignment.topCenter,
          
                width: 300,
          
                child: Column(
          
                  mainAxisSize: MainAxisSize.min,

          
                  children: [
          
                    Container(
          
                      color: Colors.black,
          
                      width: double.infinity,
          
                      height: 30,
          
                      margin: EdgeInsets.all(2),
          
                    ),
          
                    Container(
          
                      color: Colors.black,
          
                      height: 2,
          
                    ),


                    IBus.instance.loginInformation == null ? ControlPanelLogin() : _staticAnnouncer(),


          
                  ],
          
                )
          
              )
          
            ],
          
          ),
        ),

      ),
    );
  }
}

class ControlPanelLogin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(



    );
  }



}

class _staticAnnouncer extends StatefulWidget {

  HomePageState? homePageState;

  _staticAnnouncer({
    super.key,
    this.homePageState
  });

  @override
  State<_staticAnnouncer> createState() => _staticAnnouncerState();
}

class _staticAnnouncerState extends State<_staticAnnouncer> {
  int pageIndex = 0;

  List<Widget> initPages() => [

    Column(

      children: [

        ControlPanelRightEntry(
          label: "Driver Change",
          index: 1,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
              message: "Driver Change",
              audio: AssetSource("assets/audio/driverchange.mp3")
            ));

          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "No Standing Upr Deck",
          index: 2,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "No standing on upper deck",
                audio: AssetSource("assets/audio/nostanding.mp3")
            ));

          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Face Covering",
          index: 3,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Please wear a face covering!",
                audio: AssetSource("assets/audio/facecovering.mp3")
            ));

          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Seats Upstairs",
          index: 4,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Seats are available upstairs",
                audio: AssetSource("assets/audio/seatsupstairs.mp3")
            ));
          },
        ),

      ],

    ),

    Column(

      children: [

        ControlPanelRightEntry(
          label: "Bus Terminates Here",
          index: 5,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Bus terminates here. Please take your belongings with you",
                audio: AssetSource("assets/audio/busterminateshere.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Bus On Diversion",
          index: 6,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Bus on diversion. Please listen for further announcements",
                audio: AssetSource("assets/audio/busondiversion.mp3")
            ));

          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Destination Change",
          index: 7,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Destination Changed - please listen for further instructions",
                audio: AssetSource("assets/audio/destinationchange.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Wheelchair Space",
          index: 8,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Wheelchair space requested",
                audio: AssetSource("assets/audio/wheelchairspace1.mp3")
            ));
          },
        ),

      ],

    ),

    Column(

      children: [

        ControlPanelRightEntry(
          label: "Move Down The Bus",
          index: 9,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Please move down the bus",
                audio: AssetSource("assets/audio/movedownthebus.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Next Stop Closed",
          index: 10,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "The next bus stop is closed",
                audio: AssetSource("assets/audio/nextstopclosed.wav")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "CCTV In Operation",
          index: 11,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "CCTV is in operation on this bus",
                audio: AssetSource("assets/audio/cctvoperation.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Safe Door Opening",
          index: 12,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Driver will open the doors when it is safe to do so",
                audio: AssetSource("assets/audio/safedooropening.mp3")
            ));
          },
        ),

      ],

    ),

    Column(

      children: [

        ControlPanelRightEntry(
          label: "Buggy Safety",
          index: 13,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "For your child's safety, please remain with your buggy",
                audio: AssetSource("assets/audio/buggysafety.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Wheelchair Space 2",
          index: 14,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Wheelchair priority space required",
                audio: AssetSource("assets/audio/wheelchairspace2.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Service Regulation",
          index: 15,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "Regulating service - please listen for further information",
                audio: AssetSource("assets/audio/serviceregulation.mp3")
            ));
          },
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        ControlPanelRightEntry(
          label: "Bus Ready To Depart",
          index: 16,

          onPressed: () {
            IBus.instance.queueAnnouncement(IBusAnnouncementEntry(
                message: "This bus is ready to depart",
                audio: AssetSource("assets/audio/readytodepart.mp3")
            ));
          },
        ),

      ],

    )
  ];



  @override
  Widget build(BuildContext context) {

    final pages = initPages();

    return Column(

      children: [

        pages[pageIndex],

        Container(

          color: Colors.black,

          height: 2,

        ),

        Container(

          height: 40,

          padding: EdgeInsets.all(2),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              ElevatedButton(
                onPressed: () {

                  setState(() {
                    print("Page before: $pageIndex");

                    pageIndex--;

                    print("Page during: $pageIndex");

                    if (pageIndex < 0){
                      pageIndex = pages.length - 1;
                    }

                    print("Page after: $pageIndex");
                  });

                },

                child: Icon(Icons.arrow_upward),

                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(

                  )
                ),

              ),

              SizedBox(
                width: 2,
              ),

              ElevatedButton(
                onPressed: () {

                  setState(() {
                    print("Page before: $pageIndex");

                    pageIndex++;

                    print("Page during: $pageIndex");


                    if (pageIndex >= pages.length){
                      pageIndex = 0;
                    }

                    print("Page after: $pageIndex");
                  });

                },

                child: Icon(Icons.arrow_downward),

                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(

                    )
                ),

              )

            ],

          ),

        )

      ],

    );
  }
}

class ControlPanelRightEntry extends StatelessWidget {

  bool invertColor = true;

  String label = "null";

  int index = -1;

  late VoidCallback onPressed;



  ControlPanelRightEntry({super.key,
    required this.onPressed,
    this.label = "null",
    this.invertColor = false,
    this.index = -1
  });


  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(

      margin: EdgeInsets.all(2),

      width: double.infinity,
      height: 70,

      color: invertColor ? Colors.black : Color.fromRGBO(0, 0, 0, 0),

      child: Stack(

        children: [

          Container(

            padding: EdgeInsets.all(8),

            child: Text(
            label,
              style: TextStyle(
                fontFamily: "LCD",
                fontSize: 23,
                height: 1,
                color: invertColor ? Colors.lightGreen.shade100 : Colors.black,
                shadows: [
                  Shadow(
                      blurRadius: 60,
                    color: invertColor ? Colors.lightGreen.shade100 : Colors.black,
                  )
                ]
              ),

            ),
          ),

          SizedBox(

            width: double.infinity,
            height: double.infinity,

            child: TextButton(

              onPressed: onPressed,

              child: Text(
                ""
              ),

              style: TextButton.styleFrom(

                padding: EdgeInsets.all(0),

                shape: RoundedRectangleBorder(),

                backgroundColor: Colors.transparent,
                foregroundColor: Colors.transparent
              )

            ),
          ),

          Container(

            alignment: Alignment.topRight,

            padding: EdgeInsets.all(8),

            child: Text(
              "${index}",
              style: TextStyle(
                fontFamily: "LCD",
                fontSize: 23,
                height: 1,
                color: invertColor ? Colors.lightGreen.shade100 : Colors.black,
                shadows: [
                  Shadow(
                    blurRadius: 60,
                    color: invertColor ? Colors.lightGreen.shade100 : Colors.black,
                  )
                ]
              ),

            ),

          )

        ],

      ),

    );
  }

}
