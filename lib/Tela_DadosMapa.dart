import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'LogicaMapa.dart';
import 'TelaAvaliacao.dart';

class TimerScreen extends StatefulWidget {
  final String emergenciaId;
  final String atendimentoId;

  const TimerScreen({super.key, required this.emergenciaId, required this.atendimentoId});

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int minutes = 1;
  int seconds = 50;
  Timer? timer;

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
      if (kDebugMode) {
        print('Permissão de localização concedida');
      }
    } else {
      // A permissão foi negada ou ainda não foi concedida
      if (kDebugMode) {
        print('Permissão de localização negada');
      }
    }
  }

  Future<void> enviarLocalizacao() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('Atendimentos')
          .doc(widget.atendimentoId)
          .get();

      if (docSnapshot.exists) {
        GeoPoint userLocationGeoPoint =
        GeoPoint(userLocation.latitude, userLocation.longitude);
        await FirebaseFirestore.instance
            .collection('Atendimentos')
            .doc(widget.atendimentoId)
            .update({'geolocalizacaoEmergencia': userLocationGeoPoint});

        DocumentSnapshot updatedDocSnapshot = await FirebaseFirestore.instance
            .collection('Atendimentos')
            .doc(widget.atendimentoId)
            .get();

        if (updatedDocSnapshot.exists) {
          var data = updatedDocSnapshot.data() as Map<String, dynamic>;
          GeoPoint dentistLocation = data['geolocalizacaoDentista'];

          if (dentistLocation.latitude == 0 && dentistLocation.longitude == 0) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Aguarde'),
                content: Text('Aguarde o dentista enviar a localização.'),
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
          } else {
            LatLng dentistLatLng = LatLng(
              dentistLocation.latitude,
              dentistLocation.longitude,
            );

            abrirTelaMapa(userLocation, dentistLatLng);
          }
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Erro'),
              content: Text('O documento não foi atualizado corretamente.'),
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
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro'),
          content: const Text('Ocorreu um erro ao enviar a localização.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void abrirTelaMapa(LatLng? userLocation, LatLng? dentistLocation) {
    Set<Marker> markers = {};
    if (kDebugMode) {//teste
      print(userLocation);
    }
    if (kDebugMode) {//teste
      print(dentistLocation);
    }
    if (userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('userLocation'),
          position: userLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Usuário'),
        ),
      );
    }

    if (dentistLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dentistLocation'),
          position: dentistLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dentista'),
        ),
      );
    }

    if (kDebugMode) {//finalmente
      print(userLocation);
    }
    if (kDebugMode) {//finalmente
      print(dentistLocation);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          userLocation: userLocation ?? const LatLng(0, 0),
          dentistLocation: dentistLocation ?? const LatLng(0, 0),
          markers: markers,
        ),
      ),
    );
  }

  void abrirTelaAvaliacao() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvaliacaoPage(atendimentoId: widget.atendimentoId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tempo de espera'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Tempo Restante:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                solicitarPermissaoLocalizacao();
              },
              child: const Text('Permitir Localização'),
            ),
            ElevatedButton(
              onPressed: () {
                enviarLocalizacao();
              },
              child: const Text('Enviar Localização'),
            ),
            ElevatedButton(
              onPressed: () {
                abrirTelaAvaliacao();
              },
              child: const Text('Avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}