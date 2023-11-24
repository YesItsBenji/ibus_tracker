
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:ibus_tracker/main.dart';
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
      int rowRouteVariant = entries[1];

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

      double northing = entries[8].toDouble();
      double easting = entries[7].toDouble();
      List<double> latLong = OSGrid.toLatLong(northing, easting);

      stop.latitude = latLong[0];
      stop.longitude = latLong[1];

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

  @override
  String toString() {
    // TODO: implement toString
    return "Route: $routeNumber: ${busStops[0].stopName} - ${busStops.last.stopName} ";
  }

  String getAudioFileName() {

    return "R_${routeNumber}_001.mp3";

  }

}

class RouteStop {

  String stopName = "";

  int stopCode = 0;

  double latitude = 0.0;
  double longitude = 0.0;

  String getAudioFileName() {

    // Convert the stop name to all caps
    String stopName = this.stopName.toUpperCase();

    stopName = beautifyString(stopName);

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
  const int radius = 6371; // radius of earth in Km
  final dLat = _degreeToRadian(lat2 - lat1);
  final dLon = _degreeToRadian(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2)
      + cos(_degreeToRadian(lat1)) * cos(_degreeToRadian(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  final distance = radius * c;
  return distance * 1000; // convert to meters
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

    stopName = beautifyString(stopName);

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