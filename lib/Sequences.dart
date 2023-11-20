

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'NorthingsNEastings.dart';

class BusSequences {

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

}



class BusRoute {

  String routeNumber = "";

  int routeVariant = -1;

  List<RouteStop> busStops = [];

  @override
  String toString() {
    // TODO: implement toString
    return "Route: $routeNumber: ${busStops[0].stopName} - ${busStops.last.stopName} ";
  }

}

class RouteStop {

  String stopName = "";

  int stopCode = 0;

  double latitude = 0.0;
  double longitude = 0.0;

}

class BusRouteStopDDDD {

  late String route;
  late int run;
  late int sequence;
  late String stop_code_lsbl;
  late String bus_stop_code;
  late String naptan_atco;
  late String stop_Name;
  late int easting;
  late int northing;
  late int heading;
  late int vbs;

  @override
  String toString() {
    // create a map from the fields
    Map<String, dynamic> map = {
      "route": route,
      "run": run,
      "sequence": sequence,
      "stop_code_lsbl": stop_code_lsbl,
      "bus_stop_code": bus_stop_code,
      "naptan_atco": naptan_atco,
      "stop_Name": stop_Name,
      "easting": easting,
      "northing": northing,
      "heading": heading,
      "vbs": vbs
    };

    // convert the map to json string
    String json = jsonEncode(map);

    return json;

  }
}