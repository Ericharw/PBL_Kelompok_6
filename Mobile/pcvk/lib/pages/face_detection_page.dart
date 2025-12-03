import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({super.key, required this.title});

  final String title;

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  String? imagePath;
  final ImagePicker picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    final XFile? file = await picker.pickImage(source: source);
    if (file != null) {
      setState(() {
        imagePath = file.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Ambil Foto"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text("Pilih dari Galeri"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                imagePath == null
                    ? "Hasil deteksi akan muncul di sini"
                    : "Gambar siap untuk deteksi",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
