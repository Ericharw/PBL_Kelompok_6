import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> detectHijab(File imageFile) async {
    final uri = Uri.parse("$baseUrl/detect");
    final request = http.MultipartRequest("POST", uri);

    final p = imageFile.path.toLowerCase();
    final MediaType mediaType =
        p.endsWith(".png") ? MediaType("image", "png") : MediaType("image", "jpeg");

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        imageFile.path,
        contentType: mediaType,
        filename: p.endsWith(".png") ? "upload.png" : "upload.jpg",
      ),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded["detail"] != null) {
          throw Exception(decoded["detail"].toString());
        }
      } catch (_) {}
      throw Exception("Request gagal (${streamed.statusCode}): $body");
    }

    final decoded = jsonDecode(body);
    return decoded as Map<String, dynamic>;
  }
}
