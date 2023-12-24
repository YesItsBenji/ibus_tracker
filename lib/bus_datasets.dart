
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:csv/csv.dart';
import 'package:ibus_tracker/main.dart';
import 'package:intl/intl.dart';
import 'package:vector_math/vector_math.dart';
import 'NorthingsNEastings.dart';

class BusSequences {

  // Singleton
  static final BusSequences _instance = BusSequences._internal();

  factory BusSequences() {
    return _instance;
  }

  BusSequences._internal();

  late List<BusRoute> routes = [];

  static BusSequences fromCSV(String csv) {
    BusSequences sequences = BusSequences();

    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csv);

    // entries.removeRange(0, 11);

    BusRoute route = BusRoute();

    int line = 0;

    rowsAsListOfValues.removeAt(0);

    for (List<dynamic> entries in rowsAsListOfValues) {

      line++;

      String rowRouteNumber = entries[0].toString();

      // print("rowRouteVariant: ${entries[1]}");

      int rowRouteVariant = -1;

      try {
        rowRouteVariant = entries[1];
      } catch (e) {
        print("Error on line $line");
        continue;
      }

      // if the route varient is -1, we are on the first row.
      if (route.routeVariant == -1) {
        route.routeNumber = rowRouteNumber;
        route.routeVariant = rowRouteVariant;
      } else if (route.routeVariant != rowRouteVariant) {
        sequences.routes.add(route);

        route = BusRoute();
        route.routeNumber = rowRouteNumber;
        route.routeVariant = rowRouteVariant;
      }

      RouteStop stop = RouteStop();

      stop.stopName = entries[6];
      try {
        stop.stopCode = entries[3];
      } catch (e) {
        stop.stopCode = -2;
      }

      stop.sequence = entries[2];

      double northing = entries[8].toDouble();
      double easting = entries[7].toDouble();
      List<double> latLong = OSGrid.toLatLong(northing, easting);

      stop.latitude = latLong[0];
      stop.longitude = latLong[1];

      // check to see if its a string or int
      if (entries[9].runtimeType == String) {
        stop.heading = double.tryParse(entries[9]) ?? 0.0;
      } else {
        stop.heading = entries[9].toDouble();
      }

      // print("Type: ${entries[9].runtimeType}");

      route.busStops.add(stop);

      // print(stop.toString());
    }

    // Sort routes by route number
    sequences.routes.sort((a, b) {
      bool aIsNumeric = RegExp(r'^\d+$').hasMatch(a.routeNumber);
      bool bIsNumeric = RegExp(r'^\d+$').hasMatch(b.routeNumber);

      if (aIsNumeric && !bIsNumeric) {
        return -1; // Place pure numeric routes first
      } else if (!aIsNumeric && bIsNumeric) {
        return 1; // Place pure numeric routes first
      } else {
        int aNumber = int.tryParse(a.routeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int bNumber = int.tryParse(b.routeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        if (aNumber == bNumber) {
          return a.routeNumber.compareTo(b.routeNumber);
        }

        return aNumber - bNumber;
      }
    });

    print("Created ${sequences.routes.length} routes from $line lines.");

    return sequences;
  }

  List<BusRoute>? getBusRoute(String routeNumber) {

    List<BusRoute> routes = [];

    for (BusRoute route in this.routes) {
      if (route.routeNumber == routeNumber) {
        routes.add(route);
      }
    }

    return routes;
  }

}



class BusRoute {

  String routeNumber = "";

  int routeVariant = -1;

  List<RouteStop> busStops = [];

  RouteStop getNearestBusStop(double latitude, double longitude) {

    RouteStop nearestBusStop = busStops.first;

    double nearestDistance = _calculateDistance(latitude, longitude, nearestBusStop.latitude, nearestBusStop.longitude);

    for (RouteStop busStop in busStops) {

      double distance = _calculateDistance(latitude, longitude, busStop.latitude, busStop.longitude);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestBusStop = busStop;
      }

    }

    return nearestBusStop;

  }

  RouteStop? getNextBusStop(double latitude, double longitude) {

    RouteStop nearestStop = getNearestBusStop(latitude, longitude);

    // Check to see if the coordinates have passed the stop
    double relativeDistance = nearestStop.calculateRelativeDistance(latitude, longitude);
    double actualDistance = _calculateDistance(latitude, longitude, nearestStop.latitude, nearestStop.longitude);

    // If the relative distance is negative, the coordinates have passed the stop
    if (relativeDistance < 0) {

      int stopIndex = busStops.indexOf(nearestStop);

      // use min function to prevent index out of bounds error
      return busStops[min(stopIndex + 1, busStops.length - 1)];
    } else {
      return nearestStop;
    }

  }

  @override
  String toString() {
    // TODO: implement toString
    return "Route: $routeNumber: ${busStops[0].stopName} - ${busStops.last.stopName} ";
  }

  String getAudioFileName() {

    return "R_${routeNumber}_001.mp3";

  }

}

class LatLng {
  double latitude;
  double longitude;

  LatLng(this.latitude, this.longitude);

  // project lat long to a 2d plane that is to scale
  Vector2 toCartesian() {

// Earth's radius in kilometers
    const double R = 6371;

    double lat = radians(latitude);
    double lon = radians(longitude);

    double x = R * cos(lat) * cos(lon);
    double y = R * cos(lat) * sin(lon);

    return Vector2(x, y);
  }
}

class RouteStop {

  String stopName = "";

  int stopCode = 0;

  int sequence = 0;

  double latitude = 0.0;
  double longitude = 0.0;

  double heading = 0.0;

  // Earth's radius in kilometers
  static const double R = 6371;

  String getStopName_Beautified() {
    return NameBeutify.beautifyStopName(stopName);
  }

  double calculateRelativeDistance(double latitude, double longitude) {

    Vector2 stopPoint = OSGrid.toNorthingEasting(this.latitude, this.longitude);
    Vector2 currentPoint = OSGrid.toNorthingEasting(latitude, longitude);

    // calculate the heading from the current point to the stop point
    // 0 degrees is north, 90 degrees is east, 180 degrees is south, 270 degrees is west
    double toHeading = degrees(atan2(stopPoint.x - currentPoint.x, stopPoint.y - currentPoint.y));
    toHeading = (toHeading + 360) % 360;


    // get the dot product of the heading and the stop heading
    double dotProduct = cos(radians(toHeading)) * cos(radians(this.heading)) + sin(radians(toHeading)) * sin(radians(this.heading));
    print("====================================");
    print(" ");
    print("Bus stop: $stopName");
    print(" ");
    print("Coordinates: $latitude, $longitude");
    print(" ");
    print("Heading to bus stop: $toHeading");
    print("Bus stop heading: ${this.heading}");
    print(" ");
    print("Bus stop point: $stopPoint");
    print("Current point: $currentPoint");
    print(" ");
    print("Dot product: $dotProduct");
    print(" ");
    print("====================================");

    return (dotProduct.sign) * _calculateDistance(latitude, longitude, this.latitude, this.longitude);

  }

  String getAudioFileName() {

    // Convert the stop name to all caps
    String stopName = this.stopName.toUpperCase();

    stopName = NameBeutify.beautifyStopName(stopName);

    // replace & with N
    stopName = stopName.replaceAll('&', 'N');

    stopName = stopName.replaceAll('/', '');

    stopName = stopName.replaceAll('\'', '');

    stopName = stopName.replaceAll('  ', ' ');

    // Replace space with underscore
    stopName = stopName.replaceAll(' ', '_');

    // convert to all caps
    stopName = stopName.toUpperCase();

    return "S_${stopName}_001.mp3";

  }

}

class BusStops {

  // Singleton
  static final BusStops _instance = BusStops._internal();

  factory BusStops() {
    return _instance;
  }

  BusStops._internal();

  List<BusStop> busStops = [];

  static BusStops fromCSV(String csv) {

    BusStops busStops = BusStops();

    busStops.busStops.clear();

    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csv);

    rowsAsListOfValues.removeAt(0);

    for (List<dynamic> entries in rowsAsListOfValues) {

      BusStop busStop = BusStop();

      busStop.stopName = entries[3];

      try {
        busStop.stopCode = entries[1].toInt();
      } catch (e) {
        busStop.stopCode = -2;
        // print(e);
      }

      double northing = entries[5].toDouble();
      double easting = entries[4].toDouble();

      List<double> latLong = OSGrid.toLatLong(northing, easting);

      busStop.latitude = latLong[0];
      busStop.longitude = latLong[1];

      busStops.busStops.add(busStop);

    }

    print("Done loading ${busStops.busStops.length} bus stops.");

    return busStops;
  }

  BusStop? getNearestBusStop(double latitude, double longitude) {

    if (busStops.isEmpty) {
      return null;
    }

    BusStop? nearestBusStop = busStops.first;

    double nearestDistance = _calculateDistance(latitude, longitude, nearestBusStop.latitude, nearestBusStop.longitude);

    for (BusStop busStop in busStops) {

      double distance = _calculateDistance(latitude, longitude, busStop.latitude, busStop.longitude);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestBusStop = busStop;
      }

    }

    return nearestBusStop;

  }


}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {

  // Convert to eastings and northings
  Vector2 point1 = OSGrid.toNorthingEasting(lat1, lon1);
  Vector2 point2 = OSGrid.toNorthingEasting(lat2, lon2);

  return point1.distanceTo(point2);

}

double _degreeToRadian(double degree) {
  return degree * pi / 180;
}

class BusStop {

  String stopName = "";

  int stopCode = 0;

  double latitude = 0.0;
  double longitude = 0.0;

  @override
  bool operator ==(Object other) {
    return other is BusStop && other.stopCode == stopCode;
  }

  String getAudioFileName() {

    // Convert the stop name to all caps
    String stopName = this.stopName.toUpperCase();

    stopName = NameBeutify.beautifyStopName(stopName);

    stopName = stopName.replaceAll('/', '');

    stopName = stopName.replaceAll('\'', '');

    stopName = stopName.replaceAll('  ', ' ');

    // Replace space with underscore
    stopName = stopName.replaceAll(' ', '_');

    // convert to all caps
    stopName = stopName.toUpperCase();

    return "S_${stopName}_001.mp3";

  }

}

class BusGarages {

  // Singleton
  static final BusGarages _instance = BusGarages._internal();

  factory BusGarages() {
    return _instance;
  }

  BusGarages._internal();

  List<BusGarage> busGarages = [];

  static BusGarages fromCSV(String csv){

    BusGarages busGarages = BusGarages();

    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csv);

    rowsAsListOfValues.removeAt(0);

    for (List<dynamic> entries in rowsAsListOfValues) {

      BusGarage busGarage= BusGarage();


      busGarage.garageName = entries[0];
      busGarage.garageOperator = entries[1];
      // print(entries[2]);
      busGarage.garageNumber = entries[2];



      busGarages.busGarages.add(busGarage);
    }

    return busGarages;

  }

  BusGarage? getBusGarage(int garageNumber) {

    for (BusGarage busGarage in busGarages) {
      if (busGarage.garageNumber == garageNumber) {
        return busGarage;
      }
    }

    return null;
  }

}

class BusGarage {

  String garageName = "";

  String garageOperator = "";

  int garageNumber = -1;

  @override
  bool operator ==(Object other) {
    return other is BusGarage && other.garageNumber == garageNumber;
  }

}

class BusBlinds {

  // Singleton
  static final BusBlinds _instance = BusBlinds._internal();

  factory BusBlinds() {
    return _instance;
  }

  BusBlinds._internal();

  Map<String, List<BusBlindsEntry>> destinations = {};

  BusBlindsEntry? getNearestBusBlind(double latitude, double longitude, String routeNumber) {

    if (!destinations.containsKey(routeNumber)) {

      print("Route $routeNumber not found in bus blinds");
      return null;
    }

    List<BusBlindsEntry> busBlinds = destinations[routeNumber] ?? [];

    BusBlindsEntry? nearestBusBlind = busBlinds.first;

    double nearestDistance = _calculateDistance(latitude, longitude, nearestBusBlind.latitude, nearestBusBlind.longitude);

    for (BusBlindsEntry busBlind in busBlinds) {

      double distance = _calculateDistance(latitude, longitude, busBlind.latitude, busBlind.longitude);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestBusBlind = busBlind;
      }

    }

    return nearestBusBlind;

  }

  static BusBlinds fromCSV(String csv) {

    BusBlinds routeBlinds = BusBlinds();

    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csv);

    rowsAsListOfValues.removeAt(0);

    print("Extracting bus blinds");

    for (List<dynamic> entries in rowsAsListOfValues) {

      String route = entries[0].toString();
      String blind = entries[1].toString();

      if (!routeBlinds.destinations.containsKey(route)){
        routeBlinds.destinations[route] = [];
      }

      BusBlindsEntry blindsEntry = BusBlindsEntry();

      try {
        blindsEntry.route = route;
        blindsEntry.label = blind;
        blindsEntry.latitude = entries[2].toDouble();
        blindsEntry.longitude = entries[3].toDouble();
      } catch (e) {

      }

      // print("Blinds: $blind ${blindsEntry.latitude} ${blindsEntry.longitude}");

      routeBlinds.destinations[route]?.add(blindsEntry);


    }


    return routeBlinds;

  }


}

class BusBlindsEntry {

  String label = "";

  String route = "";

  double latitude = 0;

  double longitude = 0;

  String getAudioFileName() {

    // Convert the stop name to all caps
    String stopName = label.toUpperCase();

    stopName = NameBeutify.beautifyStopName(stopName);

    stopName = stopName.replaceAll('/', '');

    stopName = stopName.replaceAll('\'', '');

    stopName = stopName.replaceAll('  ', ' ');

    // Replace space with underscore
    stopName = stopName.replaceAll(' ', '_');

    stopName = stopName.replaceAll(',', '');

    // convert to all caps
    stopName = stopName.toUpperCase();

    return "D_${stopName}_001.mp3";

  }

}

class RailReplacement {

  // Singleton
  static final RailReplacement _instance = RailReplacement._internal();

  factory RailReplacement() {
    return _instance;
  }

  RailReplacement._internal();

  Map<String, RailReplacementRoute> routes = {};

  static RailReplacement fromCSV(String csv) {

    RailReplacement railReplacement = RailReplacement();

    List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csv);

    rowsAsListOfValues.removeAt(0);

    for (List<dynamic> entries in rowsAsListOfValues) {

      RailReplacementRoute route = RailReplacementRoute();

      route.routeNumber = entries[0];
      route.routeDescription = entries[1];
      route.routeLine = entries[2];

      railReplacement.routes[route.routeNumber] = route;

    }

    return railReplacement;

  }

  RailReplacementRoute? getRailReplacementRoute(String routeNumber) {

    if (routes.containsKey(routeNumber)) {
      return routes[routeNumber];
    }

    return null;

  }

}

class RailReplacementRoute {

  String routeNumber = "";

  String routeDescription = "";

  String routeLine = "";

  AssetSource getAudioFile() {

    // Convert the stop name to all caps
    String stopName = routeLine.toUpperCase();

    stopName = NameBeutify.beautifyStopName(stopName);

    stopName = stopName.replaceAll('/', '');

    stopName = stopName.replaceAll('\'', '');

    stopName = stopName.replaceAll('  ', ' ');

    // Replace space with underscore
    stopName = stopName.replaceAll(' ', '_');

    // Replace & with N
    stopName = stopName.replaceAll('&', 'N');

    // convert to all caps
    stopName = stopName.toUpperCase();

    print("assets/audio/rail_replacement/$stopName.mp3");

    return AssetSource("assets/audio/rail_replacement/$stopName.mp3");


  }

}


class NameBeutify {

  static final Map<String, String> Longify = {

    "ctr": "Centre",
    "stn": "Station",
    "tn": "Town",

  };

  static String beautifyStopName(String label) {

    String stopName = label.toUpperCase();

    // remove <>
    stopName = stopName.replaceAll("<>", "");

    // remove any parathesese pairs as well as the contents (), [], {}, <>, ><
    stopName = stopName.replaceAll(RegExp(r'\(.*\)'), '');
    stopName = stopName.replaceAll(RegExp(r'\[.*\]'), '');
    stopName = stopName.replaceAll(RegExp(r'\{.*\}'), '');
    // stopName = stopName.replaceAll(RegExp(r'\<.*\>'), '');
    stopName = stopName.replaceAll(RegExp(r'\>.*\<'), '');


    // remove any special characters except & and /
    stopName = stopName.replaceAll(RegExp(r'[^a-zA-Z0-9&/ ]'), '');

    // remove any double spaces
    stopName = stopName.replaceAll(RegExp(r'  '), ' ');

    // remove any spaces at the start or end of the string
    stopName = stopName.trim();

    // replace any short words with their long form
    for (String phrase in Longify.keys) {
      stopName = stopName.replaceAll(RegExp(phrase, caseSensitive: false), Longify[phrase]!);
    }


    stopName = stopName.toLowerCase();
    // Capitalify the first letter of each word
    try {
      stopName = stopName.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
    } catch (e) {}

    return stopName;

  }

  static String getShortTime(){

    // return the HH:MM with AM and PM and make sure that the hour is 12 hour format and it always double digits. IE 01, 02 etc
    DateTime now = DateTime.now();
    String formatted = DateFormat('hh:mm a').format(now);
    return formatted;
  }

  static String getLongTime() {
    DateTime now = DateTime.now();
    String formattedTime = DateFormat('HH:mm:ss  dd.MM.yyyy').format(now);
    return formattedTime;
  }

}