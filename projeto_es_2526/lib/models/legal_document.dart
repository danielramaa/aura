enum LegalDocumentType { terms, privacyPolicy }

class LegalDocument {
  final LegalDocumentType type;
  final String title;
  final String version;
  final String content;

  const LegalDocument({
    required this.type,
    required this.title,
    required this.version,
    required this.content,
  });
}

class LegalDocuments {
  static const termsVersion = '1.0';
  static const privacyPolicyVersion = '1.0';

  static const terms = LegalDocument(
    type: LegalDocumentType.terms,
    title: 'Termos e Condições',
    version: termsVersion,
    content: '''
Termos e Condições

Última atualização: 22/05/2026

1. Aceitação dos termos
Ao criar uma conta, concorda em cumprir estes Termos e Condições. Deve fornecer informações de registo precisas e ter pelo menos 13 anos para utilizar esta plataforma. Se não concordar com alguma parte destes termos, não poderá utilizar a aplicação.

2. Utilização da aplicação
Esta aplicação oferece salas de chat anónimas para apoio emocional. Concorda em tratar todos os membros com respeito. Não pode utilizar a app para assediar outros, espalhar desinformação médica, vender ou promover medicamentos sujeitos a receita médica, ou partilhar links maliciosos. A funcionalidade de anonimato foi concebida para proteger a sua privacidade, não para ocultar comportamentos abusivos.

3. Responsabilidades do utilizador
É responsável por manter a confidencialidade das credenciais da sua conta. Embora a aplicação gere uma identidade anónima para si em cada sala, não deve partilhar informações pessoais identificáveis (como o seu nome real, número de telefone ou endereço de e-mail) nos chats públicos, para garantir a sua própria segurança.

4. Informações de saúde e comunidade
AVISO IMPORTANTE: O conteúdo partilhado nesta aplicação por outros utilizadores destina-se apenas a fins informativos e de apoio emocional. NÃO substitui o aconselhamento, diagnóstico ou tratamento médico profissional. Procure sempre o conselho do seu médico ou de um profissional de saúde qualificado para qualquer questão que possa ter sobre uma condição médica ou medicação.

5. Suspensão de conta
Reservamo-nos o direito de limitar, aplicar uma suspensão temporária ou permanente à sua conta sem aviso prévio caso viole estes termos. Isto inclui, mas não se limita a, usar discurso de ódio, praticar bullying, partilhar conteúdo ilegal ou colocar em risco a segurança da comunidade.

6. Alterações a estes termos
Podemos atualizar estes termos ocasionalmente para refletir alterações na nossa aplicação ou requisitos legais. Iremos notificá-lo de quaisquer alterações significativas através de uma notificação na aplicação ou por e-mail antes de entrarem em vigor.

7. Contacto
Se tiver alguma dúvida ou preocupação sobre estes Termos, contacte-nos através de suporte@aura.com.
''',
  );

  static const privacyPolicy = LegalDocument(
    type: LegalDocumentType.privacyPolicy,
    title: 'Política de Privacidade',
    version: privacyPolicyVersion,
    content: '''
Política de Privacidade

Última atualização: 22/05/2026

1. Dados que recolhemos
Recolhemos informações padrão de conta (E-mail e Data de Nascimento) durante o registo para verificar a sua elegibilidade. Também recolhemos dados específicos da app, como as condições de saúde que escolhe seguir, identificadores de dispositivo para notificações push e as suas mensagens de chat.

2. Como utilizamos os dados
Os seus dados de perfil real são utilizados estritamente para autenticação e recuperação de conta. As suas condições de saúde são usadas para organizar o seu diretório de salas. Dentro das salas de chat, a sua verdadeira identidade é completamente ocultada; utilizamos um sistema automatizado para gerar e atribuir-lhe nomes e avatares anónimos distintos para cada sala específica, protegendo a sua privacidade enquanto lhe permite comunicar.

3. Armazenamento de dados
Os seus dados são armazenados de forma segura utilizando encriptação padrão da indústria. Empregamos uma arquitetura rigorosa de isolamento de dados: as suas mensagens públicas de chat estão ligadas APENAS à sua identidade anónima específica da sala, e não aos seus dados de perfil real. Isto garante que a sua atividade pública não possa ser rastreada até à sua verdadeira identidade por outros utilizadores.

4. Partilha de dados
Não vendemos os seus dados pessoais a terceiros. Utilizamos serviços externos exclusivamente para operar a aplicação. Nenhuma informação de identificação pessoal é partilhada com estes serviços. Apenas divulgaremos as suas informações reais às autoridades se estritamente exigido por um pedido legal válido ou em situações de emergência que envolvam uma ameaça imediata à vida.

5. Direitos do utilizador
Ao abrigo do RGPD, tem o direito de aceder, corrigir ou eliminar os seus dados pessoais. Pode solicitar exportar os seus dados ou eliminar permanentemente a sua conta diretamente através das definições de privacidade na aplicação.

6. Retenção de dados
Mantemos os seus dados enquanto a sua conta estiver ativa. Se optar por eliminar a sua conta, existe um período de tolerância de 30 dias durante o qual os seus dados ficam ocultos, após o qual são permanentemente apagados das nossas bases de dados ativas.

7. Contacto
Para quaisquer pedidos relacionados com a privacidade ou questões sobre como os seus dados são tratados, contacte o nosso Encarregado da Proteção de Dados através de privacidade@oseudominio.com.
''',
  );
}
