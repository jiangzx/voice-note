import 'dart:async';
import 'dart:developer' as dev;

import '../../../core/network/dto/transaction_correction_request.dart';
import '../../../core/network/dto/transaction_correction_response.dart';
import '../../../core/network/network_status_service.dart';
import '../../voice/data/llm_repository.dart';
import '../../voice/data/local_nlp_engine.dart';
import 'draft_batch.dart';
import 'parse_result.dart';
import 'voice_correction_handler.dart' hide CorrectionIntent;

/// Orchestrates NLP parsing and correction: local engine first, server LLM
/// fallback. When offline, LLM is skipped entirely.
class NlpOrchestrator {
  static const _llmCorrectionTimeout = Duration(seconds: 3);
  static const _llmParseTimeout = Duration(seconds: 120);
  static const _confidenceThreshold = 0.7;

  final LocalNlpEngine _localEngine;
  final LlmRepository _llmRepository;
  final NetworkStatusService? _networkStatus;
  final VoiceCorrectionHandler _correctionHandler;

  NlpOrchestrator({
    required LocalNlpEngine localEngine,
    required LlmRepository llmRepository,
    NetworkStatusService? networkStatus,
    VoiceCorrectionHandler? correctionHandler,
  })  : _localEngine = localEngine,
        _llmRepository = llmRepository,
        _networkStatus = networkStatus,
        _correctionHandler = correctionHandler ?? VoiceCorrectionHandler();

  /// Parse [text] into a list of structured transactions.
  /// Online: returns batch from LLM. Offline: single-element list from local.
  Future<List<ParseResult>> parse(
    String text, {
    List<String>? recentCategories,
    List<String>? customCategories,
    List<String>? accounts,
  }) async {
    LocalParseResult localResult;
    try {
      localResult = _localEngine.parse(text);
    } catch (e, st) {
      dev.log('Local NLP engine failed', error: e, stackTrace: st, name: 'NLP');
      localResult = const LocalParseResult(type: 'EXPENSE', isComplete: false);
    }

    if (_isOffline) {
      dev.log('Offline — skipping LLM fallback', name: 'NLP');
      return [_localFallback(localResult)];
    }

    try {
      final llmResults = await _llmRepository.parseTransaction(
        text: text,
        recentCategories: recentCategories,
        customCategories: customCategories,
        accounts: accounts,
      ).timeout(_llmParseTimeout);

      if (llmResults.isEmpty) return [_localFallback(localResult)];

      return llmResults.map((r) {
        return ParseResult(
          amount: r.amount ?? localResult.amount,
          date: r.date ?? localResult.date,
          category: r.category ?? localResult.category,
          description: r.description ?? localResult.description,
          type: r.type.isNotEmpty ? r.type : localResult.type,
          account: r.account,
          confidence: r.confidence,
          source: ParseSource.llm,
        );
      }).toList();
    } catch (e, st) {
      dev.log('LLM fallback failed', error: e, stackTrace: st, name: 'NLP');
      return [_localFallback(localResult)];
    }
  }

  /// Correct transactions via LLM dialogue with local fallback.
  /// Online: calls LLM with 3s timeout, degrades to local on timeout/error.
  /// Offline: uses local [VoiceCorrectionHandler].
  /// Returns null intent ("unclear") if confidence < 0.7.
  Future<TransactionCorrectionResponse> correct(
    String text,
    DraftBatch draftBatch, {
    List<String>? recentCategories,
    List<String>? customCategories,
  }) async {
    final batchSize = draftBatch.pendingItems.length;
    dev.log(
      'correct() start: batchSize=$batchSize, textLength=${text.length}',
      name: 'NLP',
    );

    if (_isOffline) {
      dev.log('Offline — using local correction (batchSize=$batchSize)', name: 'NLP');
      return _localCorrection(text, draftBatch);
    }

    try {
      final batchItems = draftBatch.pendingItems
          .map((d) => BatchItem(
                index: d.index,
                amount: d.result.amount,
                category: d.result.category,
                type: d.result.type,
                description: d.result.description,
                date: d.result.date,
              ))
          .toList();

      final response = await _llmRepository
          .correctTransaction(
            currentBatch: batchItems,
            correctionText: text,
            recentCategories: recentCategories,
            customCategories: customCategories,
          )
          .timeout(_llmCorrectionTimeout);

      dev.log(
        'LLM correction OK: intent=${response.intent}, confidence=${response.confidence}, model=${response.model}',
        name: 'NLP',
      );

      if (response.confidence < _confidenceThreshold) {
        dev.log(
          'Confidence ${response.confidence} < threshold $_confidenceThreshold, downgrading to unclear',
          name: 'NLP',
        );
        return TransactionCorrectionResponse(
          corrections: response.corrections,
          intent: CorrectionIntent.unclear,
          confidence: response.confidence,
          model: response.model,
        );
      }

      return response;
    } on TimeoutException {
      dev.log(
        'LLM correction timed out after ${_llmCorrectionTimeout.inSeconds}s (batchSize=$batchSize) — falling back to local',
        name: 'NLP',
        level: 900,
      );
      return _localCorrection(text, draftBatch);
    } catch (e, st) {
      dev.log('LLM correction failed (batchSize=$batchSize)', error: e, stackTrace: st, name: 'NLP');
      return _localCorrection(text, draftBatch);
    }
  }

  bool get _isOffline =>
      _networkStatus != null && !_networkStatus.isOnline;

  ParseResult _localFallback(LocalParseResult local) {
    return ParseResult(
      amount: local.amount,
      date: local.date,
      category: local.category,
      description: local.description,
      type: local.type,
      confidence: 0.3,
      source: ParseSource.local,
    );
  }

  TransactionCorrectionResponse _localCorrection(
    String text,
    DraftBatch draftBatch,
  ) {
    // Try local correction on each pending item, return first match
    for (final item in draftBatch.pendingItems) {
      final corrected = _correctionHandler.applyCorrection(text, item.result);
      if (corrected != null) {
        return TransactionCorrectionResponse(
          corrections: [
            CorrectionItem(
              index: item.index,
              updatedFields: _diffFields(item.result, corrected),
            ),
          ],
          intent: CorrectionIntent.correction,
          confidence: 0.75,
          model: 'local',
        );
      }
    }

    return const TransactionCorrectionResponse(
      corrections: [],
      intent: CorrectionIntent.unclear,
      confidence: 0.0,
      model: 'local',
    );
  }

  Map<String, dynamic> _diffFields(ParseResult old, ParseResult updated) {
    final diff = <String, dynamic>{};
    if (updated.amount != old.amount) diff['amount'] = updated.amount;
    if (updated.category != old.category) diff['category'] = updated.category;
    if (updated.type != old.type) diff['type'] = updated.type;
    if (updated.description != old.description) {
      diff['description'] = updated.description;
    }
    if (updated.date != old.date) diff['date'] = updated.date;
    if (updated.account != old.account) diff['account'] = updated.account;
    return diff;
  }
}
