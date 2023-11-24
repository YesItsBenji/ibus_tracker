import 'dart:math' as math;
import 'package:proj4dart/proj4dart.dart' as proj4;


class OSGrid {

  static List<double> toLatLong(double northing, double easting) {

    final sourceProjection = proj4.Projection.parse('+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.9996012717 '
        '+x_0=400000 +y_0=-100000 +ellps=airy +datum=OSGB36 +units=m +no_defs'); // British National Grid
    final destinationProjection = proj4.Projection.WGS84;// WGS84

    final point = proj4.Point(x: easting, y: northing);
    final transformedPoint = sourceProjection.transform(destinationProjection, point);



    return [transformedPoint.y, transformedPoint.x];
  }

}

