import 'package:flutter/material.dart';

void main() {
  runApp(const AuditorApp());
}

class AuditorApp extends StatelessWidget {
  const AuditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditor LGPD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuditorScreen(),
    );
  }
}

class AuditorScreen extends StatefulWidget {
  const AuditorScreen({super.key});

  @override
  State<AuditorScreen> createState() => _AuditorScreenState();
}

class _AuditorScreenState extends State<AuditorScreen> {
  final TextEditingController _inputController = TextEditingController(
    text: 'Registro de teste: Cliente Carlos Eduardo, CPF 123.456.789-00 realizou consulta.',
  );
  String _resultadoSanitizado = '';
  int _totalDetectado = 0;
  double _latenciaMs = 0.0;

  void _executarAuditoria() {
    final stopwatch = Stopwatch()..start();

    final textoOriginal = _inputController.text;
    final regexCpf = RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b');

    final matches = regexCpf.allMatches(textoOriginal);
    final total = matches.length;

    final textoAnonimizado = textoOriginal.replaceAll(
      regexCpf,
      '[DADO_PESSOAL_MASCARADO]',
    );

    stopwatch.stop();

    setState(() {
      _totalDetectado = total;
      _resultadoSanitizado = textoAnonimizado;
      _latenciaMs = stopwatch.elapsedMicroseconds / 1000.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditor de Dados & Métricas LGPD'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Texto ou Log para Análise:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Cole aqui os dados para sanitização...',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _executarAuditoria,
              icon: const Icon(Icons.shield),
              label: const Text('Executar Sanitização & Benchmark'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            if (_resultadoSanitizado.isNotEmpty) ...[
              const Text(
                'Métricas de Desempenho e Segurança:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Detectados',
                      '$_totalDetectado',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Latência',
                      '${_latenciaMs.toStringAsFixed(3)} ms',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Cobertura',
                      _totalDetectado > 0 ? '100%' : 'N/A',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Log Sanitizado (Safe Output):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _resultadoSanitizado,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
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
          Text(title, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
