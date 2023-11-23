
import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibus_tracker/main.dart';

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

  IBus();

  // Audio loop queue
  List<IBusAnnouncementEntry> _audioQueue = [];
  bool isPlayingAudio = false;

  Timer announcementTimer() => Timer.periodic(
    Duration(milliseconds: 10),
      (Timer t) async {

      // print("Audio queue: ${_audioQueue.length}");

      if (_audioQueue.isNotEmpty && !isPlayingAudio){
        isPlayingAudio = true;

        print("Playing: ${_audioQueue[0].message}");

        CurrentMessage = _audioQueue[0].message;

        refresh();

        AssetsAudioPlayer player = AssetsAudioPlayer.newPlayer();

        player.open(
            _audioQueue[0].audio!,
          autoStart: true,
          showNotification: false,
          loopMode: LoopMode.single
        );

        player.playlistAudioFinished.listen((event) {
          _audioQueue.removeAt(0);
          isPlayingAudio = false;
          print("Popped audio queue");
          player.stop();
        });
      }

    }
  );

  String CurrentMessage = "LEA INTERCHANGE";

  void queueAnnouncement(IBusAnnouncementEntry announcementEntry){

    _audioQueue.add(announcementEntry);

  }

  List<Function()> _refreshFunctions = [];

  void addRefresher(Function() refreshFunction){
    _refreshFunctions.add(refreshFunction);
    print("Added refresh function");
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


}

class IBusAnnouncementEntry {

  final String message;

  final Audio? audio;

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
          
                    _staticAnnouncer(),


          
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
              audio: Audio("assets/audio/driverchange.mp3")
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
                audio: Audio("assets/audio/nostanding.mp3")
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
                audio: Audio("assets/audio/facecovering.mp3")
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
                audio: Audio("assets/audio/seatsupstairs.mp3")
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
                audio: Audio("assets/audio/busterminateshere.mp3")
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
                audio: Audio("assets/audio/busondiversion.mp3")
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
                audio: Audio("assets/audio/destinationchange.mp3")
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
                audio: Audio("assets/audio/wheelchairspace1.mp3")
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
                audio: Audio("assets/audio/movedownthebus.mp3")
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
                audio: Audio("assets/audio/nextstopclosed.wav")
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
                audio: Audio("assets/audio/cctvoperation.mp3")
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
                audio: Audio("assets/audio/safedooropening.mp3")
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
                audio: Audio("assets/audio/buggysafety.mp3")
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
                audio: Audio("assets/audio/wheelchairspace2.mp3")
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
                audio: Audio("assets/audio/serviceregulation.mp3")
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
                audio: Audio("assets/audio/readytodepart.mp3")
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
