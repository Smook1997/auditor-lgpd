import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AuditorDadosApp());
}

class AuditorDadosApp extends StatelessWidget {
  const AuditorDadosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditor de Dados Abertos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0D6EFD),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE9ECEF), width: 1),
          ),
        ),
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final TextEditingController _cnpjController = TextEditingController(
    text: '00.000.000/0001-91',
  );

  bool _carregando = false;
  Map<String, dynamic>? _dados;
  String _mensagemErro = '';
  
  // Métricas Técnicas
  double _latenciaMs = 0.0;
  int _tamanhoBytes = 0;
  int _statusCode = 0;

  Future<void> _realizarConsulta() async {
    final cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'\D'), '');

    if (cnpjLimpo.length != 14) {
      setState(() {
        _mensagemErro = 'CNPJ inválido. Digite os 14 dígitos numéricos.';
        _dados = null;
      });
      return;
    }

    // Fecha o teclado
    FocusScope.of(context).unfocus();

    setState(() {
      _carregando = true;
      _mensagemErro = '';
      _dados = null;
    });

    final cronometro = Stopwatch()..start();

    try {
      final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpjLimpo');
      final resposta = await http.get(url).timeout(const Duration(seconds: 12));

      cronometro.stop();

      setState(() {
        _statusCode = resposta.statusCode;
        _latenciaMs = cronometro.elapsedMicroseconds / 1000.0;
        _tamanhoBytes = resposta.bodyBytes.length;
      });

      if (resposta.statusCode == 200) {
        final Map<String, dynamic> corpoDecodificado = json.decode(
          utf8.decode(resposta.bodyBytes),
        );
        setState(() {
          _dados = corpoDecodificado;
        });
      } else if (resposta.statusCode == 404) {
        setState(() {
          _mensagemErro = 'CNPJ não encontrado na base de dados da Receita Federal.';
        });
      } else {
        setState(() {
          _mensagemErro = 'Serviço indisponível no momento (Código HTTP: ${resposta.statusCode}).';
        });
      }
    } catch (e) {
      cronometro.stop();
      setState(() {
        _mensagemErro = 'Falha de comunicação. Verifique sua conexão com a internet.';
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
        centerTitle: true,
        title: const Text(
          'Auditor de Dados Públicos',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de Entrada / Pesquisa
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.manage_search_rounded, color: Color(0xFF0D6EFD)),
                          SizedBox(width: 8),
                          Text(
                            'Consultar Base Oficial',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Insira o CNPJ da instituição para auditar os registros cadastrais públicos em tempo real.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _cnpjController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '00.000.000/0001-91',
                          labelText: 'Número do CNPJ',
                          filled: true,
                          fillColor: const Color(0xFFF1F3F5),
                          prefixIcon: const Icon(Icons.corporate_fare_rounded),
                          suffixIcon: _cnpjController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _cnpjController.clear(),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _carregando ? null : _realizarConsulta,
                          icon: _carregando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                          label: Text(
                            _carregando ? 'Buscando Dados...' : 'Executar Consulta',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6EFD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Alerta de Erro
              if (_mensagemErro.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF8787)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE03131)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mensagemErro,
                          style: const TextStyle(color: Color(0xFFC92A2A), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Bloco de Métricas Técnicas (TCC)
              if (_dados != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Métricas de Desempenho (Avaliação TCC)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _construirCardMetrica(
                        titulo: 'Latência',
                        valor: '${_latenciaMs.toStringAsFixed(1)} ms',
                        icone: Icons.timer_outlined,
                        cor: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _construirCardMetrica(
                        titulo: 'Status HTTP',
                        valor: '$_statusCode OK',
                        icone: Icons.check_circle_outline,
                        cor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _construirCardMetrica(
                        titulo: 'Payload',
                        valor: '${(_tamanhoBytes / 1024).toStringAsFixed(1)} KB',
                        icone: Icons.data_usage_rounded,
                        cor: const Color(0xFF0D6EFD),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text(
                  'Dados Cadastrais Públicos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),

                // Card Principal dos Dados
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _construirItemDado(
                          label: 'Razão Social',
                          valor: _dados!['razao_social'] ?? 'Não informado',
                          destaque: true,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F3F5)),
                        _construirItemDado(
                          label: 'Nome Fantasia',
                          valor: (_dados!['nome_fantasia'] != null && _dados!['nome_fantasia'].toString().trim().isNotEmpty)
                              ? _dados!['nome_fantasia']
                              : 'Sem nome fantasia registrado',
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F3F5)),
                        _construirItemDado(
                          label: 'Situação Cadastral',
                          valor: _dados!['descricao_situacao_cadastral'] ?? 'Ativa',
                          badgeCor: _dados!['descricao_situacao_cadastral'] == 'ATIVA'
                              ? Colors.green
                              : Colors.red,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F3F5)),
                        _construirItemDado(
                          label: 'Atividade Econômica (CNAE)',
                          valor: _dados!['cnae_fiscal_descricao'] ?? 'Não informado',
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F3F5)),
                        _construirItemDado(
                          label: 'Localização',
                          valor: '${_dados!['logradouro'] ?? ''}, ${_dados!['numero'] ?? 'S/N'} - ${_dados!['bairro'] ?? ''}\n${_dados!['municipio'] ?? ''} / ${_dados!['uf'] ?? ''} - CEP: ${_dados!['cep'] ?? ''}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirCardMetrica({
    required String titulo,
    required String valor,
    required IconData icone,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirItemDado({
    required String label,
    required String valor,
    bool destaque = false,
    Color? badgeCor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black45,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        if (badgeCor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeCor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              valor,
              style: TextStyle(
                color: badgeCor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          )
        else
          SelectableText(
            valor,
            style: TextStyle(
              fontSize: destaque ? 15 : 13,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF212529),
            ),
          ),
      ],
    );
  }
}
