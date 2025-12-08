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
  final String apiBaseUrl = "http://192.168.63.195:8000";
  late final ApiService api;

  String? imagePath;
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;
  String statusText = "Hasil deteksi akan muncul di sini";

  Map<String, dynamic>? lastResult;

  @override
  void initState() {
    super.initState();
    api = ApiService(baseUrl: apiBaseUrl);
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file != null) {
        setState(() {
          imagePath = file.path;
          lastResult = null;
          statusText = "Gambar siap untuk deteksi";
        });
      }
    } catch (e) {
      setState(() => statusText = "Gagal mengambil gambar: $e");
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
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null;

    return Scaffold(
      // ================= BEAUTIFUL BACKGROUND WITH GRADIENT =================
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A5AE0),
              Color(0xFF8A73F5),
              Color(0xFFB9A7FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [
              // ================= HEADER =================
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ================= WHITE CONTAINER =================
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),

                  child: Column(
                    children: [
                      // IMAGE PREVIEW
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: imagePath == null
                            ? const Center(
                                child: Text(
                                  "Belum ada gambar\nSilakan ambil atau pilih foto",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  File(imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),

                      const SizedBox(height: 18),

                      // BUTTONS CAMERA & GALLERY
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => pickImage(ImageSource.camera),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A5AE0),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt),
                                  SizedBox(width: 8),
                                  Text("Camera"),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => pickImage(ImageSource.gallery),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8A73F5),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library),
                                  SizedBox(width: 8),
                                  Text("Gallery"),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // BUTTON DETECT
                      ElevatedButton(
                        onPressed: (!hasImage || isLoading) ? null : predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F3CC9),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Deteksi (Upload ke API)"),
                      ),

                      const SizedBox(height: 20),

                      // ================= BEAUTIFUL RESULT BOX =================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFB9A7FF),
                              Color(0xFFD6C9FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon bulat
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in,
                                color: Color(0xFF4F3CC9),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Result
                            Expanded(child: _resultBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}