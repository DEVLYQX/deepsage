import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastUtils {
  static void showSuccess(String message) {
    print('🟢 SUCCESS TOAST: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF10B981), // Green
      textColor: Colors.white,
      fontSize: 16.0,
      timeInSecForIosWeb: 3,
    );
  }

  static void showError(String message) {
    print('🔴 ERROR TOAST: $message');
    // Add small delay to ensure context is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFEF4444), // Red
        textColor: Colors.white,
        fontSize: 16.0,
        timeInSecForIosWeb: 4,
      );
    });
  }

  static void showWarning(String message) {
    print('🟡 WARNING TOAST: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFFF59E0B), // Orange
      textColor: Colors.white,
      fontSize: 16.0,
      timeInSecForIosWeb: 3,
    );
  }

  static void showInfo(String message) {
    print('🔵 INFO TOAST: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color(0xFF6366F1), // Primary color (Indigo)
      textColor: Colors.white,
      fontSize: 16.0,
      timeInSecForIosWeb: 3,
    );
  }

  static void show(String message, {Color? backgroundColor}) {
    print('⚪ TOAST: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor ?? const Color(0xFF374151), // Default gray
      textColor: Colors.white,
      fontSize: 16.0,
      timeInSecForIosWeb: 3,
    );
  }
}
