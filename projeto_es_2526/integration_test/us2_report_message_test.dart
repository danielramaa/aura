// ============================================================
// Testes de Aceitação – User Story 2
// Denunciar Conteúdo Impróprio ou Desinformação Médica
// Ferramenta: Flutter Integration Tests
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:projeto_es_2526/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────
  // CENÁRIO A – Denúncia bem-sucedida
  // ──────────────────────────────────────────────────────────
  group('Cenário A – Denúncia de mensagem ofensiva com sucesso', () {
    // A1 – Long press numa mensagem exibe a opção "Denunciar"
    testWidgets(
      'A1: Long press numa mensagem deve exibir a opção "Denunciar" em destaque',
      (WidgetTester tester) async {
        // Arrange: arrancar a app e navegar para uma sala de chat
        app.main();
        await tester.pumpAndSettle();

        // Localizar a bolha de mensagem alvo
        final messageBubble = find.byKey(const Key('message_bubble_0'));
        expect(messageBubble, findsOneWidget);

        // Act: long press na mensagem
        await tester.longPress(messageBubble);
        await tester.pumpAndSettle();

        // Assert: menu contextual visível com opção "Denunciar" em destaque
        final reportOption = find.text('Denunciar');
        expect(
          reportOption,
          findsOneWidget,
          reason: 'A opção "Denunciar" deve aparecer no menu contextual',
        );

        // Verificar destaque visual (cor diferente das outras opções)
        final reportWidget = tester.widget<Text>(reportOption);
        expect(
          reportWidget.style?.color,
          isNotNull,
          reason: 'A opção "Denunciar" deve ter cor em destaque',
        );
      },
    );

    // A2 – Após confirmar o motivo, a mensagem desaparece com confirmação
    testWidgets(
      'A2: Após selecionar motivo e confirmar, mensagem desaparece com confirmação de sucesso',
      (WidgetTester tester) async {
        // Arrange
        app.main();
        await tester.pumpAndSettle();

        // Long press para abrir menu
        final messageBubble = find.byKey(const Key('message_bubble_0'));
        await tester.longPress(messageBubble);
        await tester.pumpAndSettle();

        // Tocar em "Denunciar"
        await tester.tap(find.text('Denunciar'));
        await tester.pumpAndSettle();

        // Act: selecionar motivo "Desinformação médica" no diálogo
        final reasonOption = find.text('Desinformação médica');
        expect(reasonOption, findsOneWidget);
        await tester.tap(reasonOption);
        await tester.pumpAndSettle();

        // Confirmar a denúncia
        final confirmButton = find.text('Confirmar');
        expect(confirmButton, findsOneWidget);
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Assert 1: mensagem denunciada já não aparece no ecrã
        expect(
          find.byKey(const Key('message_bubble_0')),
          findsNothing,
          reason: 'A mensagem denunciada deve desaparecer do ecrã',
        );

        // Assert 2: snackbar/toast de confirmação de sucesso visível
        expect(
          find.text('Denúncia enviada com sucesso'),
          findsOneWidget,
          reason: 'Deve aparecer uma confirmação de sucesso visível',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────
  // CENÁRIO B – Falha de rede na submissão
  // ──────────────────────────────────────────────────────────
  group('Cenário B – Falha de rede ao submeter denúncia', () {
    // B1 – Falha de rede mostra aviso discreto com "Tentar Novamente"
    testWidgets(
      'B1: Falha de rede deve mostrar aviso discreto com opção "Tentar Novamente"',
      (WidgetTester tester) async {
        // Arrange: simular falha de rede (mock do serviço de denúncias)
        // Exemplo: MockReportService().throwNetworkException()
        app.main();
        await tester.pumpAndSettle();

        // Long press + selecionar "Denunciar"
        final messageBubble = find.byKey(const Key('message_bubble_0'));
        await tester.longPress(messageBubble);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Denunciar'));
        await tester.pumpAndSettle();

        // Selecionar motivo e confirmar (mesmo fluxo do cenário A)
        await tester.tap(find.text('Desinformação médica'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        // Assert 1: aviso de erro de rede é exibido de forma discreta
        expect(
          find.text('Erro de ligação'),
          findsOneWidget,
          reason: 'Deve aparecer um aviso de falha de rede',
        );

        // Assert 2: botão "Tentar Novamente" disponível
        final retryButton = find.text('Tentar Novamente');
        expect(
          retryButton,
          findsOneWidget,
          reason: 'Deve existir a opção "Tentar Novamente"',
        );

        // Act: clicar em "Tentar Novamente" (simular rede restaurada)
        await tester.tap(retryButton);
        await tester.pumpAndSettle();

        // Assert 3: após retry bem-sucedido, mensagem desaparece
        expect(
          find.byKey(const Key('message_bubble_0')),
          findsNothing,
          reason: 'Após retry bem-sucedido, mensagem deve ser removida',
        );
      },
    );
  });
}
