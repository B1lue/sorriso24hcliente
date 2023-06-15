import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'DadosDentista_Atendimento.dart';

class DadosUsuarioTela extends StatefulWidget {
  final CameraDescription camera;
  const DadosUsuarioTela({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  _DadosUsuarioTelaState createState() => _DadosUsuarioTelaState();
}

class _DadosUsuarioTelaState extends State<DadosUsuarioTela> {
  bool _uploading = false;
  double _uploadProgress = 0.0;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final List<File> _imageFiles = [];

  get customFileName_ => null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: ImageSource.camera);

    setState(() {
      if (pickedImage != null) {
        _imageFiles.add(File(pickedImage.path));
      }
    });
  }

  Future<void> _uploadData() async {
    if (_imageFiles.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Fotos não tiradas'),
            content: const Text('Por favor, tire fotos antes de enviar os dados.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      // Salve os dados do usuário no Firestore
      DocumentReference documentReference = await FirebaseFirestore.instance.collection('Emergencias').add({
        'nome': _nameController.text,
        'telefone': _phoneController.text,
        'statusEncerrada': false,
      });

      String emergenciaId = documentReference.id; // Armazena o ID do documento

      for (int i = 0; i < _imageFiles.length; i++) {
        // Crie uma referência para o arquivo de imagem usando o ID do documento
        String customFileName_ = emergenciaId;
        Reference storageReference =
        FirebaseStorage.instance.ref().child('images/$customFileName_${i + 1}');

        // Faça o upload do arquivo para o Firebase Storage
        UploadTask uploadTask = storageReference.putFile(File(_imageFiles[i].path));

        // Monitore o progresso do upload
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress = progress;
          });
        });

        // Aguarde o término do upload
        await uploadTask.whenComplete(() {
          setState(() {
            _uploading = false;
          });
        });

        // Obtenha a URL de download do arquivo
        String imageUrl = await storageReference.getDownloadURL();

        // Atualize o documento com a URL da imagem
        await documentReference.update({'image_url_${i + 1}': imageUrl});
      }

      // Redirecione para a tela de dentista
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DadosDentistasTela(emergenciaId: emergenciaId),
        ),
      );

    } catch (error) {

      showDialog(

        context: context,

        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Erro'),
            content: Text('Ocorreu um erro ao enviar os dados: $error'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados do Usuário')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o nome';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o telefone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _imageFiles.length; i++)
                      Container(
                        margin: const EdgeInsets.all(20.0),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: FileImage(_imageFiles[i]),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _captureImage,
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(200, 50),
                  ),
                  child: const Text('Tirar Foto'),
                ),
                ElevatedButton(
                  onPressed: _uploadData,
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(200, 50),
                  ),
                  child: const Text('Enviar Dados'),
                ),
                if (_uploading) // Mostrar ProgressBar somente durante o upload
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[300], // Cor de fundo da ProgressBar
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green), // Cor do preenchimento da ProgressBar
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
