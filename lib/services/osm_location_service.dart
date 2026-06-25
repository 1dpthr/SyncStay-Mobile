import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Free OpenStreetMap Nominatim geocoding (respect usage policy: low rate, identify app).
class OsmLocationService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'SyncStay/1.0 (campus hostel app)';

  static Future<List<OsmPlace>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': q,
      'format': 'json',
      'addressdetails': '1',
      'limit': '6',
      'accept-language': 'en',
    });

    final response = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return [];

    final list = json.decode(response.body) as List<dynamic>;
    return list.map((e) => OsmPlace.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'json',
      'accept-language': 'en',
    });

    final response = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['display_name'] as String?;
  }
}

class OsmPlace {
  final String displayName;
  final LatLng point;

  OsmPlace({required this.displayName, required this.point});

  factory OsmPlace.fromJson(Map<String, dynamic> json) {
    return OsmPlace(
      displayName: json['display_name'] as String? ?? 'Unknown',
      point: LatLng(
        double.parse(json['lat'].toString()),
        double.parse(json['lon'].toString()),
      ),
    );
  }
}
