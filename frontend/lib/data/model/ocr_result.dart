class OcrResult {
  final String? merchant;
  final double? amount;
  final DateTime? date;
  final List<String>? items;
  final double? tax;
  final double? subtotal;
  final String? receiptNumber;
  final Map<String, dynamic>? rawData;

  OcrResult({
    this.merchant,
    this.amount,
    this.date,
    this.items,
    this.tax,
    this.subtotal,
    this.receiptNumber,
    this.rawData,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      merchant: json['merchant'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      items: List<String>.from(json['items'] as List? ?? []),
      tax: (json['tax'] as num?)?.toDouble(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      receiptNumber: json['receiptNumber'] as String?,
      rawData: json['rawData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (merchant != null) 'merchant': merchant,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date?.toIso8601String(),
      if (items != null && items!.isNotEmpty) 'items': items,
      if (tax != null) 'tax': tax,
      if (subtotal != null) 'subtotal': subtotal,
      if (receiptNumber != null) 'receiptNumber': receiptNumber,
      if (rawData != null) 'rawData': rawData,
    };
  }

  bool get hasValidAmount => amount != null && amount! > 0;
  bool get hasValidMerchant => merchant != null && merchant!.isNotEmpty;
}
