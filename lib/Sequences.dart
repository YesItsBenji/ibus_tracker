

import 'dart:convert';
import 'dart:io';
import 'NorthingsNEastings.dart';

class BusSequences {

  late List<BusRoute> routes = [];

  static BusSequences fromCSV(File file) {
    BusSequences sequences = BusSequences();

    String fileContent = file.readAsStringSync();

    List<String> entries = /* Split at "," or "\r\n" */ fileContent.split(RegExp(r',|\r\n'));

    entries.removeRange(0, 11);

    BusRoute route = BusRoute();

    for (int i = 0; i <= entries.length; i += 11) {

      String rowRouteNumber = entries[i];
      int rowRouteVariant = int.parse(entries[i + 1]);

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

      stop.stopName = entries[i + 6];
      stop.stopCode = int.parse(entries[i + 3]);

      double northing = double.parse(entries[i + 8]);
      double easting = double.parse(entries[i + 7]);
      List<double> latLong = OSGrid.toLatLong(northing, easting);

      stop.latitude = latLong[0];
      stop.longitude = latLong[1];

      route.busStops.add(stop);

      print(stop.toString());
    }


    return sequences;
  }

}

class BusRoute {

  String routeNumber = "";

  int routeVariant = -1;

  List<RouteStop> busStops = [];

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