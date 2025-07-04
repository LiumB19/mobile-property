import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';

class ApiService {
  // Ganti dengan IP address komputer Anda atau gunakan emulator
  // Untuk emulator Android: '10.0.2.2:5000'
  // Untuk device fisik: 'IP_ADDRESS_KOMPUTER:5000'
  static const String baseUrl = 'http://192.168.43.221:5001';
  // static const String baseUrl = 'http://192.168.1.100:5000'; // Contoh untuk device fisik

  Future<bool> addProperty({
    required String token,
    required String title,
    required String type,
    required String price,
    required String ethPrice,
    required String address,
    required String description,
    required File imageFile,
  }) async {
    var uri = Uri.parse('$baseUrl/properties');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['type'] = type;
    request.fields['price'] = price;
    request.fields['ethPrice'] = ethPrice;
    request.fields['address'] = address;
    request.fields['description'] = description;

    var imageMultipart = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType:
          MediaType('image', extension(imageFile.path).replaceAll('.', '')),
    );
    request.files.add(imageMultipart);

    var response = await request.send();
    return response.statusCode == 201;
  }

  // Method untuk mengambil token dari SharedPreferences
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // Method untuk menyimpan token ke SharedPreferences
  static Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  // Method untuk menghapus token dari SharedPreferences
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      print('Attempting login to: $baseUrl/api/login');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Tambahkan timeout

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      // Jika login berhasil, simpan token
      if (responseData['success'] == true && responseData['token'] != null) {
        await _saveToken(responseData['token']);
      }

      return responseData;
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      print('Attempting register to: $baseUrl/api/register');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/register'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Tambahkan timeout

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      print('Register error: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan: ${e.toString()}',
      };
    }
  }

  // Test koneksi ke server
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      print('Testing connection to: $baseUrl/api/ping');

      final response = await http.get(
        Uri.parse('$baseUrl/api/ping'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('Ping response status: ${response.statusCode}');
      print('Ping response body: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('Connection test error: $e');
      return {'success': false, 'error': 'Connection failed: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getProperties() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/properties'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

// Method untuk menambah property dengan image - FIXED VERSION
  static Future<Map<String, dynamic>> addPropertyWithImage(
      Map<String, dynamic> propertyData, File? imageFile) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      print('=== ADD PROPERTY DEBUG ===');
      print('Property data to send: $propertyData');
      print('Image file: ${imageFile?.path}');
      print('Token exists: ${token.isNotEmpty}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/properties'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add text fields dengan validasi
      propertyData.forEach((key, value) {
        if (value != null) {
          String stringValue = value.toString().trim();
          if (stringValue.isNotEmpty) {
            request.fields[key] = stringValue;
            print('Added field: $key = $stringValue');
          }
        }
      });

      // Add image file if exists
      if (imageFile != null && await imageFile.exists()) {
        try {
          var multipartFile = await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            // Tentukan content type secara eksplisit
            contentType: MediaType('image', 'jpeg'), // Uncomment jika perlu
          );
          request.files.add(multipartFile);
          print('Image file added to request: ${imageFile.path}');
          print('File size: ${await imageFile.length()} bytes');
        } catch (e) {
          print('Error adding image file: $e');
          return {
            'success': false,
            'error': 'Error processing image file: ${e.toString()}',
          };
        }
      } else {
        print('No image file provided or file does not exist');
      }

      print('Sending multipart request to: ${request.url}');
      print('Request fields: ${request.fields}');
      print('Request files count: ${request.files.length}');

      // Send request dengan timeout yang lebih panjang
      var streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );

      // Convert streamed response to regular response
      var response = await http.Response.fromStream(streamedResponse);

      print('=== RESPONSE DEBUG ===');
      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      // Parse response
      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        print('Error parsing JSON response: $e');
        return {
          'success': false,
          'error': 'Invalid server response format',
          'raw_response': response.body,
        };
      }

      // Handle response based on status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Property successfully added');
        return {
          'success': true,
          'data': responseData['data'],
          'message': responseData['message'] ?? 'Property berhasil ditambahkan',
        };
      } else {
        print('❌ Server returned error status: ${response.statusCode}');
        return {
          'success': false,
          'error': responseData['message'] ??
              responseData['error'] ??
              'Failed to add property',
          'status_code': response.statusCode,
          'details': responseData,
        };
      }
    } catch (e) {
      print('❌ Network/Client error: $e');

      // Handle specific error types
      String errorMessage = 'Network error occurred';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timeout - server might be slow';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection or server unreachable';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response format from server';
      } else {
        errorMessage = 'Network error: ${e.toString()}';
      }

      return {
        'success': false,
        'error': errorMessage,
        'exception': e.toString(),
      };
    }
  }

  // Method lama untuk backward
  // Method untuk update property dengan image
  static Future<Map<String, dynamic>> updatePropertyWithImage(int propertyId,
      Map<String, dynamic> propertyData, File? imageFile) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/properties/$propertyId'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // Add text fields
      propertyData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add image file if exists
      if (imageFile != null && await imageFile.exists()) {
        var multipartFile = await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        );
        request.files.add(multipartFile);
      }

      var streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );

      var response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Failed to update property',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteProperty(int propertyId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/properties/$propertyId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': responseData['message'] ?? 'Failed to delete property',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/transactions'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> addTransaction(
      Map<String, dynamic> transactionData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/transactions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(transactionData),
          )
          .timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No authentication token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Connection error: ${e.toString()}'};
    }
  }

  // Method untuk logout
  static Future<void> logout() async {
    await clearToken();
  }

  // Method untuk check apakah user sudah login
  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }
}
