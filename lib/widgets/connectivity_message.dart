import 'package:flutter/material.dart';

class ConnectivityMessage extends StatelessWidget {
  final String type;
  final bool isConnected;

  const ConnectivityMessage({
    super.key,
    required this.type,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return Container(
        padding: EdgeInsets.all(8),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected! The page will refresh automatically.',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      );
    }

    String message = '';
    IconData icon = Icons.wifi_off;
    Color color = Colors.red;

    switch (type) {
      case 'no_connection':
        message = 'No internet connection detected. Try:\n• Checking your Wi-Fi settings\n• Enabling mobile data\n• Switching to a different network';
        icon = Icons.signal_wifi_off;
        break;
      case 'slow':
        message = 'Your connection seems slow. For better performance:\n• Move closer to your Wi-Fi router\n• Try switching to a different network\n• Check if other apps are using bandwidth';
        icon = Icons.signal_wifi_0_bar;
        color = Colors.orange;
        break;
      case 'no_data':
        message = 'Connected to network, but no internet access. Try:\n• Checking your data plan\n• Resetting your network connection\n• Contacting your service provider';
        icon = Icons.wifi_off;
        break;
      default:
        message = 'Unable to connect to the internet. Please check your network settings and try again.';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.split('\n')[0],
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (message.contains('\n')) ...[
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(left: 32),
              child: Text(
                message.split('\n').skip(1).join('\n'),
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 