import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show AppColors;
import '../api_config.dart';
import 'edit_profile_screen.dart';

// Class representing achievement badge details
class AchievementBadge {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final double progress; // 0.0 to 1.0

  AchievementBadge({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.progress,
  });
}

// Class representing user profile activity history (Mock issue wrapper)
class ProfileActivity {
  final String category;
  final String location;
  final DateTime date;
  final String severity; // 'High', 'Medium', 'Low'
  final String status; // 'Resolved', 'Pending', 'In Progress'

  ProfileActivity({
    required this.category,
    required this.location,
    required this.date,
    required this.severity,
    required this.status,
  });

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'resolved':
        return AppColors.success;
      case 'in progress':
        return AppColors.navyBlue;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  IconData get severityIcon {
    switch (severity.toLowerCase()) {
      case 'high':
        return Icons.report_problem_rounded;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'low':
      default:
        return Icons.info_outline;
    }
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'No email registered';
  int _karmaPoints = 0;
  String _rank = 'Civic Cadet';
  int _nextRankPoints = 100;
  bool _isLoadingActivity = false;

  List<AchievementBadge> _badges = [];
  List<ProfileActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    // Pre-populate with Firebase Auth credentials
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userName = user.displayName ?? (user.isAnonymous ? 'Guest User' : 'Citizen');
        _userEmail = user.email ?? (user.isAnonymous ? 'Anonymous' : '');
      }
    } catch (e) {
      debugPrint('Firebase Auth not available on startup: $e');
    }
    
    // Initialize default badges
    _badges = [
      AchievementBadge(
        title: 'Pothole Patrol',
        description: 'Reported 5 potholes',
        icon: Icons.edit_road_rounded,
        color: Colors.amber,
        isUnlocked: false,
        progress: 0.0,
      ),
      AchievementBadge(
        title: 'Eco Warrior',
        description: 'Reported 10 trash issues',
        icon: Icons.delete_outline_rounded,
        color: Colors.green,
        isUnlocked: false,
        progress: 0.0,
      ),
      AchievementBadge(
        title: 'First Responder',
        description: 'First to report an issue',
        icon: Icons.flash_on_rounded,
        color: Colors.lightBlue,
        isUnlocked: false,
        progress: 0.0,
      ),
      AchievementBadge(
        title: 'Spotter Elite',
        description: 'File 15 reports overall',
        icon: Icons.verified_user_rounded,
        color: Colors.purple,
        isUnlocked: false,
        progress: 0.0,
      ),
    ];

    _loadUserProfile();
    _fetchUserActivity();
  }

  void _updateRankAndNextPoints() {
    if (_karmaPoints < 100) {
      _rank = 'Civic Cadet';
      _nextRankPoints = 100;
    } else if (_karmaPoints < 500) {
      _rank = 'Neighborhood Watcher';
      _nextRankPoints = 500;
    } else if (_karmaPoints < 1500) {
      _rank = 'Eco Warrior';
      _nextRankPoints = 1500;
    } else {
      _rank = 'Civic Champion';
      _nextRankPoints = _karmaPoints;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            if (data['name'] != null) {
              _userName = data['name'];
            }
            if (data['email'] != null) {
              _userEmail = data['email'];
            }
            if (data['karma'] != null) {
              _karmaPoints = (data['karma'] as num).toInt();
              _updateRankAndNextPoints();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _fetchUserActivity() async {
    setState(() {
      _isLoadingActivity = true;
    });
    try {
      final response = await http.get(Uri.parse(ApiConfig.issuesUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final uid = FirebaseAuth.instance.currentUser?.uid;
        
        final List<ProfileActivity> userIssues = [];
        int potholeCount = 0;
        int trashCount = 0;
        
        for (var item in jsonList) {
          final issueUserId = item['userId']?.toString();
          if (issueUserId == uid) {
            final category = item['classification']?.toString() ?? 'General';
            if (category.toLowerCase().contains('pothole')) {
              potholeCount++;
            } else if (category.toLowerCase().contains('trash') || category.toLowerCase().contains('sanitation') || category.toLowerCase().contains('eco')) {
              trashCount++;
            }
            
            DateTime parsedDate = DateTime.now();
            if (item['timestamp'] != null) {
              try {
                parsedDate = DateTime.parse(item['timestamp'].toString());
              } catch (_) {}
            }
            
            userIssues.add(
              ProfileActivity(
                category: category,
                location: 'GPS: ${item['latitude']}, ${item['longitude']}',
                date: parsedDate,
                severity: item['severity']?.toString() ?? 'Medium',
                status: item['status']?.toString() ?? 'Pending',
              ),
            );
          }
        }
        
        userIssues.sort((a, b) => b.date.compareTo(a.date));
        
        setState(() {
          _activities = userIssues;
          _badges = [
            AchievementBadge(
              title: 'Pothole Patrol',
              description: 'Reported 5 potholes',
              icon: Icons.edit_road_rounded,
              color: Colors.amber,
              isUnlocked: potholeCount >= 5,
              progress: (potholeCount / 5).clamp(0.0, 1.0),
            ),
            AchievementBadge(
              title: 'Eco Warrior',
              description: 'Reported 10 trash issues',
              icon: Icons.delete_outline_rounded,
              color: Colors.green,
              isUnlocked: trashCount >= 10,
              progress: (trashCount / 10).clamp(0.0, 1.0),
            ),
            AchievementBadge(
              title: 'First Responder',
              description: 'First to report an issue',
              icon: Icons.flash_on_rounded,
              color: Colors.lightBlue,
              isUnlocked: userIssues.isNotEmpty,
              progress: userIssues.isNotEmpty ? 1.0 : 0.0,
            ),
            AchievementBadge(
              title: 'Spotter Elite',
              description: 'File 15 reports overall',
              icon: Icons.verified_user_rounded,
              color: Colors.purple,
              isUnlocked: userIssues.length >= 15,
              progress: (userIssues.length / 15).clamp(0.0, 1.0),
            ),
          ];
        });
      }
    } catch (e) {
      debugPrint('Error fetching user activity: $e');
    } finally {
      setState(() {
        _isLoadingActivity = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = _karmaPoints / _nextRankPoints;

    return Scaffold(
      backgroundColor: AppColors.bgGray,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 440.0,
            backgroundColor: AppColors.navyBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Icon(Icons.shield_rounded, color: Colors.white70, size: 20),
                  ),
            leadingWidth: Navigator.canPop(context) ? null : 36,
            title: const Text(
              'Citizen Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        currentName: _userName,
                        currentEmail: _userEmail,
                      ),
                    ),
                  );
                  if (result != null && result is Map) {
                    setState(() {
                      _userName = result['name'] ?? _userName;
                      _userEmail = result['email'] ?? _userEmail;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(progressPercentage),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  _buildSectionTitle('Achievement Badges'),
                  const SizedBox(height: 12),
                  _buildBadgesGrid(),

                  const SizedBox(height: 32),

                  _buildSectionTitle('Activity Timeline'),
                  const SizedBox(height: 16),
                  _buildActivityTimeline(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(double progress) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyDark, AppColors.navyBlue],
        ),
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 100.0, 24.0, 16.0),
          child: Column(
            children: [
            // Avatar with outer ring
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.orange, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                backgroundImage: (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))
                    ? null
                    : NetworkImage(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(_userName)}',
                      ),
                child: (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 14),

            Text(
              _userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _userEmail,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 16),

            // Karma score card on navy background
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$_karmaPoints pts',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Civic Karma',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: Colors.white24,
                      ),
                      Column(
                        children: [
                          Text(
                            _rank,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Current Rank',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Progress to next rank',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBadgesGrid() {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 1.15;

    if (width > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 1.6;
    } else if (width > 800) {
      crossAxisCount = 3;
      childAspectRatio = 1.35;
    } else if (width > 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.25;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) {
        final badge = _badges[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: badge.isUnlocked
                      ? badge.color.withValues(alpha: 0.05)
                      : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              children: [
                // Faint background glow for unlocked achievements
                if (badge.isUnlocked)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.color.withValues(alpha: 0.1),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge Icon and Lock indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: badge.isUnlocked
                                  ? badge.color.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              badge.icon,
                              color: badge.isUnlocked
                                  ? badge.color
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                          if (!badge.isUnlocked)
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.grey.shade400,
                              size: 16,
                            ),
                        ],
                      ),

                      // Badge titles
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: badge.isUnlocked
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge.description,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      // Progress bar for locked badges
                      if (!badge.isUnlocked)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: badge.progress,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTimeline() {
    if (_isLoadingActivity && _activities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }
    if (_activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: [
              Icon(Icons.feed_outlined, color: Colors.grey.shade400, size: 48),
              const SizedBox(height: 8),
              Text(
                'No activity reported yet',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final activity = _activities[index];
        final isLast = index == _activities.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom timeline node indicators
            Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: activity.severityColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 80,
                    color: Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Card item details
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activity.category,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: activity.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            activity.status,
                            style: TextStyle(
                              color: activity.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          activity.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              activity.severityIcon,
                              color: activity.severityColor,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${activity.severity} Severity',
                              style: TextStyle(
                                color: activity.severityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(activity.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
