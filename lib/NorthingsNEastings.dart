import 'dart:math' as math;

const double radToDeg = 180 / math.pi;
const double degToRad = math.pi / 180;

const double a = 6377563.396;
const double b = 6356256.909;  // Airy 1830 major & minor semi-axes
const double f0 = 0.9996012717; // NatGrid scale factor on central meridian
const double lat0 = 49 * degToRad;
const double lon0 = -2 * degToRad; // NatGrid true origin
const double n0 = -100000.0;
const double e0 = 400000.0;        // northing & easting of true origin, meters
const double e2 = 1 - (b * b) / (a * a); // eccentricity squared
const double n = (a - b) / (a + b);
const double n2 = n * n;
const double n3 = n * n * n;

class OSGrid {

  static List<double> toLatLong(double northing, double easting) {
    double lat = lat0;
    double m = 0.0;

    while (northing - n0 - m >= 1e-5) { // until < 0.01mm
      lat = (northing - n0 - m) / (a * f0) + lat;
      double ma = (1 + n + (5 / 4) * n2 + (5 / 4) * n3) * (lat - lat0);
      double mb = (3 * n + 3 * n * n + (21 / 8) * n3) * math.sin(lat - lat0) * math.cos(lat + lat0);
      double mc = ((15 / 8) * n2 + (15 / 8) * n3) * math.sin(2 * (lat - lat0)) * math.cos(2 * (lat + lat0));
      double md = (35 / 24) * n3 * math.sin(3 * (lat - lat0)) * math.cos(3 * (lat + lat0));
      m = b * f0 * (ma - mb + mc - md); // meridional arc
    }

    double cosLat = math.cos(lat);
    double sinLat = math.sin(lat);
    double nu = a * f0 / math.sqrt(1 - e2 * sinLat * sinLat);                 // transverse radius of curvature
    double rho = a * f0 * (1 - e2) / math.pow(1 - e2 * sinLat * sinLat, 1.5); // meridional radius of curvature
    double eta2 = nu / rho - 1;
    double tanLat = math.tan(lat);
    double tan2lat = tanLat * tanLat;
    double tan4lat = tan2lat * tan2lat;
    double tan6lat = tan4lat * tan2lat;
    double secLat = 1 / cosLat;
    double nu3 = nu * nu * nu;
    double nu5 = nu3 * nu * nu;
    double nu7 = nu5 * nu * nu;
    double vii = tanLat / (2 * rho * nu);
    double viii = tanLat / (24 * rho * nu3) * (5 + 3 * tan2lat + eta2 - 9 * tan2lat * eta2);
    double ix = tanLat / (720 * rho * nu5) * (61 + 90 * tan2lat + 45 * tan4lat);
    double x = secLat / nu;
    double xi = secLat / (6 * nu3) * (nu / rho + 2 * tan2lat);
    double xii = secLat / (120 * nu5) * (5 + 28 * tan2lat + 24 * tan4lat);
    double xiia = secLat / (5040 * nu7) * (61 + 662 * tan2lat + 1320 * tan4lat + 720 * tan6lat);
    double de = easting - e0;
    double de2 = de * de;
    double de3 = de2 * de;
    double de4 = de2 * de2;
    double de5 = de3 * de2;
    double de6 = de4 * de2;
    double de7 = de5 * de2;
    lat = lat - vii * de2 + viii * de4 - ix * de6;
    double lon = lon0 + x * de - xi * de3 + xii * de5 - xiia * de7;

    return [lat * radToDeg, lon * radToDeg];
  }

}

