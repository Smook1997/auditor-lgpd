import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AuditorComercialApp());
}

class AuditorComercialApp extends StatelessWidget {
  const AuditorComercialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditor de Risco Comercial',
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
      home: const TelaAuditoriaComercial(),
    );
  }
}

class TelaAuditoriaComercial extends StatefulWidget {
  const TelaAuditoriaComercial({super.key});

  @override
  State<TelaAuditoriaComercial> createState() => _TelaAuditoriaComercialState();
}

class _TelaAuditoriaComercialState extends State<TelaAuditoriaComercial> {
  final TextEditingController _cnpjController = TextEditingController(
    text: '00.000.000/0001-91', // Banco do Brasil (Exemplo)
  );

  bool _carregando = false;
  Map<String, dynamic>? _dados;
  String _mensagemErro = '';

  // Variáveis de Análise de Risco
  String _parecerComercial = '';
  Color _corParecer = Colors.green;
  IconData _iconeParecer = Icons.check_circle_rounded;
  int _scoreRisco = 0;
  List<String> _criteriosAvaliados = [];

  void _analisarRiscoComercial(Map<String, dynamic> dados) {
    int pontuacao = 100;
    List<String> criterios = [];

    final situacao = (dados['descricao_situacao_cadastral'] ?? '').toString().toUpperCase();
    final dataAberturaStr = dados['data_inicio_atividade'] ?? '';
    final capitalSocial = double.tryParse(dados['capital_social']?.toString() ?? '0') ?? 0;

    // 1. Checagem da Situação Cadastral na Receita
    if (situacao == 'ATIVA') {
      criterios.add('✓ CNPJ Regular e Ativo na Receita Federal');
    } else {
      pontuacao -= 70;
      criterios.add('✗ CNPJ $situacao (Risco Crítico)');
    }

    // 2. Tempo de Fundação / Maturidade da Empresa
    if (dataAberturaStr.isNotEmpty) {
      try {
        final dataAbertura = DateTime.parse(dataAberturaStr);
        final diferencaDias = DateTime.now().difference(dataAbertura).inDays;
        final anosEmpresa = (diferencaDias / 365).floor();

        if (anosEmpresa >= 2) {
          criterios.add('✓ Empresa madura ($anosEmpresa anos de mercado)');
        } else if (anosEmpresa >= 1) {
          pontuacao -= 10;
          criterios.add('⚠ Empresa com cerca de 1 ano de atividade');
        } else {
          pontuacao -= 25;
          criterios.add('⚠ Empresa recente (menos de 1 ano de abertura)');
        }
      } catch (_) {
        criterios.add('• Tempo de mercado não identificado');
      }
    }

    // 3. Estrutura de Capital
    if (capitalSocial > 0) {
      criterios.add('✓ Capital social declarado e registrado');
    } else {
      pontuacao -= 10;
      criterios.add('⚠ Capital social zerado ou não informado');
    }

    // Classificação Final
    if (pontuacao >= 75) {
      _parecerComercial = 'APROVADO / RECOMENDADO';
      _corParecer = const Color(0xFF2B8A3E); // Verde escuro
      _iconeParecer = Icons.verified_user_rounded;
    } else if (pontuacao >= 50) {
      _parecerComercial = 'ATENÇÃO / RISCO MODERADO';
      _corParecer = const Color(0xFFE67700); // Laranja
      _iconeParecer = Icons.warning_amber_rounded;
    } else {
      _parecerComercial = 'NÃO RECOMENDADO / NEGADO';
      _corParecer = const Color(0xFFC92A2A); // Vermelho
      _iconeParecer = Icons.cancel_rounded;
    }

    _scoreRisco = pontuacao.clamp(0, 100);
    _criteriosAvaliados = criterios;
  }

  Future<void> _realizarAuditoria() async {
    final cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'\D'), '');

    if (cnpjLimpo.length != 14) {
      setState(() {
        _mensagemErro = 'CNPJ inválido. Digite os 14 dígitos numéricos.';
        _dados = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _carregando = true;
      _mensagemErro = '';
      _dados = null;
    });

    try {
      final url = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpjLimpo');
      final resposta = await http.get(url).timeout(const Duration(seconds: 12));

      if (resposta.statusCode == 200) {
        final Map<String, dynamic> corpo = json.decode(utf8.decode(resposta.bodyBytes));
        setState(() {
          _dados = corpo;
          _analisarRiscoComercial(corpo);
        });
      } else if (resposta.statusCode == 404) {
        setState(() {
          _mensagemErro = 'CNPJ não encontrado nas bases oficiais do Governo.';
        });
      } else {
        setState(() {
          _mensagemErro = 'Erro ao consultar a base oficial (${resposta.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _mensagemErro = 'Erro de conexão. Verifique o acesso à internet.';
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
          'Auditor de Risco Comercial',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de Busca
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auditoria de Compliance & Crédito',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Consulte a saúde cadastral da empresa antes de fechar negócios, parcerias ou vendas a prazo.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _cnpjController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '00.000.000/0001-91',
                          labelText: 'Número do CNPJ',
                          filled: true,
                          fillColor: const Color(0xFFF1F3F5),
                          prefixIcon: const Icon(Icons.business_rounded),
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _carregando ? null : _realizarAuditoria,
                          icon: _carregando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Icon(Icons.shield_outlined),
                          label: Text(
                            _carregando ? 'Auditando...' : 'Avaliar Risco Comercial',
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

              // Mensagem de Erro
              if (_mensagemErro.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF8787)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE03131)),
                      const SizedBox(width: 8),
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

              // RESULTADO DA ANÁLISE COMERCIAL
              if (_dados != null) ...[
                const SizedBox(height: 20),

                // Card Parecer Geral (Aprovado / Negado)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _corParecer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _corParecer.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_iconeParecer, color: _corParecer, size: 28),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _parecerComercial,
                              style: TextStyle(
                                color: _corParecer,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score de Conformidade: $_scoreRisco / 100',
                        style: TextStyle(
                          color: _corParecer,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Critérios e Checklist Legal
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CRITÉRIOS DE AVALIAÇÃO LEGAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._criteriosAvaliados.map(
                          (criterio) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              criterio,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Dados Cadastrais Oficiais
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REGISTRO OFICIAL NA RECEITA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Divider(height: 16, color: Color(0xFFF1F3F5)),
                        _itemInfo('Razão Social', _dados!['razao_social'] ?? 'Não informado'),
                        _itemInfo('Nome Fantasia', _dados!['nome_fantasia'] ?? 'Não registrado'),
                        _itemInfo('Atividade (CNAE)', _dados!['cnae_fiscal_descricao'] ?? 'Não informado'),
                        _itemInfo('Endereço', '${_dados!['logradouro'] ?? ''}, ${_dados!['numero'] ?? 'S/N'} - ${_dados!['municipio'] ?? ''}/${_dados!['uf'] ?? ''}'),
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

  Widget _itemInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.bold),
          ),
          SelectableText(
            valor.trim().isEmpty ? 'Não informado' : valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
