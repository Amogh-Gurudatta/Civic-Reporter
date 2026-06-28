import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../api_config.dart';
import '../main.dart' show AppColors;
import '../widgets/scale_interactive_widget.dart';
import '../widgets/fade_in_stagger_text.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _base64Image;
  Position? _currentPosition;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // Pre-emptively request location permission
    _checkLocationPermission();
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. We cannot tag the report.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _handleImageSource(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Optimize image size for upload
      );

      if (photo == null) return;

      setState(() {
        _base64Image = null;
        _isLocating = true;
        _statusMessage = 'Reading image and acquiring GPS coordinates...';
      });

      // 1. Convert image to base64
      final bytes = await photo.readAsBytes();
      final base64String = base64Encode(bytes);

      // 2. Fetch coordinates simultaneously
      Position? position;
      final hasPermission = await _checkLocationPermission();
      if (hasPermission) {
        // Use default LocationSettings instead of deprecated desiredAccuracy/timeLimit
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
        position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
        );
      }

      setState(() {
        _base64Image = base64String;
        _currentPosition = position;
        _isLocating = false;
        _statusMessage = position != null
            ? 'GPS coordinates tagged successfully!'
            : 'Image loaded, but GPS acquisition timed out/failed.';
      });
    } catch (e) {
      setState(() {
        _isLocating = false;
        _statusMessage = 'Error loading image: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() => _handleImageSource(ImageSource.camera);
  Future<void> _pickFromGallery() => _handleImageSource(ImageSource.gallery);

  Future<void> _submitReport() async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a photo first.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Try to get GPS again if it failed previously
    if (_currentPosition == null) {
      setState(() {
        _isSubmitting = true;
        _statusMessage = 'Retrying GPS acquisition...';
      });
      try {
        final hasPermission = await _checkLocationPermission();
        if (hasPermission) {
          const locationSettings = LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          );
          _currentPosition = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          );
        }
      } catch (_) {}
    }

    // Default coordinates if location acquisition failed completely
    final lat = _currentPosition?.latitude ?? 0.0;
    final lng = _currentPosition?.longitude ?? 0.0;

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Uploading captured image to cloud storage...';
    });

    try {
      // 1. Decode captured image bytes
      final bytes = base64Decode(_base64Image!);
      
      // 2. Generate unique name and path
      final String uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
      final storageRef = FirebaseStorage.instance.ref().child('reports/$uniqueId.jpg');
      
      // 3. Upload to Firebase Storage
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Update status and submit metadata to backend
      setState(() {
        _statusMessage = 'Submitting report to authorities...';
      });

      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final response = await http.post(
        Uri.parse(ApiConfig.reportIssueUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageUrl': downloadUrl,
          'latitude': lat,
          'longitude': lng,
          'userId': userId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _showSuccessDialog(responseData);
        _resetForm();
      } else {
        throw Exception(
          'Failed to upload. Server responded with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Submission Failed'),
              ],
            ),
            content: Text(
              'Could not report issue to ${ApiConfig.reportIssueUrl}.\n\nDetails: $e',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _base64Image = null;
      _currentPosition = null;
      _statusMessage = '';
    });
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final classification = data['classification'] ?? 'Unknown';
    final severity = (data['severity'] ?? 'Medium').toString();
    final description = data['description'] ?? 'No description provided.';
    final id = data['id'] ?? 'N/A';

    Color sevColor = Colors.orange;
    if (severity.toLowerCase().contains('high')) sevColor = Colors.red;
    if (severity.toLowerCase().contains('low')) sevColor = Colors.green;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 36),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Issue Filed!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Report ID: $id',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Category:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      classification,
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Severity:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        color: sevColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'AI Description:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Navy header gradient ──────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navyDark, AppColors.navyBlue],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Official header ───────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File a Civic Report',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                             Text(
                               "Citizen Issue Reporting Portal",
                               style: TextStyle(
                                 fontSize: 12,
                                 color: Colors.white70,
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),


                  // ── Photo capture card ────────────────────────────
                  Container(
                    height: size.height * 0.34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _base64Image != null
                            ? AppColors.navyBlue.withValues(alpha: 0.4)
                            : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navyBlue.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _base64Image != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Evidence photo attached',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                          ),
                                        ),
                                      ),
                                      ScaleInteractiveWidget(
                                        onTap: _isSubmitting || _isLocating ? null : _takePhoto,
                                        child: IgnorePointer(
                                          child: ElevatedButton.icon(
                                            onPressed: _isSubmitting || _isLocating ? null : () {},
                                            icon: const Icon(Icons.camera_alt_rounded, size: 13),
                                            label: const Text('Retake', style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              elevation: 0,
                                              backgroundColor: Colors.black.withValues(alpha: 0.4),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.navyBlue.withValues(alpha: 0.07),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 40,
                                    color: AppColors.navyBlue,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Attach Evidence Photo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Text(
                                    'Photograph the issue clearly for AI analysis.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMid,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ScaleInteractiveWidget(
                                      onTap: _isSubmitting || _isLocating ? null : _takePhoto,
                                      child: IgnorePointer(
                                        child: ElevatedButton.icon(
                                          onPressed: _isSubmitting || _isLocating ? null : () {},
                                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                          label: const Text('Open Camera'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.orange,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ScaleInteractiveWidget(
                                      onTap: _isSubmitting || _isLocating ? null : _pickFromGallery,
                                      child: IgnorePointer(
                                        child: OutlinedButton.icon(
                                          onPressed: _isSubmitting || _isLocating ? null : () {},
                                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                                          label: const Text('Upload Photo'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.navyBlue,
                                            side: const BorderSide(color: AppColors.navyBlue, width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── GPS status card ───────────────────────────────
                  if (_statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentPosition != null
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.navyBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _currentPosition != null
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.navyBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentPosition != null
                                ? Icons.gps_fixed_rounded
                                : Icons.sync_rounded,
                            color: _currentPosition != null
                                ? AppColors.success
                                : AppColors.navyBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _currentPosition != null
                                        ? AppColors.success
                                        : AppColors.navyBlue,
                                  ),
                                ),
                                if (_currentPosition != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMid,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isLocating)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBlue),
                              ),
                            )
                        ],
                      ),
                    ),


                  const SizedBox(height: 32),

                  // ── Submit button ─────────────────────────────────
                  ScaleInteractiveWidget(
                    onTap: _base64Image == null || _isSubmitting || _isLocating
                        ? null
                        : _submitReport,
                    child: IgnorePointer(
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: _base64Image != null && !_isSubmitting && !_isLocating
                              ? const LinearGradient(
                                  colors: [AppColors.orange, AppColors.orangeLight],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: _base64Image == null || _isSubmitting || _isLocating
                              ? const Color(0xFFE2E8F0)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _base64Image != null && !_isSubmitting
                              ? [
                                  BoxShadow(
                                    color: AppColors.orange.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: _base64Image == null || _isSubmitting || _isLocating
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Submit Report to Authorities',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: _base64Image == null || _isSubmitting || _isLocating
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_base64Image != null && !_isSubmitting && !_isLocating)
                    ScaleInteractiveWidget(
                      onTap: _resetForm,
                      child: IgnorePointer(
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Clear and Start Over',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Submitting overlay ────────────────────────────────────
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Single official progress spinner
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.navyBlue),
                              backgroundColor: const Color(0xFFDBE8FF),
                            ),
                            const Icon(Icons.shield_rounded, color: AppColors.navyBlue, size: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeInStaggerText(
                        texts: const [
                          'Acquiring GPS coordinates...',
                          'Encrypting evidence data...',
                          'Transmitting to server...',
                          'Analyzing via Gemini AI...',
                          'Filing with municipality...',
                        ],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
