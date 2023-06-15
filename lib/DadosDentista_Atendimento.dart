import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Tela_DadosMapa.dart';


class DadosDentistasTela extends StatefulWidget {
  final String emergenciaId;

  const DadosDentistasTela({super.key, required this.emergenciaId});

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

  void criarAtendimento(
      int index,
      double latitudeDentista,
      double longitudeDentista,
      double latitudeEmergencia,
      double longitudeEmergencia,
      ) {
    String dentistaId = listaDentistas[index]['dentistaId'];
    String emergenciaId = widget.emergenciaId;

    // Crie objetos GeoPoint com as coordenadas de geolocalização
    GeoPoint geolocalizacaoDentista = GeoPoint(latitudeDentista, longitudeDentista);
    GeoPoint geolocalizacaoEmergencia = GeoPoint(latitudeEmergencia, longitudeEmergencia);

    FirebaseFirestore.instance
        .collection('Emergencias')
        .doc(emergenciaId)
        .get()
        .then((docSnapshot) {
      if (docSnapshot.exists) {
        var emergenciaData = docSnapshot.data();
        String nomeEmergencia = emergenciaData?['nome'];
        String telefoneEmergencia = emergenciaData?['telefone'];

        Map<String, dynamic> atendimento = {
          'dentista': dentistaId,
          'emergencia': emergenciaId,
          'statusPendente': true,
          'geolocalizacaoDentista': geolocalizacaoDentista,
          'geolocalizacaoEmergencia': geolocalizacaoEmergencia,
          'nome': nomeEmergencia,
          'telefone': telefoneEmergencia,
          'estrelasProfissional': null, // Campo inicialmente nulo para a avaliação
          'comentarioAtendimento': null, // Campo inicialmente nulo para a avaliação
          'notaApp': null, // Campo inicialmente nulo para a avaliação
          'comentarioApp': null, // Campo inicialmente nulo para a avaliação
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
                atendimentoId: atendimentoId, // Passa o ID do documento de atendimento para a próxima tela
              ),
            ),
          );
        });
      } else {
        if (kDebugMode) {//teste
          print('Documento de emergência não encontrado.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados dos Dentistas'),
      ),
      body: listaDentistas.isEmpty
          ? const Text('Nenhum dentista encontrado no documento')
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
              child: const Text('Aceitar'),
            ),
          );
        },
      ),
    );
  }
}