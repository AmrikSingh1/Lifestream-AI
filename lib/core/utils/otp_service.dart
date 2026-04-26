import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class OtpService {
  static Future<bool> sendOtp(String email, String otp) async {
    final apiKey = dotenv.env['BREVO_API_KEY'];
    final senderEmail = dotenv.env['OTP_FROM_EMAIL'] ?? 'amrik2052003@gmail.com';
    final senderName = dotenv.env['OTP_FROM_NAME'] ?? 'LifeStream AI';

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Brevo API Key is missing');
      return false;
    }

    final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
    
    final payload = {
      "sender": {
        "name": senderName,
        "email": senderEmail
      },
      "to": [
        {
          "email": email
        }
      ],
      "subject": "Verify your Identity - LifeStream AI",
      "htmlContent": """
        <html>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 20px;">
            <h2 style="color: #DC143C;">LifeStream AI</h2>
            <p>Thank you for registering as a hero donor.</p>
            <p>Your verification code is:</p>
            <h1 style="letter-spacing: 5px; color: #333;">$otp</h1>
            <p>Please enter this code in the app to complete your verification.</p>
          </body>
        </html>
      """
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Failed to send OTP. Status: \${response.statusCode}. Body: \${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }
}
