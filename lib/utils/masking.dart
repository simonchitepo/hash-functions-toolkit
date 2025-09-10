import 'package:flutter/material.dart';

String maskData(String data, {String maskChar = "*", int unmaskedLength = 4}) {
  if (unmaskedLength < 0) unmaskedLength = 0;
  if (data.length <= unmaskedLength) return data;
  final maskedPart = List.filled(data.length - unmaskedLength, maskChar).join();
  final unmaskedPart = data.substring(data.length - unmaskedLength);
  return maskedPart + unmaskedPart;
}

bool isValidPin(String pin) => pin.length == 6 && int.tryParse(pin) != null;

bool isNarrowLayout(BuildContext context) => MediaQuery.of(context).size.width < 640;
