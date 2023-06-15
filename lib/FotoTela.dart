import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class PegarFotoTela extends StatefulWidget {
  const PegarFotoTela({super.key});

  @override
  _PegarFotoTelaState createState() => _PegarFotoTelaState();
}

class _PegarFotoTelaState extends State<PegarFotoTela> {
  final List<File> _imageFiles = [];

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.camera);

    setState(() {
      if (pickedImage != null) {
        _imageFiles.add(File(pickedImage.path));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pegar Foto')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageFiles.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _imageFiles.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: FileImage(_imageFiles[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _captureImage,
              style: ButtonStyle(
                fixedSize: MaterialStateProperty.all<Size>(const Size(200, 50)),
              ),
              child: const Text('Tirar Foto'),
            ),
          ],
        ),
      ),
    );
  }
}