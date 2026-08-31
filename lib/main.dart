import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ConsultaPublicaApp());
}

class ConsultaPublicaApp extends StatelessWidget {
  const ConsultaPublicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta Dados Públicos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ConsultaScreen(),
    );
  }
}

class ConsultaScreen extends StatefulWidget {
  const ConsultaScreen({super.key});

  @override
  State<ConsultaScreen> createState() => _ConsultaScreenState();
}

class _ConsultaScreenState extends State<ConsultaScreen> {
  final TextEditingController _cnpjController = TextEditingController(
    text: '00000000000191', // Exemplo: Banco do Brasil
  );

  bool _carregando = false;
  Map<String, dynamic>? _dadosRetornados;
  String _erro = '';
  double _latenciaMs = 0.0;
  int _tamanhoPayloadBytes = 0;

  Future<void> _consultarApi() async {
    final cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'\D'), '');

    if (cnpjLimpo.length != 14) {
      setState(() {
        _erro = 'Por favor, insira um CNPJ válido com 14 dígitos.';
        _dadosRetornados = null;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = '';
      _dadosRetornados = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpjLimpo');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _dadosRetornados = decoded;
          _latenciaMs = stopwatch.elapsedMicroseconds / 1000.0;
          _tamanhoPayloadBytes = response.bodyBytes.length;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _erro = 'Registro não encontrado na base pública.';
        });
      } else {
        setState(() {
          _erro = 'Erro na requisição: Código HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _erro = 'Falha na conexão: Verifique a internet.';
      });
    } finally {
      setState(() {
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditor de Dados Públicos & API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Consulta de Base Pública (Dados Abertos):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cnpjController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Digite o CNPJ (somente números)...',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _carregando ? null : _consultarApi,
              icon: _carregando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_carregando ? 'Consultando...' : 'Consultar Base Oficial'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            if (_erro.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _erro,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            if (_dadosRetornados != null) ...[
              const Text(
                'Métricas da Requisição (TCC):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Latência da API',
                      '${_latenciaMs.toStringAsFixed(1)} ms',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Status HTTP',
                      '200 OK',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Payload',
                      '$_tamanhoPayloadBytes B',
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Dados Retornados (Base Pública):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Razão Social', _dadosRetornados!['razao_social'] ?? 'N/A'),
                      _buildInfoRow('Nome Fantasia', _dadosRetornados!['nome_fantasia'] ?? 'N/A'),
                      _buildInfoRow('CNPJ', _dadosRetornados!['cnpj'] ?? 'N/A'),
                      _buildInfoRow('Situação Cadastral', _dadosRetornados!['descricao_situacao_cadastral'] ?? 'N/A'),
                      _buildInfoRow('CNAE Principal', _dadosRetornados!['cnae_fiscal_descricao'] ?? 'N/A'),
                      _buildInfoRow('Município / UF', '${_dadosRetornados!['municipio'] ?? ''} - ${_dadosRetornados!['uf'] ?? ''}'),
                      _buildInfoRow('Logradouro', '${_dadosRetornados!['logradouro'] ?? ''}, ${_dadosRetornados!['numero'] ?? ''}'),
                      _buildInfoRow('Bairro', _dadosRetornados!['bairro'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
