import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
class AvaliacaoPage extends StatefulWidget {
  final String atendimentoId;

  const AvaliacaoPage({super.key, required this.atendimentoId});

  @override
  _AvaliacaoPageState createState() => _AvaliacaoPageState();
}

class _AvaliacaoPageState extends State<AvaliacaoPage> {
  int estrelasProfissional = 0;
  String comentarioAtendimento = '';
  int notaApp = 0;
  String comentarioApp = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliação'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Página de Avaliação',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. De uma nota de 0 a 5 estrelas pelo atendimento do profissional que lhe atendeu:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: estrelasProfissional.toDouble(),
              minRating: 0,
              maxRating: 5,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 40,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  estrelasProfissional = rating.toInt();
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '2. Comente o que achou do atendimento em geral:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  comentarioAtendimento = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Digite seu comentário...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              '3. Dê uma nota para o Sorriso24h aplicativo:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: notaApp.toDouble(),
              minRating: 0,
              maxRating: 5,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 40,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  notaApp = rating.toInt();
                });
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '4. Comente o que você achou do aplicativo:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) {
                setState(() {
                  comentarioApp = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Digite seu comentário...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Implemente aqui a lógica para enviar a avaliação
                enviarAvaliacao();
              },
              child: const Text('Enviar Avaliação'),
            ),
          ],
        ),
      ),
    );
  }

  void enviarAvaliacao() {
    // Crie um mapa com os dados da avaliação
    Map<String, dynamic> avaliacao = {
      'estrelasProfissional': estrelasProfissional,
      'comentarioAtendimento': comentarioAtendimento,
      'notaApp': notaApp,
      'comentarioApp': comentarioApp,
    };

    // Atualize o documento de atendimento com os dados da avaliação
    FirebaseFirestore.instance
        .collection('Atendimentos')
        .doc(widget.atendimentoId)
        .update(avaliacao)
        .then((_) {
      // Envio da avaliação concluído com sucesso
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Avaliação Enviada'),
          content: const Text('Obrigado por enviar sua avaliação!'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Você pode adicionar qualquer ação adicional após enviar a avaliação
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }).catchError((error) {
      // Ocorreu um erro ao enviar a avaliação
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro ao Enviar Avaliação'),
          content: const Text('Ocorreu um erro ao enviar sua avaliação. Tente novamente mais tarde.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Você pode adicionar qualquer ação adicional após o erro de envio da avaliação
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }
}