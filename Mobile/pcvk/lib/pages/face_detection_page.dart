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
  final String apiBaseUrl = "http://192.168.1.81:8000";
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

  String fmtNum(dynamic v, {int decimals = 2}) {
    if (v == null) return "-";
    if (v is num) return v.toStringAsFixed(decimals);
    return v.toString();
  }

  Widget _buildResultCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isPositive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isPositive ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _resultBox() {
    if (lastResult == null) {
      return Text(
        statusText,
        style: const TextStyle(fontSize: 16),
      );
    }

    // === Parse Hijab Detection ===
    final hijabData = lastResult!["hijab_detection"] as Map<String, dynamic>?;
    final hijabLabel = hijabData?["label"]?.toString() ?? "-";
    final hijabScore = hijabData?["score"];
    final hijabThreshold = hijabData?["threshold"];
    final hijabMargin = hijabData?["margin_from_threshold"];
    final isHijab = hijabLabel == "HIJAB";

    // === Parse Facial Hair (Kumis) Detection ===
    final facialHairData = lastResult!["facial_hair_detection"] as Map<String, dynamic>?;
    final hasFacialHair = facialHairData?["has_facial_hair"] ?? false;
    final facialHairSuccess = facialHairData?["success"] ?? false;
    final coverage = facialHairData?["coverage_percentage"];
    final confidence = facialHairData?["confidence"];
    final facialHairMessage = facialHairData?["message"]?.toString() ?? "-";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Hijab Detection Card ===
          _buildResultCard(
            title: "Deteksi Hijab",
            icon: Icons.face_retouching_natural,
            iconColor: const Color(0xFF6A5AE0),
            children: [
              _buildStatusChip(
                isHijab ? "Berhijab ✓" : "Tidak Berhijab",
                isHijab,
              ),
              const SizedBox(height: 10),
              _buildInfoRow("Score", fmtNum(hijabScore, decimals: 4)),
              _buildInfoRow("Threshold", fmtNum(hijabThreshold, decimals: 4)),
              _buildInfoRow("Margin", fmtNum(hijabMargin, decimals: 4)),
            ],
          ),

          // === Facial Hair Detection Card ===
          _buildResultCard(
            title: "Deteksi Kumis/Jenggot",
            icon: Icons.face,
            iconColor: const Color(0xFF4CAF50),
            children: [
              if (!facialHairSuccess)
                Text(
                  facialHairMessage,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                )
              else ...[
                _buildStatusChip(
                  hasFacialHair ? "Ada Kumis/Jenggot" : "Tidak Ada Kumis",
                  !hasFacialHair, // Inverted: tidak ada kumis = hijau (positif untuk wanita)
                ),
                const SizedBox(height: 10),
                _buildInfoRow("Coverage", "${fmtNum(coverage)}%"),
                _buildInfoRow("Confidence", fmtNum(confidence)),
                const SizedBox(height: 4),
                Text(
                  facialHairMessage,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),

          // === Status ===
          Text(
            statusText,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
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
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
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
                          child: lastResult == null
                              ? Row(
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
                                    Expanded(child: _resultBox()),
                                  ],
                                )
                              : _resultBox(),
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