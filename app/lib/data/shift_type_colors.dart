import 'package:flutter/material.dart';

const shiftTypeColors = <String, Color>{
  '早班': Color(0xFFFF9F43),
  '午班': Color(0xFF2ECC71),
  '晚班': Color(0xFF3498DB),
  '大夜': Color(0xFF5C4D9C),
};

Color? colorForShiftType(String? shiftType) => shiftType == null ? null : shiftTypeColors[shiftType];
