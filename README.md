# 🎓 QR Code Attendance System

A modern, secure, and efficient Flutter-based attendance tracking system using QR codes, location verification, and real-time synchronization.

## 📱 Features

- **QR Code Scanning & Generation**
  - Dynamic QR code generation for each session
  - Fast and accurate QR code scanning
  - Backup key system for fallback scenarios

- **Location-Based Verification**
  - Geofencing for attendance validation
  - Mock location detection
  - Configurable radius settings
  - Location accuracy monitoring

- **Real-time Tracking**
  - Live attendance updates
  - Session management
  - Automatic session expiry
  - Offline support with sync

- **Security Features**
  - Device fingerprinting
  - Time synchronization
  - Network verification
  - Multiple device detection
  - Mock location prevention

- **Comprehensive Reporting**
  - Detailed attendance logs
  - PDF report generation
  - Statistical analysis
  - Data export capabilities

## 🛠️ Tech Stack

- **Frontend**: Flutter (SDK ≥ 3.0.0)
- **Backend**: Supabase
- **Database**: PostgreSQL with PostGIS
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Location Services**: Geolocator
- **QR Scanning**: Mobile Scanner
- **PDF Generation**: pdf & printing packages

## 📋 Prerequisites

- Flutter SDK (≥ 3.0.0)
- Dart SDK (≥ 3.0.0)
- Supabase Account
- Android Studio / VS Code
- Git

## 🚀 Getting Started

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Briankiboi/Flutter-Attendance-System.git
   cd Flutter-Attendance-System
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**
   Create a `.env` file in the root directory:
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  qr_flutter: ^4.1.0
  provider: ^6.1.1
  shared_preferences: ^2.0.15
  mobile_scanner: ^6.0.6
  flutter_datetime_picker: ^1.5.1
  path_provider: ^2.0.11
  mailer: ^6.0.1
  pdf: ^3.11.3
  printing: ^5.14.2
  intl: ^0.20.2
  image_picker: ^1.1.2
  fl_chart: ^0.70.2
  http: ^1.1.0
  connectivity_plus: ^5.0.2
  crypto: ^3.0.3
  google_fonts: ^6.1.0
  package_info_plus: ^8.3.0
  cached_network_image: ^3.3.1
  lottie: ^2.6.0
  curved_navigation_bar: ^1.0.3
  google_nav_bar: ^5.0.6
  line_icons: ^2.0.3
  iconify_flutter: ^0.0.5
  flutter_native_splash: ^2.2.19
  photo_view: ^0.14.0
  geolocator: ^14.0.0
  geocoding: ^3.0.0
  internet_connection_checker: ^1.0.0
  data_table_2: ^2.5.10
  supabase_flutter: ^2.3.4
  postgrest: ^2.1.0
  flutter_dotenv: ^5.1.0
  device_info_plus: ^9.1.2
  ntp: ^2.0.0
  uuid: ^4.5.1
  excel: ^2.1.0
  path: ^1.8.3
  url_launcher: ^6.2.2
  table_calendar: ^3.2.0
  google_maps_flutter: ^2.12.2
  workmanager: ^0.6.0
  go_router: ^13.1.0
```

## 🗄️ Database Schema

The system uses Supabase with the following main tables:

- **attendance_sessions**: Stores class session details
- **attendance**: Records student attendance
- **student_location_history**: Tracks location data
- **users**: Manages user accounts
- **lecturers**: Stores lecturer information
- **students**: Contains student records

## 🔒 Security Features

1. **Real-time Location Verification**
   - Geofencing with configurable radius (1-100 meters)
   - Advanced mock location detection using multiple data points
   - Location accuracy validation with minimum threshold
   - Real-time location updates and monitoring
   - Haversine distance calculation for accuracy

2. **Device Security**
   - Device fingerprinting with hardware identifiers
   - Multiple device detection and prevention
   - Platform and OS verification
   - Device tampering detection
   - Secure device registration

3. **Time Synchronization**
   - NTP time synchronization for accuracy
   - Time drift detection and correction
   - Session time window validation
   - Automatic session expiration
   - Time-based OTP for backup

4. **Network Security**
   - Real-time connection verification
   - Network type monitoring and validation
   - API request validation with rate limiting
   - SSL/TLS encryption for all communications
   - Secure WebSocket connections for real-time updates

5. **Data Security**
   - End-to-end encryption for sensitive data
   - Secure key storage and management
   - Regular security audits and logging
   - Data backup and recovery systems
   - GDPR and CCPA compliance ready

## 📊 Monitoring & Analytics

- Real-time attendance tracking
- Session statistics and analytics
- Location accuracy monitoring
- Device usage analytics
- Network performance metrics
- Security incident logging
- Audit trail maintenance

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

MIT License

Copyright (c) 2024 Brian Kiboi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 👥 Authors

- Brian Kiboi - Initial work - [Briankiboi](https://github.com/Briankiboi)

## 🙏 Acknowledgments

- All contributors who have helped this project grow-[https://github.com/kelvin482/] logo designer 

