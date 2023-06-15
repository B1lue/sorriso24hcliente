import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TelaInicial(camera: firstCamera),
    ),
  );
}

class TelaInicial extends StatelessWidget {
  final CameraDescription camera;

  const TelaInicial({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergência')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DadosUsuarioTela(camera: camera),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            primary: Colors.red,
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 16.0,
            ),
          ),
          child: const Text(
            'Chamar Emergência',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}



class PegarFotoTela extends StatefulWidget {
  @override
  _PegarFotoTelaState createState() => _PegarFotoTelaState();
}

class _PegarFotoTelaState extends State<PegarFotoTela> {
  List<File> _imageFiles = [];

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
                        shape: BoxShape.circle,
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
              child: const Text('Tirar Foto'),
            ),
          ],
        ),
      ),
    );
  }
}

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
  List<File> _imageFiles = [];

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados do Usuário')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
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
                children: [
                  for (int i = 0; i < _imageFiles.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(4.0),
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
                    ),
                ],
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _captureImage,
                child: const Text('Tirar Foto'),
              ),
              ElevatedButton(
                onPressed: _uploadData,
                child: const Text('Enviar Dados'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DadosDentistasTela extends StatefulWidget {
  final String emergenciaId;

  DadosDentistasTela({required this.emergenciaId});

  @override
  _DadosDentistasTelaState createState() => _DadosDentistasTelaState();
}

class _DadosDentistasTelaState extends State<DadosDentistasTela> {
  List<Map<String, dynamic>> listaDentistas = [];
  int contador = 1;

  @override
  void initState() {
    super.initState();
    fetchDentistas();
  }
  //remove odentista que na oatendeu
  void removerDentistaSelecionado(int index) {
    setState(() {
      listaDentistas.removeAt(index);
    });
  }
  void fetchDentistas() {
    FirebaseFirestore.instance
        .collection('Emergencias')
        .doc(widget.emergenciaId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic> dadosEmergencia =
        snapshot.data() as Map<String, dynamic>;

        listaDentistas.clear();
        contador = 1;

        dadosEmergencia.forEach((key, value) {
          if (key.startsWith('dentista_')) {
            String dentistaId = value.toString();

            FirebaseFirestore.instance
                .collection('Dentistas')
                .doc(dentistaId)
                .get()
                .then((dentistaSnapshot) {
              if (dentistaSnapshot.exists) {
                Map<String, dynamic> detalhesDentista =
                dentistaSnapshot.data() as Map<String, dynamic>;

                String nomeDentista = detalhesDentista['nome'] ?? '';
                String telefoneDentista = detalhesDentista['telefone'] ?? '';

                listaDentistas.add({
                  'nome': nomeDentista,
                  'telefone': telefoneDentista,
                  'dentistaId': dentistaId,
                });

                setState(() {
                  // Atualiza a interface do usuário com a nova lista de dentistas
                  // após a obtenção dos detalhes de um dentista
                });
              }
            });
          }
        });
      }
    });
  }

  void criarAtendimento(int index, double latitudeDentista, double longitudeDentista, double latitudeEmergencia, double longitudeEmergencia) {
    String dentistaId = listaDentistas[index]['dentistaId'];
    String emergenciaId = widget.emergenciaId;

    // Crie objetos GeoPoint com as coordenadas de geolocalização
    GeoPoint geolocalizacaoDentista = GeoPoint(latitudeDentista, longitudeDentista);
    GeoPoint geolocalizacaoEmergencia = GeoPoint(latitudeEmergencia, longitudeEmergencia);

    Map<String, dynamic> atendimento = {
      'dentista': dentistaId,
      'emergencia': emergenciaId,
      'statusPendente': true,
      'geolocalizacaoDentista': geolocalizacaoDentista,
      'geolocalizacaoEmergencia': geolocalizacaoEmergencia,
    };

    FirebaseFirestore.instance
        .collection('Atendimentos')
        .add(atendimento)
        .then((docRef) {
      String atendimentoId = docRef.id; // ID do documento do atendimento

      setState(() {
        // Atualize a interface do usuário se necessário
        removerDentistaSelecionado(index);
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimerScreen(
            emergenciaId: emergenciaId,
            atendimentoId: docRef.id, // Passa o ID do documento de atendimento para a próxima tela
          ),
        ),
      );
    });
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Dados dos Dentistas'),
        ),
        body: listaDentistas.isEmpty
            ? Text('Nenhum dentista encontrado no documento')
            : ListView.builder(
          itemCount: listaDentistas.length,
          itemBuilder: (context, index) {
            final dentista = listaDentistas[index];
            final String nomeDentista = dentista['nome'];
            final String telefoneDentista = dentista['telefone'];

            return ListTile(
              title: Text('Dentista ${index + 1}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nome: $nomeDentista'),
                  Text('Telefone: $telefoneDentista'),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () {
                  criarAtendimento(
                    index,
                    0.0,  // latitudeDentista (valor padrão ou nulo)
                    0.0,  // longitudeDentista (valor padrão ou nulo)
                    0.0,  // latitudeEmergencia (valor padrão ou nulo)
                    0.0,  // longitudeEmergencia (valor padrão ou nulo)
                  );
                },
                child: Text('Aceitar'),
              ),
            );
          },
        ),
      );
    }
  }

class TimerScreen extends StatefulWidget {
  final String emergenciaId;
  final String atendimentoId;

  TimerScreen({required this.emergenciaId, required this.atendimentoId});

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int minutes = 1;
  int seconds = 50;
  Timer? timer;
  LatLng _dentistLocation = LatLng(0, 0); // Adicione essa linha para definir a variável _dentistLocation
  Set<Marker> _markers = {}; // Adicione essa linha para definir a variável _markers

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    timer = Timer.periodic(oneSec, (timer) {
      setState(() {
        if (seconds > 0) {
          seconds--;
        } else {
          if (minutes > 0) {
            minutes--;
            seconds = 59;
          } else {
            timer.cancel();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> solicitarPermissaoLocalizacao() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      // A permissão foi concedida, você pode prosseguir com o código
      print('Permissão de localização concedida');
    } else {
      // A permissão foi negada ou ainda não foi concedida, você pode lidar com isso aqui
      print('Permissão de localização negada');
    }
  }

  Future<void> enviarLocalizacao(String atendimentoId) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('Atendimentos')
          .doc(atendimentoId)
          .get();

      if (docSnapshot.exists) {
        GeoPoint userLocationGeoPoint =
        GeoPoint(userLocation.latitude, userLocation.longitude);
        await FirebaseFirestore.instance
            .collection('Atendimentos')
            .doc(atendimentoId)
            .update({'geolocalizacaoEmergencia': userLocationGeoPoint});
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Erro'),
            content: Text('O documento não foi encontrado.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
      print(_dentistLocation);
      print(userLocation);
      abrirTelaMapa(userLocation, null);
    } catch (e) {
      print(e);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Erro'),
          content: Text('Ocorreu um erro ao enviar a localização.'),

          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void receberLocalizacao() async {
    DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
        .collection('Atendimentos')
        .doc(widget.atendimentoId)
        .get();

    if (docSnapshot.exists) {
      var data = docSnapshot.data() as Map<String, dynamic>;
      GeoPoint dentistLocation = data['geolocalizacaoDentista'];

      LatLng dentistLatLng = LatLng(
        dentistLocation.latitude,
        dentistLocation.longitude,
      );

      LatLng? userLatLng = null; // Inicializa a variável com valor null

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        userLatLng = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('Erro ao obter a localização do usuário: $e');
      }

      if (userLatLng != null) {
        abrirTelaMapa(userLatLng, dentistLatLng);
      } else {
        // Trate o caso em que a localização do usuário não está disponível
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Erro'),
            content: Text('Não foi possível obter a localização do usuário.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
    print(_dentistLocation);
  }



  void abrirTelaMapa(LatLng? userLocation, LatLng? dentistLocation) {
    Set<Marker> markers = {};

    if (userLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('userLocation'),
          position: userLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Usuário'),
        ),
      );
    }

    if (dentistLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('dentistLocation'),
          position: dentistLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Dentista'),
        ),
      );
    }
    print(_dentistLocation);
    print(userLocation);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          userLocation: userLocation ?? LatLng(0, 0),
          dentistLocation: dentistLocation ?? LatLng(0, 0),
          markers: markers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tempo de espera'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Tempo Restante:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 40),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                solicitarPermissaoLocalizacao();
              },
              child: Text('Permitir Localização'),
            ),
            ElevatedButton(
              onPressed: () {
                enviarLocalizacao(widget.atendimentoId);
              },
              child: Text('Enviar Localização'),
            ),
            ElevatedButton(
              onPressed: () {
                receberLocalizacao();
              },
              child: Text('Receber Localização'),
            ),
            ElevatedButton(
              onPressed: () {
                AvaliacaoPage();
              },
              child: Text('Avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final LatLng userLocation;
  final LatLng dentistLocation;
  final Set<Marker> markers;

  MapScreen({
    required this.userLocation,
    required this.dentistLocation,
    required this.markers,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa'),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: widget.userLocation,
          zoom: 12.0,
        ),
        markers: widget.markers,
      ),
    );
  }
}

class AvaliacaoPage extends StatefulWidget {
  @override
  _AvaliacaoPageState createState() => _AvaliacaoPageState();
}

class _AvaliacaoPageState extends State<AvaliacaoPage> {
  double _rating = 0.0;
  String _comment = '';

  void _submitRating() {
    // Aqui você pode implementar a lógica para enviar a avaliação
    // e fazer o que for necessário com o rating e o comentário.
    print('Rating: $_rating');
    print('Comment: $_comment');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Avaliação'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classificação:',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.star),
                  color: _rating >= 1 ? Colors.yellow : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _rating = 1.0;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.star),
                  color: _rating >= 2 ? Colors.yellow : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _rating = 2.0;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.star),
                  color: _rating >= 3 ? Colors.yellow : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _rating = 3.0;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.star),
                  color: _rating >= 4 ? Colors.yellow : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _rating = 4.0;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.star),
                  color: _rating >= 5 ? Colors.yellow : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _rating = 5.0;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Comentário:',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  _comment = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Digite seu comentário...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _submitRating,
                child: Text('Enviar Avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
