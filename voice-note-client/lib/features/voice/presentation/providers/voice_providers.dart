import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/database_provider.dart';
import '../../../../core/di/network_providers.dart';
import '../../../transaction/presentation/providers/transaction_form_providers.dart';
import '../../data/asr_repository.dart';
import '../../data/llm_repository.dart';
import '../../data/local_nlp_engine.dart';
import '../../data/voice_transaction_service.dart';
import '../../domain/nlp_orchestrator.dart';
import '../../domain/voice_correction_handler.dart';

/// ASR token management (caches tokens, refreshes on expiry).
final asrRepositoryProvider = Provider<AsrRepository>((ref) {
  return AsrRepository(ref.watch(apiClientProvider));
});

/// LLM-based transaction parsing via server API.
final llmRepositoryProvider = Provider<LlmRepository>((ref) {
  return LlmRepository(ref.watch(apiClientProvider));
});

/// On-device NLP engine for zero-cost parsing.
final localNlpEngineProvider = Provider<LocalNlpEngine>((ref) {
  return LocalNlpEngine();
});

/// Local-first NLP with LLM fallback. Skips LLM when offline.
final nlpOrchestratorProvider = Provider<NlpOrchestrator>((ref) {
  return NlpOrchestrator(
    localEngine: ref.watch(localNlpEngineProvider),
    llmRepository: ref.watch(llmRepositoryProvider),
    networkStatus: ref.watch(networkStatusServiceProvider),
  );
});

/// Stateless correction intent classifier.
final voiceCorrectionHandlerProvider = Provider<VoiceCorrectionHandler>((ref) {
  return VoiceCorrectionHandler();
});

/// Persists confirmed voice transactions to SQLite.
final voiceTransactionServiceProvider = Provider<VoiceTransactionService>((ref) {
  return VoiceTransactionService(
    transactionRepo: ref.watch(transactionRepositoryProvider),
    categoryDao: ref.watch(categoryDaoProvider),
    accountDao: ref.watch(accountDaoProvider),
  );
});
