import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class Country {
  final String name;
  final String cca2; // 2-letter code for mapsicon
  final String flagUrl;

  Country({
    required this.name,
    required this.cca2,
    required this.flagUrl,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name']['common'] ?? 'Unknown',
      cca2: (json['cca2'] as String).toLowerCase(),
      flagUrl: json['flags']['png'] ?? '',
    );
  }
}

class CountryService {
  static const String _baseUrl = 'https://restcountries.com/v3.1/all';

  // We only fetch fields we need to minimize data transfer
  static const String _fields = 'name,cca2,flags';

  Future<List<Country>> fetchAllCountries() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?fields=$_fields'))
          .timeout(const Duration(seconds: 5)); // Add timeout

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Country.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load countries from API');
      }
    } catch (e) {
      // Fallback to local asset
      debugPrint("API failed ($e), loading from local assets...");
      return _loadFromAssets();
    }
  }

  Future<List<Country>> _loadFromAssets() async {
    try {
       // We need to import 'package:flutter/services.dart' for rootBundle
       // But this class is pure dart currently. We need to add the import.
       // For now, let's assume we add the import.
       final String response = await rootBundle.loadString('assets/countries.json');
       final List<dynamic> data = json.decode(response);
       return data.map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load local countries data: $e');
    }
  }
}
