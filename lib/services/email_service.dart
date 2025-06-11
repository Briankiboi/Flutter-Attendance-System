import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class EmailService {
  // Brevo API key - in a real app, store this securely using environment variables
  static const String apiKey = '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';
  
  // Brevo API endpoint for sending transactional emails
  static const String apiUrl = 'https://api.brevo.com/v3/smtp/email';
  
  // Method to generate a random 4-digit code
  static String generateOTP() {
    Random random = Random();
    int code = random.nextInt(9000) + 1000; // Generate a number between 1000 and 9999
    return code.toString();
  }
  
  // Method to store OTP in shared preferences
  static Future<void> storeOTP(String email, String otp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('otp_$email', otp);
    
    // Set an expiration time (5 minutes from now)
    final expirationTime = DateTime.now().add(Duration(minutes: 5)).millisecondsSinceEpoch;
    await prefs.setInt('otp_expiry_$email', expirationTime);
    
    // Always print the OTP to the console for debugging during development
    print('OTP for $email: $otp');
  }
  
  // Method to verify OTP
  static Future<bool> verifyOTP(String email, String enteredOtp) async {
    final prefs = await SharedPreferences.getInstance();
    final storedOtp = prefs.getString('otp_$email');
    final expirationTime = prefs.getInt('otp_expiry_$email');
    
    if (storedOtp == null || expirationTime == null) {
      return false; // OTP not found
    }
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime > expirationTime) {
      // OTP expired, clean up
      await prefs.remove('otp_$email');
      await prefs.remove('otp_expiry_$email');
      return false;
    }
    
    return storedOtp == enteredOtp;
  }
  
  // Check internet connectivity
  static Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  
  // Method to send verification email using Brevo
  static Future<bool> sendVerificationEmail(String email, String name) async {
    try {
      // Check connectivity first
      bool hasConnectivity = await _checkConnectivity();
      if (!hasConnectivity) {
        print('No internet connection detected');
        return false;
      }
      
      // Generate OTP
      final otp = generateOTP();
      
      // Store OTP for verification later
      await storeOTP(email, otp);
      
      // Create email payload - using a proper verified sender email from your Brevo account
      final Map<String, dynamic> payload = {
        'sender': {
          'name': 'Tharaka University',
          'email': 'briankiboi83@gmail.com'  // Using the verified email from your account
        },
        'to': [
          {
            'email': email,
            'name': name
          }
        ],
        'subject': 'Email Verification - QR Code Attendance App',
        'htmlContent': '''
          <html>
            <body style="font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f9f9f9;">
              <table role="presentation" width="100%" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1);">
                <tr>
                  <td style="padding: 30px;">
                    <div style="text-align: center; margin-bottom: 20px;">
                      <h1 style="color: #3498db; margin: 0;">QR Code Attendance App</h1>
                    </div>
                    <p style="font-size: 16px; color: #333;">Hello $name,</p>
                    <p style="font-size: 16px; color: #333;">Thank you for registering/attending for our QR Code Attendance app  for Tharaka university!</p>
                    <p style="font-size: 16px; color: #333;">To complete your registration and activate your account, please verify your email address by entering the following code in the app:</p>
                    <div style="background-color: #f7f7f7; padding: 15px; border-radius: 5px; text-align: center; margin: 20px 0;">
                      <h2 style="margin: 0; color: #3498db; letter-spacing: 5px; font-size: 32px;">$otp</h2>
                    </div>
                    <p style="font-size: 16px; color: #333;">This code will expire in 5 minutes.</p>
                    <p style="font-size: 16px; color: #333;">If you didn't create an account, please ignore this email.</p>
                    <p style="font-size: 16px; color: #333; margin-top: 30px;">Best regards,<br>The QR Code Attendance ICT Team</p>
                    <div style="border-top: 1px solid #e0e0e0; margin-top: 30px; padding-top: 15px; text-align: center; color: #777; font-size: 12px;">
                      <p>&copy; ${DateTime.now().year} Tharaka University. All rights reserved.</p>
                      <p>This is an automated message. Please do not reply to this email.</p>
                    </div>
                  </td>
                </tr>
              </table>
            </body>
          </html>
        '''
      };
      
      // Log the request for debugging
      print('===== BREVO API REQUEST =====');
      print('Sending email to: $email with OTP: $otp');
      print('From: briankiboi83@gmail.com (Tharaka University)');
      print('API Endpoint: $apiUrl');
      
      // Send request to Brevo API with a timeout
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 30));
      
      // Check if request was successful
      print('===== BREVO API RESPONSE =====');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Verification email sent successfully: ${response.body}');
        return true;
      } else {
        print('Failed to send verification email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('===== BREVO API ERROR =====');
      print('Error sending verification email: $e');
      return false;
    }
  }
  
  // Method to resend verification email
  static Future<bool> resendVerificationEmail(String email, String name) async {
    return await sendVerificationEmail(email, name);
  }
} 