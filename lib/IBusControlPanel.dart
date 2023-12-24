
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ibus_tracker/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bus_datasets.dart';

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

          margin: const EdgeInsets.all(10),
          
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

  List<BusRoute> busRoute = [];

  int routeVariant = -1;

  int operatingNumber = -1;

  int tripNumber = -1;

  BusRoute? getBusRouteVariant(int RouteVariant){
    for (BusRoute route in busRoute){
      if (route.routeVariant == RouteVariant){
        return route;
      }
    }

    return busRoute[0];
  }

  BusRoute? getBusRoute(){
    if (routeVariant == -1){
      return null;
    }
    return getBusRouteVariant(routeVariant);
  }

}

// IBus singleton
class IBus {

  // singleton with initialisation
  static final IBus _instance = IBus._internal();

  factory IBus() {
    return _instance;
  }

  IBus._internal(){
    init();
  }


  String announcementDirectory = "";

  void init(){

    announcementTimer();

    LoadDatasets();

    AudioCache.instance.prefix = "";

    prefCallback(SharedPreferences pref) {
      print("Inside shared preferences");

      bool conditionA = pref.containsKey("announcementDirectory");
      bool conditionB = false;
      bool conditionC = false;
      if (conditionA){
        conditionB = Directory(pref.getString("announcementDirectory")!).existsSync();
        conditionC = pref.getString("announcementDirectory")!.isNotEmpty;
      }

      if (conditionA && conditionB && conditionC){
        announcementDirectory = pref.getString("announcementDirectory")!;
      } else {
        FilePicker.platform.getDirectoryPath().then((value) {
          announcementDirectory = value!;

          pref.setString("announcementDirectory", announcementDirectory);
        });
      }
    }

    // Check if platform android
    if (Platform.isAndroid){
      Permission.manageExternalStorage.request().then((value) => {

        print("Storage Permission: $value"),

        SharedPreferences.getInstance().then(prefCallback)
      });
    } else {
      SharedPreferences.getInstance().then(prefCallback);
    }
  }

  void LoadDatasets(){

    rootBundle.loadString("assets/garage_codes.csv").then((value) {
      BusGarages.fromCSV(value);
      refresh();
    });

    // Read string from url = https://tfl.gov.uk/bus-sequences.csv

    http.get(Uri.parse('https://tfl.gov.uk/bus-sequences.csv')).then((value) {
      BusSequences sequences = BusSequences.fromCSV(value.body);
      refresh();
    }).catchError((e){
      rootBundle.loadString("assets/bus-sequences.csv").then((value) {
        BusBlinds sequences = BusBlinds.fromCSV(value);
        refresh();
      });
    });


    rootBundle.loadString("assets/bus-blinds.csv").then((value) {
      BusBlinds sequences = BusBlinds.fromCSV(value);
      refresh();
    });

    rootBundle.loadString("assets/bus-stops.csv").then((value) async {
      BusStops.fromCSV(value);
    });

    rootBundle.loadString("assets/rail-replacement.csv").then((value) {
      RailReplacement.fromCSV(value);
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
    const Duration(milliseconds: 50),
    (Timer t) async {


      try {
        if (_audioQueue.isNotEmpty && !isPlayingAudio){
          isPlayingAudio = true;


          CurrentMessage = _audioQueue[0].message;

          refresh();

          AudioPlayer player = AudioPlayer();

          IBusAnnouncementEntry entry = _audioQueue[0];

          if (entry.delay != null){
            await Future.delayed(entry.delay!);
          }


          for (Source audio in entry.audio){
            try {
              await player.play(audio);
              Duration? duration = await player.getDuration();

              // wait for the audio to finish playing
              if (entry.audio.last != audio) {
                await Future.delayed(duration! + const Duration(milliseconds: 350));
              }
            } catch (e) {
              _audioQueue.removeAt(0);
              isPlayingAudio = false;

              refresh();
              break;
            }

          }


          player.onPlayerComplete.listen((event) {
            // player.stop();

            // If there is nothing else in the queue to play, then leave the announcement on the screen for 5 seconds and then change it back to the bus stop name.
            // If there is something else in the queue, then play the next announcement immediately.
            if (_audioQueue.length == 1){

              int QueueLength = _audioQueue.length;

              Future.delayed(const Duration(seconds: 2), () {
                if (QueueLength == 1){

                  if (!entry.persist){

                    if (CurrentMessage == entry.message){
                      announceDestination();
                    }

                  }

                  refresh();
                }
              });
            }

            _audioQueue.removeAt(0);
            isPlayingAudio = false;
            // print("Popped audio queue");
          });



        }
      } catch (e) {
        print(e);
        isPlayingAudio = false;
        _audioQueue.removeAt(0);
      }

    }
  );

  RouteStop? lastAnnouncedStop;
  StreamSubscription<Position> locationSubscription() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5
    )
  ).listen((Position? position) async {

    isNearestStopComputing = true;

    this.isNearestStopComputing = true;

    RouteStop? nearestStop = loginInformation?.getBusRoute()?.getNextBusStop(position!.latitude, position.longitude);

    // Check if the nearest stop has changed
    if (nearestStop != null && (nearestStop != nearestBusStop || nearestBusStop == null)){
      nearestBusStop = nearestStop;

      CurrentMessage = nearestBusStop!.getStopName_Beautified();

      refresh();
    }
    if (nearestStop != null && nearestBusStop != null && lastAnnouncedStop != nearestBusStop) {
      // check to see if the stop is within 100m of the nearest stop

      double distance = Geolocator.distanceBetween(
        position!.latitude,
        position.longitude,
        nearestBusStop!.latitude,
        nearestBusStop!.longitude
      );

      print("Distance: $distance");

      if (distance < 200){
        lastAnnouncedStop = nearestBusStop;

        String pth = ("$announcementDirectory/${nearestBusStop!.getAudioFileName()}");

        Source audio = DeviceFileSource(pth);

        if (!await File(pth).exists()){

          print("Failed file: $pth");

          audio = AssetSource("assets/audio/nextstopclosed.wav");

          Fluttertoast.showToast(
            msg: "Missing audio file for ${nearestBusStop!.getAudioFileName()}",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 5,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
          );
        }

        queueAnnouncement(IBusAnnouncementEntry(
          message: nearestBusStop!.getStopName_Beautified(),
          audio: [audio],
          persist: true
        ));
      }

    }

  });

  String CurrentMessage = "*** NO MESSAGE ***";

  void queueAnnouncement(IBusAnnouncementEntry announcementEntry){

    _audioQueue.add(announcementEntry);

  }

  void announceDestination({bool withAudio = false}){

    // {RouteNumber} to {Destination}

    print("announcementdirectory: $announcementDirectory");

    AssetSource audio = AssetSource("assets/audio/to_destination.wav");

    RouteStop lastStop = loginInformation!.getBusRoute()!.busStops.last;
    BusBlindsEntry? destinationBlind = BusBlinds().getNearestBusBlind(lastStop.latitude, lastStop.longitude, loginInformation!.getBusRoute()!.routeNumber);


    // get the destination audio file

    // String Destinationpth = ("$announcementDirectory/${loginInformation?.getBusRoute()?.busStops.last.getAudioFileName()}");
    String Destinationpth = ("$announcementDirectory/${destinationBlind?.getAudioFileName()}");
    DeviceFileSource audioDestination = DeviceFileSource(Destinationpth);

    String DestinationName = destinationBlind!.label;

    // get the number audio file

    Source audioNumber;

    // check if the route number has the 'UL' prefix
    if (loginInformation!.getBusRoute()!.routeNumber.startsWith("UL")){

      // get the rail replacement route
      audioNumber = RailReplacement().getRailReplacementRoute(loginInformation!.getBusRoute()!.routeNumber)!.getAudioFile();
    } else {
      String numberPath = ("$announcementDirectory/${loginInformation!.getBusRoute()!.getAudioFileName()}");
      audioNumber = DeviceFileSource(numberPath);
    }

    String message = "${loginInformation!.getBusRoute()!.routeNumber} to ${DestinationName}";

    if (withAudio){
      queueAnnouncement(IBusAnnouncementEntry(
          message: message,
          audio: [audioNumber, audio, audioDestination]
      ));
    } else {
     CurrentMessage = message;
     refresh();
    }



  }

  Map<Object, Function()> _refreshFunctions = {};

  void addRefresher(Object object, Function() refreshFunction){
    _refreshFunctions[object] = refreshFunction;
    refreshFunction();
  }

  void refresh(){
    // loop keys and values

    List<Object?> keysToRemove = [];

    _refreshFunctions.forEach((key, value) {
      // if key is still valid then run function, if not remove it
      if (key != null){
        try {
          value();
        } catch (e) {
          keysToRemove.add(key);
        }
      } else {
        keysToRemove.add(key);
      }
    });

    for (Object? key in keysToRemove){
      _refreshFunctions.remove(key);
    }
  }

  bool _isBusStopping = false;

  // refresh on isBusStopping set
  set isBusStopping(bool value){
    _isBusStopping = value;
    refresh();
  }

  bool get isBusStopping => _isBusStopping;

  IBusLoginInformation? loginInformation;

  RouteStop? nearestBusStop;

  bool driverInfoMode = false;


}

class IBusAnnouncementEntry {

  final String message;

  final List<Source> audio;

  final bool persist;

  final Duration? delay;

  IBusAnnouncementEntry({
    this.message = "*** NO MESSAGE ***",
    this.audio = const [],
    this.persist = false,
    this.delay
  });

}

class ControlPanel extends StatefulWidget {



  ControlPanel({
    super.key,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

// stay alive
class _ControlPanelState extends State<ControlPanel>{
  String rightTitle = "";

  void refresh(){
    setState(() {

    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    IBus().addRefresher(this, refresh);

  }


  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(

      height: 384,

      padding: const EdgeInsets.all(2),

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

                          padding: const EdgeInsets.all(10),

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

                              const Text(
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

                              const Text(
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




                    Expanded(child: IBus().loginInformation == null ?
                    ControlPanelLogin() :
                    IBus().loginInformation?.routeVariant == -1 ?
                    ControlPanelRouteVarient(

                    ) :
                    IBus().driverInfoMode ?
                    _staticAnnouncer() :
                    ControlPanel_BusStops()),



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

  // Field Controllers
  final TextEditingController garageController = TextEditingController();
  final TextEditingController routeController = TextEditingController();
  final TextEditingController operatingNumberController = TextEditingController(
    text: "0"
  );
  final TextEditingController tripNumberController = TextEditingController(
    text: "0"
  );



  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      


      child: Column(

        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Expanded(
            child: Container(

              padding: const EdgeInsets.all(10),

              child: Column(

                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: MainAxisSize.max,

                children: [

                  ControlPanelTextField(
                    label: "Garage",
                    controller: garageController,
                    keyboardType: TextInputType.number,
                  ),

                  ControlPanelTextField(
                    label: "Route",
                    controller: routeController,
                  ),

                  ControlPanelTextField(
                    label: "Oper. No.",
                    controller: operatingNumberController,
                    keyboardType: TextInputType.number,
                  ),

                  ControlPanelTextField(
                    label: "Trip No.",
                    controller: tripNumberController,
                    keyboardType: TextInputType.number,
                  ),

                ],


              ),
            ),
          ),

          Container(

            color: Colors.black,

            height: 2,

          ),

          Container(

            height: 40,

            padding: const EdgeInsets.all(2),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                ElevatedButton(
                  onPressed: () {

                    IBus().loginInformation = IBusLoginInformation();

                    BusGarages garages = BusGarages();

                    IBus().loginInformation!.busGarage = garages.getBusGarage(int.parse(garageController.text));
                    IBus().loginInformation!.busRoute = BusSequences().getBusRoute(routeController.text.toUpperCase())!;
                    IBus().loginInformation!.operatingNumber = int.parse(operatingNumberController.text);
                    IBus().loginInformation!.tripNumber = int.parse(tripNumberController.text);

                    IBus().CurrentMessage = IBus().loginInformation!.busGarage!.garageName ?? "";

                    IBus().refresh();
                  },

                  child: const Icon(Icons.login),

                  style: ElevatedButton.styleFrom(
                      shape: const RoundedRectangleBorder(

                      )
                  ),

                ),

                // const SizedBox(
                //   width: 2,
                // ),

              ],

            ),

          )

        ],
      ),

    );
  }



}

class ControlPanel_BusStops extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build

    List<ControlPanelRightEntry> items = [];

    // All the bus stops in the route, when clicked, announce the bus stop
    int index = 1;
    for (RouteStop stop in IBus().loginInformation!.getBusRoute()!.busStops){
      items.add(ControlPanelRightEntry(
        label: stop.getStopName_Beautified(),
        index: index++,
        onPressed: () {
          IBus().queueAnnouncement(IBusAnnouncementEntry(
            message: stop.getStopName_Beautified(),
            audio: [DeviceFileSource("${IBus().announcementDirectory}/${stop.getAudioFileName()}")],
            delay: const Duration(milliseconds: 500)
          ));

          // pop drawer
          Navigator.pop(context);
        },
      ));
    }

    return ControlPanel_ListPage(
      items: items,
      Footer: Row(

        children: [
          // button to enable driver info mode
          ElevatedButton(
            onPressed: () {
              IBus().driverInfoMode = !IBus().driverInfoMode;
              IBus().refresh();
            },

            child: const Icon(Icons.info),

            style: ElevatedButton.styleFrom(
                shape: const RoundedRectangleBorder(

                )
            ),

          ),
        ],

      ),
    );
  }



}

class ControlPanelTextField extends StatelessWidget {

  String label = "";

  TextEditingController? controller;

  TextInputType keyboardType;

  ControlPanelTextField({
    super.key,
    this.label = "",
    this.controller,
    this.keyboardType = TextInputType.text
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(

      height: 40,

      child: Row(

        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(
            "$label ",
            style: const TextStyle(
                fontFamily: "LCD",
                fontSize: 20,
                height: 1,
                color: Colors.black,
                shadows: [
                  Shadow(
                    blurRadius: 60,
                    color: Colors.black,
                  )
                ]
            ),

          ),

          Container(
            width: 150,

            padding: const EdgeInsets.all(2),

            color: Colors.black,

            // alignment: Alignment.center,

            child: Container(

              color: Colors.lightGreen.shade100,



              padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 2
              ),

              child: Row(

                mainAxisSize: MainAxisSize.max,

                children: [
                  Expanded(
                    child: Transform(

                      transform: Transform.translate(
                          offset: const Offset(0, 0)
                      ).transform,
                      child: TextField(

                        textAlignVertical: TextAlignVertical.center,
                        textAlign: TextAlign.right,
                        keyboardType: keyboardType,

                        controller: controller,

                        // no border
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 0
                            )
                        ),

                        style: const TextStyle(
                            fontFamily: "LCD",
                            fontSize: 20,
                            height: 1,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                blurRadius: 60,
                                color: Colors.black,
                              )
                            ]
                        ),
                      ),
                    ),
                  ),

                  const Text(
                    " <",
                    style: TextStyle(
                        fontFamily: "LCD",
                        fontSize: 20,
                        height: 1,
                        color: Colors.black,
                        shadows: [
                          Shadow(
                            blurRadius: 60,
                            color: Colors.black,
                          )
                        ]
                    ),

                  ),

                ],
              ),
            ),

          )

        ],

      ),
    );
  }



}

class ControlPanel_ListPage extends StatefulWidget {

  List<ControlPanelRightEntry> items = [];

  Widget? Footer;

  ControlPanel_ListPage({
    super.key,
    this.items = const [],
    this.Footer
  });

  @override
  State<ControlPanel_ListPage> createState() => _ControlPanel_ListPageState();
}

class _ControlPanel_ListPageState extends State<ControlPanel_ListPage> {
  int pageIndex = 0;

  Widget getPage(int pageIndex){

    // 4 items per page
    List<Widget> items = [];

    for (int i = pageIndex * 4; i < (pageIndex * 4) + 4; i++){
      if (i < this.widget.items.length){
        items.add(this.widget.items[i]);

        if (i != (pageIndex * 4) + 3){
          items.add(Container(
            color: Colors.black,
            height: 2,
          ));
        }

      }
    }

    return Container(
      child: Column(
        children: items,
      ),
    );


  }

  @override
  Widget build(BuildContext context) {

    return Column(

      children: [

        Container(

          color: Colors.black,

          width: double.infinity,

          height: 30,

          margin: const EdgeInsets.all(2),

        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        // pages[pageIndex],
        Expanded(
          child: getPage(pageIndex),
        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        Container(

          height: 40,

          padding: const EdgeInsets.all(2),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              ElevatedButton(
                onPressed: () {

                  IBus().loginInformation = null;
                  IBus().refresh();

                },

                child: const Icon(Icons.logout),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              ElevatedButton(
                onPressed: () {

                  setState(() {

                    pageIndex--;


                    if (pageIndex < 0){
                      pageIndex = (widget.items.length / 4).ceil() - 1;
                    }

                  });

                },

                child: const Icon(Icons.arrow_upward),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              ElevatedButton(
                onPressed: () {

                  setState(() {

                    pageIndex++;


                    if (pageIndex >= (widget.items.length / 4).ceil()){
                      pageIndex = 0;
                    }

                  });

                },

                child: const Icon(Icons.arrow_downward),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              widget.Footer ?? Container()

            ],

          ),

        )

      ],

    );
  }
}

class ControlPanelRouteVarient extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    List<ControlPanelRightEntry> items = [];

    BusSequences sequences = BusSequences();

    List<BusRoute> routes = IBus().loginInformation!.busRoute;

    for (BusRoute route in routes){
      items.add(ControlPanelRightEntry(
        label: "${route.busStops.first.getStopName_Beautified()} - ${route.busStops.last.getStopName_Beautified()}",
        index: route.routeVariant,
        onPressed: () {
          IBus().loginInformation!.routeVariant = route.routeVariant;

          IBus().refresh();

          // {RouteNumber} to {Destination}



          IBus().announceDestination();

        },
      ));
    }

    return ControlPanel_ListPage(
      items: items,
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
              message: "Driver Change",
              audio: [AssetSource("assets/audio/driverchange.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "No standing on upper deck",
                audio: [AssetSource("assets/audio/nostanding.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Please wear a face covering!",
                audio: [AssetSource("assets/audio/facecovering.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Seats are available upstairs",
                audio: [AssetSource("assets/audio/seatsupstairs.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Bus terminates here. Please take your belongings with you",
                audio: [AssetSource("assets/audio/busterminateshere.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Bus on diversion. Please listen for further announcements",
                audio: [AssetSource("assets/audio/busondiversion.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Destination Changed - please listen for further instructions",
                audio: [AssetSource("assets/audio/destinationchange.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Wheelchair space requested",
                audio: [AssetSource("assets/audio/wheelchairspace1.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Please move down the bus",
                audio: [AssetSource("assets/audio/movedownthebus.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "The next bus stop is closed",
                audio: [AssetSource("assets/audio/nextstopclosed.wav")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "CCTV is in operation on this bus",
                audio: [AssetSource("assets/audio/cctvoperation.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Driver will open the doors when it is safe to do so",
                audio: [AssetSource("assets/audio/safedooropening.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "For your child's safety, please remain with your buggy",
                audio: [AssetSource("assets/audio/buggysafety.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Wheelchair priority space required",
                audio: [AssetSource("assets/audio/wheelchairspace2.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "Regulating service - please listen for further information",
                audio: [AssetSource("assets/audio/serviceregulation.mp3")]
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
            IBus().queueAnnouncement(IBusAnnouncementEntry(
                message: "This bus is ready to depart",
                audio: [AssetSource("assets/audio/readytodepart.mp3")]
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

        Container(

          color: Colors.black,

          width: double.infinity,

          height: 30,

          margin: const EdgeInsets.all(2),

        ),

        Container(

          color: Colors.black,

          height: 2,

        ),

        pages[pageIndex],

        Container(

          color: Colors.black,

          height: 2,

        ),

        Container(

          height: 40,

          padding: const EdgeInsets.all(2),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              ElevatedButton(
                onPressed: () {

                  setState(() {
                    IBus().loginInformation = null;
                    IBus().refresh();
                  });

                },

                child: const Icon(Icons.logout),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              ElevatedButton(
                onPressed: () {

                  setState(() {

                    pageIndex--;


                    if (pageIndex < 0){
                      pageIndex = pages.length - 1;
                    }

                  });

                },

                child: const Icon(Icons.arrow_upward),

                style: ElevatedButton.styleFrom(
                  shape: const RoundedRectangleBorder(

                  )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              ElevatedButton(
                onPressed: () {

                  setState(() {

                    pageIndex++;



                    if (pageIndex >= pages.length){
                      pageIndex = 0;
                    }

                  });

                },

                child: const Icon(Icons.arrow_downward),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

              const SizedBox(
                width: 2,
              ),

              // button to disable driver info mode
              ElevatedButton(
                onPressed: () {
                  IBus().driverInfoMode = !IBus().driverInfoMode;
                  IBus().refresh();
                },

                child: const Icon(Icons.bus_alert),

                style: ElevatedButton.styleFrom(
                    shape: const RoundedRectangleBorder(

                    )
                ),

              ),

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

      margin: const EdgeInsets.all(2),

      width: double.infinity,
      height: 70,

      color: invertColor ? Colors.black : const Color.fromRGBO(0, 0, 0, 0),

      child: Stack(

        children: [

          Container(

            padding: const EdgeInsets.all(8),

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

              child: const Text(
                ""
              ),

              style: TextButton.styleFrom(

                padding: const EdgeInsets.all(0),

                shape: const RoundedRectangleBorder(),

                backgroundColor: Colors.transparent,
                foregroundColor: Colors.transparent
              )

            ),
          ),

          Container(

            alignment: Alignment.topRight,

            padding: const EdgeInsets.all(8),

            child: Text(
              "$index",
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
