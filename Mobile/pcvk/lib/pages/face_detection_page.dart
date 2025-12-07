import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pcvk/services/api_service.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key, required this.title});

  final String title;

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  // GANTI sesuai environment kamu:
  // Emulator Android: http://10.0.2.2:8000
  // iOS simulator: http://localhost:8000
  // HP fisik: http://IP_LAPTOP:8000
  final String apiBaseUrl = "http://192.168.1.15:8000";

  late final ApiService api;

  String? imagePath;
  final ImagePicker picker = ImagePicker();

  bool isLoading = false;
  String statusText = "Hasil deteksi akan muncul di sini";

  Map<String, dynamic>? lastResult; // simpan JSON dari API

  @override
  void initState() {
    super.initState();
    api = ApiService(baseUrl: apiBaseUrl);
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 90, // optional: kompres sedikit
      );
      if (file != null) {
        setState(() {
          imagePath = file.path;
          lastResult = null;
          statusText = "Gambar siap untuk deteksi";
        });
      }
    } catch (e) {
      setState(() {
        statusText = "Gagal mengambil gambar: $e";
      });
    }
  }

  Future<void> predict() async {
    if (imagePath == null) {
      setState(() => statusText = "Pilih/ambil gambar dulu ya.");
      return;
    }

    setState(() {
      isLoading = true;
      statusText = "Mengirim gambar ke server...";
    });

    try {
      final result = await api.detectHijab(File(imagePath!));

      setState(() {
        lastResult = result;
        statusText = "Deteksi selesai ✅";
      });
    } catch (e) {
      setState(() {
        lastResult = null;
        statusText = "Error: $e";
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _resultBox() {
    if (lastResult == null) {
      return Text(
        statusText,
        style: const TextStyle(fontSize: 16),
      );
    }

    final label = lastResult!["label"]?.toString() ?? "-";
    final score = lastResult!["score"];
    final thr = lastResult!["threshold"];
    final margin = lastResult!["margin_from_threshold"];

    String fmtNum(dynamic v) {
      if (v == null) return "-";
      if (v is num) return v.toStringAsFixed(6);
      return v.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hasil: $label",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text("Score: ${fmtNum(score)}"),
        Text("Threshold: ${fmtNum(thr)}"),
        Text("Margin: ${fmtNum(margin)}"),
        const SizedBox(height: 10),
        Text(
          statusText,
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: imagePath == null
                  ? const Center(
                      child: Text(
                        "Belum ada gambar\nSilakan ambil atau pilih foto",
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Tombol kamera & galeri
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isLoading ? null : () => pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isLoading ? null : () => pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tombol detect
            ElevatedButton.icon(
              onPressed: (!hasImage || isLoading) ? null : predict,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(isLoading ? "Memproses..." : "Deteksi (Upload ke API)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 16),

            // Box hasil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _resultBox(),
            ),
          ],
        ),
      ),
    );
  }
}
