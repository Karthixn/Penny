import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/storage/secure_storage.dart';

const _currencyStorageKey = 'app_currency_code';

class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final String locale;
  final String flag;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
    required this.flag,
  });

  String formatPaise(int paise, {int? decimalDigits}) {
    final amount = paise / 100.0;
    return formatAmount(amount, decimalDigits: decimalDigits);
  }

  String formatAmount(double amount, {int? decimalDigits}) {
    final digits = decimalDigits ?? (amount % 1 == 0 ? 0 : 2);
    try {
      final formatter = NumberFormat.currency(
        locale: locale,
        symbol: symbol,
        decimalDigits: digits,
      );
      return formatter.format(amount);
    } catch (_) {
      return '$symbol${amount.toStringAsFixed(digits)}';
    }
  }

  static const inr = AppCurrency(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    locale: 'en_IN',
    flag: '🇮🇳',
  );

  static const usd = AppCurrency(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    locale: 'en_US',
    flag: '🇺🇸',
  );

  static const eur = AppCurrency(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    locale: 'en_IE',
    flag: '🇪🇺',
  );

  static const gbp = AppCurrency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    locale: 'en_GB',
    flag: '🇬🇧',
  );

  static const aed = AppCurrency(
    code: 'AED',
    symbol: 'د.إ',
    name: 'UAE Dirham',
    locale: 'en_AE',
    flag: '🇦🇪',
  );

  static const cad = AppCurrency(
    code: 'CAD',
    symbol: 'CA\$',
    name: 'Canadian Dollar',
    locale: 'en_CA',
    flag: '🇨🇦',
  );

  static const aud = AppCurrency(
    code: 'AUD',
    symbol: 'A\$',
    name: 'Australian Dollar',
    locale: 'en_AU',
    flag: '🇦🇺',
  );

  static const sgd = AppCurrency(
    code: 'SGD',
    symbol: 'S\$',
    name: 'Singapore Dollar',
    locale: 'en_SG',
    flag: '🇸🇬',
  );

  static const jpy = AppCurrency(
    code: 'JPY',
    symbol: '¥',
    name: 'Japanese Yen',
    locale: 'ja_JP',
    flag: '🇯🇵',
  );

  static const List<AppCurrency> all = [
    inr,
    usd,
    eur,
    gbp,
    aed,
    cad,
    aud,
    sgd,
    jpy,
  ];

  static AppCurrency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => inr,
    );
  }
}

class CurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    _loadCurrency();
    return AppCurrency.inr;
  }

  Future<void> _loadCurrency() async {
    final savedCode = await SecureStorage.get(_currencyStorageKey);
    if (savedCode != null && savedCode.isNotEmpty) {
      state = AppCurrency.fromCode(savedCode);
    }
  }

  Future<void> setCurrency(AppCurrency currency) async {
    state = currency;
    await SecureStorage.set(_currencyStorageKey, currency.code);
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, AppCurrency>(
  CurrencyNotifier.new,
);
