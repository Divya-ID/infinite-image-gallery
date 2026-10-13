import 'dart:convert';

import 'package:http/http.dart' as http;

class UnsplashService {
  static const String _accessKey = String.fromEnvironment(
    'UNSPLASH_ACCESS_KEY',
  );

  static Future<List<Map<String, dynamic>>> fetchPhotos({
    int page = 1,
    int perPage = 20,
  }) async {
    if (_accessKey.isEmpty) {
      throw Exception('Unsplash API key missing. Check run command.');
    }

    final uri = Uri.https('api.unsplash.com', '/photos', {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    print('API CALL STARTED - Page: $page');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Client-ID $_accessKey'},
    );
    print('API STATUS: ${response.statusCode}');
    print('API PAGE: $page');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('Photos received from API: ${data.length}');
      return data.cast<Map<String, dynamic>>();
    }

    if (response.statusCode == 403) {
      throw Exception(
        'Rate limit exceeded (demo key: 50 requests/hour). Try again later.',
      );
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid Unsplash access key.');
    }

    throw Exception('Unsplash API error: ${response.statusCode}');
  }
}
