class TelegramRideLead {
  const TelegramRideLead({
    required this.id,
    required this.kind,
    required this.fromCity,
    required this.toCity,
    required this.cargo,
    required this.rawText,
    required this.sourceSentAt,
    required this.publishedAt,
    required this.confidence,
    required this.contactMethods,
    required this.sourceMessageIds,
    this.departureDate,
    this.departureTime,
    this.datePrecision = 'unknown',
    this.seats,
    this.price,
    this.currency,
    this.phone,
    this.sourceChatTitle,
    this.sourceChatUsername,
    this.sourceMessageUrl,
    this.authorId,
    this.authorName,
    this.authorUsername,
  });

  final String id;
  final String kind;
  final String fromCity;
  final String toCity;
  final DateTime? departureDate;
  final String? departureTime;
  final String datePrecision;
  final int? seats;
  final bool cargo;
  final int? price;
  final String? currency;
  final String? phone;
  final List<String> contactMethods;
  final String rawText;
  final DateTime sourceSentAt;
  final DateTime publishedAt;
  final double confidence;
  final String? sourceChatTitle;
  final String? sourceChatUsername;
  final String? sourceMessageUrl;
  final List<int> sourceMessageIds;
  final int? authorId;
  final String? authorName;
  final String? authorUsername;

  bool get isDriverOffer => kind == 'offer';

  String get displayAuthor {
    final name = (authorName ?? '').trim();
    if (name.isNotEmpty) return name;
    final username = (authorUsername ?? '').trim();
    if (username.isNotEmpty) return '@${username.replaceFirst('@', '')}';
    return 'Автор объявления';
  }

  Uri? get telegramUri {
    final username = (authorUsername ?? '').trim().replaceFirst('@', '');
    if (username.isNotEmpty) return Uri.parse('https://t.me/$username');
    if (authorId != null) return Uri.parse('tg://user?id=$authorId');
    return null;
  }

  Uri? get originalUri {
    final value = (sourceMessageUrl ?? '').trim();
    return value.isEmpty ? null : Uri.tryParse(value);
  }

  Uri? get callUri {
    final normalized = _normalizedPhone;
    return normalized == null ? null : Uri.parse('tel:$normalized');
  }

  Uri? get whatsappUri {
    final normalized = _normalizedPhone?.replaceAll('+', '');
    return normalized == null ? null : Uri.parse('https://wa.me/$normalized');
  }

  String? get _normalizedPhone {
    final raw = (phone ?? '').trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return null;
    return raw.startsWith('+') ? '+$digits' : digits;
  }

  bool matchesRoute(String from, String to) =>
      _normalize(fromCity) == _normalize(from) &&
      _normalize(toCity) == _normalize(to);

  DateTime get groupingDate => departureDate ?? sourceSentAt;

  static String _normalize(String value) => value.trim().toLowerCase();

  factory TelegramRideLead.fromJson(Map<String, dynamic> json) {
    int? parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}');
    }

    DateTime? parseDate(Object? value) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    final contactRaw = json['contact_methods'];
    final idsRaw = json['source_message_ids'];
    final departureTimeRaw = '${json['departure_time'] ?? ''}'.trim();
    return TelegramRideLead(
      id: '${json['id']}',
      kind: '${json['kind'] ?? 'offer'}',
      fromCity: '${json['from_city'] ?? ''}',
      toCity: '${json['to_city'] ?? ''}',
      departureDate: parseDate(json['departure_date']),
      departureTime: departureTimeRaw.isEmpty
          ? null
          : departureTimeRaw.substring(0, departureTimeRaw.length.clamp(0, 5)),
      datePrecision: '${json['date_precision'] ?? 'unknown'}',
      seats: parseInt(json['seats']),
      cargo: json['cargo'] as bool? ?? false,
      price: parseInt(json['price']),
      currency: json['currency'] as String?,
      phone: json['phone'] as String?,
      contactMethods: contactRaw is List
          ? contactRaw.map((item) => '$item').toList(growable: false)
          : const [],
      rawText: '${json['raw_text'] ?? ''}',
      sourceSentAt: _parseTripTime('${json['source_sent_at']}') ?? _tripNow(),
      publishedAt: _parseTripTime('${json['created_at']}') ?? _tripNow(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      sourceChatTitle: json['source_chat_title'] as String?,
      sourceChatUsername: json['source_chat_username'] as String?,
      sourceMessageUrl: json['source_message_url'] as String?,
      sourceMessageIds: idsRaw is List
          ? idsRaw.map(parseInt).whereType<int>().toList(growable: false)
          : const [],
      authorId: parseInt(json['author_id']),
      authorName: json['author_name'] as String?,
      authorUsername: json['author_username'] as String?,
    );
  }

  // Telegram routes in this feed are in Tajikistan/Uzbekistan (UTC+5).
  // Keep their wall-clock time stable even when the phone uses another zone.
  static DateTime? _parseTripTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return _asTripWallClock(parsed);
  }

  static DateTime _tripNow() => _asTripWallClock(DateTime.now());

  static DateTime _asTripWallClock(DateTime instant) {
    final shifted = instant.toUtc().add(const Duration(hours: 5));
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }
}
