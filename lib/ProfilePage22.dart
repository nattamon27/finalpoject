import 'package:appfinal/AgriVehicleManagementPage21.dart';
import 'package:appfinal/BookingPage20.dart';
import 'package:appfinal/ContactAdminPage24.dart';
import 'package:appfinal/DashboardPage18.dart';
import 'package:appfinal/EditProfilePage23.dart';
import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final supabase = Supabase.instance.client;

  int _selectedIndex = 3; // index ของเมนู "ข้อมูลส่วนตัว"
  Map<String, dynamic>? userProfile;
  bool isLoading = true;

  int totalServices = 0;
  int totalBookings = 0;

  List<Map<String, dynamic>> reviews = [];
  bool isLoadingReviews = true;

  void _onMenuSelected(int index) {
    if (index == _selectedIndex) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BookingPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AgriVehicleManagementPage()),
        );
        break;
      case 3:
        // อยู่หน้า Profile อยู่แล้ว
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ContactAdminPage2()),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage1()),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      final serviceCountResponse =
          await supabase
              .from('vehicles')
              .select('vehicle_id')
              .eq('renter_id', userId)
              .count();

      final bookingCountResponse =
          await supabase
              .from('bookings')
              .select('booking_id')
              .eq('renter_id', userId)
              .count();

      setState(() {
        totalServices = serviceCountResponse.count ?? 0;
        totalBookings = bookingCountResponse.count ?? 0;
      });
    } catch (e) {
      print('Error loading user stats: $e');
      setState(() {
        totalServices = 0;
        totalBookings = 0;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response =
          await supabase
              .from('users')
              .select(
                'user_id, username, full_name, email, phone, user_type, province_id, profile_image_url, provinces!users_province_id_fkey(province_name)',
              )
              .eq('user_id', user.id)
              .single();

      String? imageUrl;
      if (response['profile_image_url'] != null &&
          response['profile_image_url'] != '') {
        final path = response['profile_image_url'] as String;
        imageUrl = supabase.storage.from('renter').getPublicUrl(path);
      }

      setState(() {
        userProfile = response;
        if (imageUrl != null) {
          userProfile!['profile_image_url'] = imageUrl;
        }
        isLoading = false;
      });

      await _loadUserStats(user.id);
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print('Error loading profile: $error');
    }
  }

  Future<void> _loadReviews() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoadingReviews = false;
      });
      return;
    }

    try {
      // ดึง vehicle_id ของพาหนะที่เป็นของ renter ที่ล็อกอิน
      final vehicleIdsData = await supabase
          .from('vehicles')
          .select('vehicle_id')
          .eq('renter_id', user.id);

      final vehicleIds =
          (vehicleIdsData as List)
              .map((v) => v['vehicle_id'].toString())
              .toList();

      if (vehicleIds.isEmpty) {
        setState(() {
          reviews = [];
          isLoadingReviews = false;
        });
        return;
      }

      // ดึง booking_id ที่เกี่ยวข้องกับพาหนะเหล่านั้น
      final bookingsData = await supabase
          .from('bookings')
          .select('booking_id, farmer_id')
          .inFilter('vehicle_id', vehicleIds);

      final bookingIds =
          (bookingsData as List)
              .map((b) => b['booking_id'].toString())
              .toList();

      if (bookingIds.isEmpty) {
        setState(() {
          reviews = [];
          isLoadingReviews = false;
        });
        return;
      }

      // ดึงรีวิวที่เกี่ยวข้องกับ booking_id เหล่านั้น พร้อมชื่อผู้รีวิว (farmer)
      final reviewsData = await supabase
          .from('reviews')
          .select(
            'review_id, booking_id, rating, comment, created_at, bookings!fk_reviews_booking(farmer_id, users!bookings_farmer_id_fkey(full_name))',
          )
          .inFilter('booking_id', bookingIds)
          .order('created_at', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> loadedReviews = [];
      for (final item in reviewsData as List) {
        String reviewerName = 'ผู้ใช้';
        if (item['bookings'] != null &&
            item['bookings']['users'] != null &&
            item['bookings']['users']['full_name'] != null) {
          reviewerName = item['bookings']['users']['full_name'];
        }
        loadedReviews.add({
          'review_id': item['review_id'],
          'booking_id': item['booking_id'],
          'rating': item['rating'],
          'comment': item['comment'],
          'created_at': item['created_at'],
          'reviewer_name': reviewerName,
        });
      }

      setState(() {
        reviews = loadedReviews;
        isLoadingReviews = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        reviews = [];
        isLoadingReviews = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadReviews();
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (isLoadingReviews) {
      return Center(child: CircularProgressIndicator());
    }
    if (reviews.isEmpty) {
      return Text('ยังไม่มีรีวิวจากชาวนา');
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'รีวิวจากชาวนา',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...reviews.map((review) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['reviewer_name'] ?? 'ผู้ใช้',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < (review['rating'] ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      review['comment'] ?? '',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      review['created_at'] != null
                          ? DateTime.parse(
                            review['created_at'],
                          ).toLocal().toString().split('.')[0]
                          : '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userProfile == null) {
      return Scaffold(body: Center(child: Text('ไม่พบข้อมูลผู้ใช้')));
    }

    final name = userProfile!['full_name'] ?? 'ไม่มีชื่อ';
    final email = userProfile!['email'] ?? 'ไม่มีอีเมล';
    final phone = userProfile!['phone'] ?? '-';
    final userType = userProfile!['user_type'] ?? '-';
    final provinceName = userProfile?['provinces']?['province_name'] ?? '-';
    String? avatarUrl = userProfile!['profile_image_url'] as String?;
    final displayAvatarUrl =
        (avatarUrl == null || avatarUrl.isEmpty)
            ? 'https://placehold.co/200x200'
            : '$avatarUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    Widget _buildProfileHeader() {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 15, 76, 47),
              Color.fromARGB(255, 15, 76, 47),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ข้อมูลส่วนตัว',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'จัดการข้อมูลส่วนตัวและการตั้งค่าบัญชีของคุณ',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildProfileCard() {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(displayAvatarUrl),
                backgroundColor: Colors.transparent,
              ),
              SizedBox(height: 16),
              Text(
                name,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 15, 76, 47),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'ยืนยันแล้ว',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                userType == 'renter' ? 'ผู้ให้เช่า' : 'เกษตรกร',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBox('บริการทั้งหมด', totalServices.toString()),
                  _buildStatBox('การจองทั้งหมด', totalBookings.toString()),
                ],
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    Widget _buildContactInfo() {
      final contacts = [
        {'icon': Icons.email, 'label': 'อีเมล', 'value': email},
        {'icon': Icons.phone, 'label': 'เบอร์โทรศัพท์', 'value': phone},
        {'icon': Icons.location_on, 'label': 'จังหวัด', 'value': provinceName},
      ];

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ข้อมูลการติดต่อ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...contacts.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.all(12),
                        child: Icon(c['icon'] as IconData, color: Colors.blue),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['label'] as String,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              c['value'] as String,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }

    Widget _buildPersonalInfoSection() {
      final info = [
        {'label': 'ชื่อ-นามสกุล', 'value': name},
        {'label': 'อีเมล', 'value': email},
        {'label': 'UserId', 'value': userProfile!['user_id'] ?? '-'},
      ];

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ข้อมูลส่วนตัว',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EditProfilePage2(
                                profileData: userProfile ?? {},
                              ),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProfile();
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.edit, size: 18),
                    label: Text('แก้ไข'),
                  ),
                ],
              ),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: info.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width < 600 ? 1 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 24,
                  childAspectRatio: 5,
                ),
                itemBuilder: (context, index) {
                  final item = info[index];
                  return Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          item['label']! as String,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item['value']! as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildBottomNavigation() {
      return BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;
          _onMenuSelected(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: [
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.gaugeHigh),
            label: 'แดชบอร์ด',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.calendarAlt),
            label: 'การจอง',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.tractor),
            label: 'พาหนะ',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.user),
            label: 'ข้อมูลส่วนตัว',
          ),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppSidebar(
        selectedIndex: _selectedIndex,
        onMenuSelected: _onMenuSelected,
        userName: userProfile?['full_name'] ?? 'ไม่มีชื่อ',
        userRole:
            userProfile?['user_type'] == 'renter' ? 'ผู้ให้เช่า' : 'เกษตรกร',
        userAvatarUrl: userProfile?['profile_image_url'],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 1,
              leading: IconButton(
                icon: Icon(Icons.menu, color: Colors.grey[700]),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                'ข้อมูลส่วนตัว',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildProfileHeader(),
                  SizedBox(height: 24),
                  Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildProfileCard(),
                            SizedBox(height: 24),
                            _buildContactInfo(),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? 0 : 24,
                        height: isMobile ? 24 : 0,
                      ),
                      Flexible(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildPersonalInfoSection(),
                            SizedBox(height: 24),
                            _buildReviewsSection(),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigation() : null,
    );
  }
}
