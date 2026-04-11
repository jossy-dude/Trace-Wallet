import '../models/vault_transaction.dart';

// Semantic Bank Rules (Ported from Legacy Python Parser V4)
class SemanticBankRules {
  static const Map<String, dynamic> cbe = {
    'display': 'CBE',
    'amt_logic': [
      r'debited with etb\s*([\d,.]+)',
      r'transfer(?:r)?ed etb\s*([\d,.]+)',
      r'credited with etb\s*([\d,.]+)'
    ],
    'bal_logic': [r'current balance is etb\s*([\d,.]+)'],
    'fee_logic': [r's\.charge of etb\s*([\d,.]+)', r'service charge of etb\s*([\d,.]+)'],
    'vat_logic': [r'vat.*?of etb\s*([\d,.]+)'],
    'name_logic': [r'(?:to|from)\s+([a-zA-Z\s.\-]+?)(?:\s+on|,|\s+at)'],
  };

  static const Map<String, dynamic> telebirr = {
    'display': 'Telebirr',
    'amt_logic': [
      r'paid etb\s*([\d,.]+)',
      r'withdrawn? etb\s*([\d,.]+)',
      r'transferred etb\s*([\d,.]+)',
      r'recharged etb\s*([\d,.]+)',
      r'received etb\s*([\d,.]+)'
    ],
    'bal_logic': [r'balance is\s*(?:etb)?\s*([\d,.]+)'],
    'fee_logic': [
      r'service fee.*?is etb\s*([\d,.]+)', 
      r'charge\s*([\d,.]+)br',
      r'transaction fee is etb\s*([\d,.]+)' // Added from Python script
    ],
    'vat_logic': [r'vat.*?is etb\s*([\d,.]+)', r'tax\s*([\d,.]+)br'],
    'name_logic': [
      r'for package\s+(.*?)\s+purchase',
      r'purchased from\s+\d+\s*-\s*([a-zA-Z\s.\-]+)',
      r'from\s+(.*?)\s+(?:on|to)',
      r'to\s+(.*?)\s+account'
    ],
  };

  static final Map<String, DateTime> startDates = {
    'CBE': DateTime(2024, 12, 10),
    'TELEBIRR': DateTime(2024, 4, 11),
    'DEFAULT': DateTime(2024, 1, 1),
  };
}

class RegexParserService {
  static final RegexParserService _instance = RegexParserService._internal();
  factory RegexParserService() => _instance;
  RegexParserService._internal();

  /// Checks if a transaction should be ignored based on its category and date.
  bool shouldIgnore(String? category, DateTime date) {
    if (category == null) return false;
    final startDate = SemanticBankRules.startDates[category.toUpperCase()] ?? SemanticBankRules.startDates['DEFAULT']!;
    return date.isBefore(startDate);
  }

  /// Helper to safely parse strings to doubles
  double? _parseDecimal(String? text) {
    if (text == null) return null;
    var cleaned = text.replaceAll(',', '').trim();
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return double.tryParse(cleaned);
  }

  /// Helper to run a list of regex patterns and return the first match
  String? _parseValue(String body, List<String> patterns) {
    for (String pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(body);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Determines which bank ruleset to use based on the raw text and sender
  Map<String, dynamic>? _identifyProfile(String body, String? sender) {
    final lowerBody = body.toLowerCase();
    final lowerSender = sender?.toLowerCase() ?? '';
    
    if (lowerBody.contains('cbe') || lowerBody.contains('commercial bank') || lowerSender.contains('cbe')) {
      return SemanticBankRules.cbe;
    } else if (lowerBody.contains('telebirr') || lowerBody.contains('127') || lowerBody.contains('ethiotel') || lowerSender.contains('127') || lowerSender.contains('telebirr')) {
      return SemanticBankRules.telebirr;
    }
    return null;
  }

  /// Processes the [VaultTransaction] using Semantic Bank Rules.
  VaultTransaction processRawTransaction(VaultTransaction tx) {
    final String body = tx.rawText;
    final profile = _identifyProfile(body, tx.senderAlias);

    if (profile == null) {
      // Fallback to generic parsing if not CBE/Telebirr
      tx = _fallbackParse(tx);
      return tx;
    }

    // 1. Bank Identification
    String bankName = profile['display'];
    tx.category = bankName; // e.g. "CBE" or "Telebirr"

    // 2. Extraction (Semantic)
    String? amtRaw = _parseValue(body, profile['amt_logic']);
    String? balRaw = _parseValue(body, profile['bal_logic']);
    String? feeRaw = _parseValue(body, profile['fee_logic']);
    String? vatRaw = _parseValue(body, profile['vat_logic']);

    tx.amount = _parseDecimal(amtRaw);
    tx.balance = _parseDecimal(balRaw);
    
    // Combine Fee and VAT
    double parsedFee = _parseDecimal(feeRaw) ?? 0.0;
    double parsedVat = _parseDecimal(vatRaw) ?? 0.0;
    if (parsedFee + parsedVat > 0) {
      tx.fee = parsedFee + parsedVat;
    }

    // 3. Name Extraction (Non-greedy)
    String? nameRaw = _parseValue(body, profile['name_logic']);
    if (nameRaw != null) {
      tx.senderAlias = nameRaw.trim();
    }

    return tx;
  }

  /// Original Fallback Logic for generic messages
  VaultTransaction _fallbackParse(VaultTransaction tx) {
    final body = tx.rawText;
    final amountRegex = RegExp(r'(?:USD|KSh|Rs|\$|KES|GBP|£)\s?(\d+(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false);
    final match = amountRegex.firstMatch(body);
    if (match != null) {
      tx.amount = _parseDecimal(match.group(1));
    }
    if (body.toLowerCase().contains('sent') || body.toLowerCase().contains('paid')) {
      tx.category = 'EXPENSE';
    } else if (body.toLowerCase().contains('received') || body.toLowerCase().contains('credited')) {
      tx.category = 'INCOME';
    }
    return tx;
  }

  /// Attempts to extract a probable entity name from the raw text (Fallback).
  String? extractProbableEntity(String body, [String? sender]) {
    final profile = _identifyProfile(body, sender);
    if (profile != null) {
      String? nameRaw = _parseValue(body, profile['name_logic']);
      if (nameRaw != null) return nameRaw.trim();
    }

    // Generic fallback
    final RegExp entityRegex = RegExp(r'(?:to|from|at|received)\s+([A-Z0-9\s-]+?)(?:\s+on|\s+at|\s+via|\.|$)', caseSensitive: false);
    final match = entityRegex.firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }
}
