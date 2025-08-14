import 'package:appfinal/AddAgriculturalVehiclePage19.dart';
import 'package:appfinal/AgriVehicleManagementPage21.dart';
import 'package:appfinal/BookingPage20.dart';
import 'package:appfinal/ContactAdminPage24.dart';
import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/Notification.dart';
import 'package:appfinal/ProfilePage22.dart';
import 'package:appfinal/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _recentBookings = [];
  bool _isLoadingVehicles = true;
  bool _isLoadingBookings = true;
  bool _isLoadingStats = true;

  String _renterName = 'ผู้ใช้';
  String _userEmail = '';
  String? _userProfileImageUrl;

  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int totalBookings = 0;
  int pendingBookings = 0;
  int completedBookings = 0; // <--- เพิ่มบรรทัดนี้
  double totalRevenue = 0;
  int totalVehicles = 0;

  final int totalBookingsGoal = 1500;
  final int pendingBookingsGoal = 75;
  final int completedBookingsGoal = 1200;
  final int totalVehiclesGoal = 900;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String mapBookingStatusToThai(String status) {
    switch (status) {
      case 'pending':
        return 'รอการตอบรับ';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'cancelled':
        return 'ยกเลิก';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'waiting_farmer_confirm':
        return 'รอชาวนายืนยัน';
      default:
        return status;
    }
  }

  String mapVehicleStatusToThai(String status) {
    switch (status) {
      case 'active':
        return 'พร้อมใช้งาน';
      case 'inactive':
        return 'ไม่พร้อมใช้งาน';
      default:
        return status;
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchUserProfile(),
      _fetchVehicles(),
      _fetchRecentBookings(),
      _fetchStats(),
    ]);
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoadingVehicles = true;
      _isLoadingBookings = true;
      _isLoadingStats = true;
    });
    await _loadAllData();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final currentUser = supabase.auth.currentUser;
      print('Fetching user profile for user id: ${currentUser?.id}');
      if (currentUser == null) return;

      final response =
          await supabase
              .from('users')
              .select('full_name, email, profile_image_url')
              .eq('user_id', currentUser.id)
              .maybeSingle();

      print('User profile response: $response');

      if (response != null) {
        setState(() {
          _renterName = response['full_name'] ?? 'ผู้ใช้';
          _userEmail = response['email'] ?? '';
          _userProfileImageUrl = response['profile_image_url'];
        });
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      final currentRenterId = supabase.auth.currentUser?.id;
      print('Fetching vehicles for renter id: $currentRenterId');
      if (currentRenterId == null) {
        setState(() => _isLoadingVehicles = false);
        return;
      }

      final data = await supabase
          .from('vehicles')
          .select('''
          vehicle_id, renter_id, vehicle_name, price_per_day, location, description, service_details, service_capacity, status, vehicle_type, is_published, is_available, province_id,
          vehicleimages!fk_vehicleimages_vehicle (image_url, is_main_image),
          fk_vehicles_renter (full_name)
        ''')
          .eq('is_available', true)
          .eq('renter_id', currentRenterId)
          .limit(10);

      print('Vehicles data count: ${data?.length}');
      print('Vehicles data: $data');

      if (data != null) {
        List<String> vehicleIds =
            (data as List).map((e) => e['vehicle_id'] as String).toList();

        Map<String, double> avgRatings = await _fetchAverageRatings(
          vehicleIds,
          currentRenterId,
        );

        print('Average ratings: $avgRatings');

        setState(() {
          _vehicles =
              data.map((e) {
                String? mainImageUrl;
                if (e['vehicleimages'] != null) {
                  final images = e['vehicleimages'] as List;
                  final mainImage = images.firstWhere(
                    (img) => img['is_main_image'] == true,
                    orElse: () => null,
                  );
                  mainImageUrl = mainImage?['image_url'];
                }

                final vid = e['vehicle_id'] as String;
                final rating = avgRatings[vid] ?? 0.0;

                return {
                  'id': vid,
                  'name': e['vehicle_name'] ?? '-',
                  'price': e['price_per_day'] ?? 0,
                  'status': mapVehicleStatusToThai(e['status'] ?? 'active'),
                  'location': e['location'] ?? '-',
                  'owner':
                      e['fk_vehicles_renter']?['full_name'] ?? 'ไม่ทราบชื่อ',
                  'image': mainImageUrl ?? 'assets/placeholder_vehicle.jpg',
                  'rating': rating.round(),
                  'description': e['description'] ?? '',
                  'tags': [],
                  'available_dates': '',
                  'usage_details': e['service_details'] ?? '',
                };
              }).toList();
          _isLoadingVehicles = false;
        });
      } else {
        setState(() => _isLoadingVehicles = false);
      }
    } catch (e) {
      print('Error fetching vehicles: $e');
      setState(() => _isLoadingVehicles = false);
    }
  }

  Future<Map<String, double>> _fetchAverageRatings(
    List<String> vehicleIds,
    String currentRenterId,
  ) async {
    if (vehicleIds.isEmpty) return {};

    try {
      final orConditions = vehicleIds
          .map((id) => 'vehicle_id.eq.$id')
          .join(',');

      print(
        'Fetching bookings for vehicles: $vehicleIds and renter: $currentRenterId',
      );

      final bookings = await supabase
          .from('bookings')
          .select('booking_id, vehicle_id')
          .or(orConditions)
          .eq('renter_id', currentRenterId);

      print('Bookings fetched: ${bookings?.length}');
      print('Bookings data: $bookings');

      if (bookings == null || bookings.isEmpty) return {};

      Map<String, String> bookingToVehicle = {};
      for (var b in bookings) {
        bookingToVehicle[b['booking_id']] = b['vehicle_id'];
      }

      final bookingIds = bookingToVehicle.keys.toList();
      if (bookingIds.isEmpty) return {};

      final orBookingConditions = bookingIds
          .map((id) => 'booking_id.eq.$id')
          .join(',');

      print('Fetching reviews for bookings: $bookingIds');

      final reviews = await supabase
          .from('reviews')
          .select('booking_id, rating')
          .or(orBookingConditions);

      print('Reviews fetched: ${reviews?.length}');
      print('Reviews data: $reviews');

      if (reviews == null || reviews.isEmpty) return {};

      Map<String, List<int>> ratingsMap = {};
      for (var r in reviews) {
        final bookingId = r['booking_id'];
        final rating = r['rating'] as int?;
        final vehicleId = bookingToVehicle[bookingId];
        if (vehicleId != null && rating != null) {
          ratingsMap.putIfAbsent(vehicleId, () => []).add(rating);
        }
      }

      Map<String, double> avgRatings = {};
      ratingsMap.forEach((vid, ratings) {
        avgRatings[vid] = ratings.reduce((a, b) => a + b) / ratings.length;
      });

      print('Calculated average ratings: $avgRatings');

      return avgRatings;
    } catch (e) {
      print('Error fetching average ratings: $e');
      return {};
    }
  }

  Future<void> _fetchRecentBookings() async {
    try {
      final currentRenterId = supabase.auth.currentUser?.id;
      print('Fetching recent bookings for renter id: $currentRenterId');
      if (currentRenterId == null) {
        setState(() => _isLoadingBookings = false);
        return;
      }

      final data = await supabase
          .from('bookings')
          .select(
            'booking_id, booking_start_date, status, farmer_id, vehicle_id, farmer:users!fk_bookings_farmer(full_name,email), vehicle:vehicles!fk_bookings_vehicle(vehicle_name), renter_id',
          )
          .eq('renter_id', currentRenterId)
          .order('created_at', ascending: false)
          .limit(5);

      print('Recent bookings count: ${data?.length}');
      print('Recent bookings data: $data');

      if (data != null) {
        setState(() {
          _recentBookings =
              (data as List).map((booking) {
                return {
                  'farmer': booking['farmer']?['full_name'] ?? 'ไม่ทราบชื่อ',
                  'email': booking['farmer']?['email'] ?? '',
                  'vehicle': booking['vehicle']?['vehicle_name'] ?? '',
                  'date': DateFormat(
                    'd MMM yyyy',
                    'th',
                  ).format(DateTime.parse(booking['booking_start_date'])),
                  'status': mapBookingStatusToThai(booking['status']),
                  'statusColor':
                      booking['status'] == 'confirmed'
                          ? Colors.green
                          : Colors.grey,
                  'frameNumber': booking['booking_id'].toString().substring(
                    0,
                    3,
                  ),
                  'booking_id': booking['booking_id'],
                };
              }).toList();
          _isLoadingBookings = false;
        });
      } else {
        setState(() => _isLoadingBookings = false);
      }
    } catch (e) {
      print('Error fetching recent bookings: $e');
      setState(() => _isLoadingBookings = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final currentRenterId = supabase.auth.currentUser?.id;
      print('Fetching stats for renter id: $currentRenterId');
      if (currentRenterId == null) {
        setState(() => _isLoadingStats = false);
        return;
      }

      final totalBookingsResponse = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('renter_id', currentRenterId);
      totalBookings = (totalBookingsResponse as List).length;
      print('Total bookings: $totalBookings');

      final pendingBookingsResponse = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('renter_id', currentRenterId)
          .eq('status', 'pending');
      pendingBookings = (pendingBookingsResponse as List).length;
      print('Pending bookings: $pendingBookings');

      // เพิ่มตรงนี้
      final completedBookingsResponse = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('renter_id', currentRenterId)
          .eq('status', 'completed');
      completedBookings = (completedBookingsResponse as List).length;
      print('Completed bookings: $completedBookings');

      totalRevenue = 0;

      final totalVehiclesResponse = await supabase
          .from('vehicles')
          .select('vehicle_id')
          .eq('renter_id', currentRenterId);
      totalVehicles = (totalVehiclesResponse as List).length;
      print('Total vehicles: $totalVehicles');

      setState(() => _isLoadingStats = false);
    } catch (e) {
      print('Error fetching stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      final response =
          await supabase
              .from('bookings')
              .update({'status': newStatus})
              .eq('booking_id', bookingId)
              .select();

      if (response == null || (response is List && response.isEmpty)) {
        _showNotification('ไม่พบการจองที่ต้องการอัปเดต หรือไม่มีสิทธิ์');
      } else {
        _showNotification('อัปเดตสถานะการจองเรียบร้อย');
        await _fetchRecentBookings();
        await _fetchStats();
      }
    } catch (e) {
      print('Error updating booking status: $e');
      _showNotification('เกิดข้อผิดพลาดในการอัปเดตสถานะ');
    }
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    try {
      final response =
          await supabase
              .from('vehicles')
              .delete()
              .eq('vehicle_id', vehicleId)
              .select();

      if (response == null || (response is List && response.isEmpty)) {
        _showNotification('ไม่พบพาหนะที่ต้องการลบ หรือไม่มีสิทธิ์ในการลบ');
      } else {
        _showNotification('ลบพาหนะเรียบร้อย');
        await _fetchVehicles();
        await _fetchStats();
      }
    } catch (e) {
      print('Error deleting vehicle: $e');
      _showNotification('เกิดข้อผิดพลาดในการลบพาหนะ');
    }
  }

  void _navigateToPage(int index) {
    if (index == _selectedIndex) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    setState(() => _selectedIndex = index);

    final pages = [
      DashboardPage(),
      BookingPage(),
      AgriVehicleManagementPage(),
      ProfilePage(),
      ContactAdminPage2(),
      LoginPage1(),
    ];

    if (index >= 0 && index < pages.length) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => pages[index]),
      );
    }
  }

  Future<bool> _confirmLogout() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('ยืนยันการออกจากระบบ'),
                content: Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('ยกเลิก'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('ออกจากระบบ'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVehicles || _isLoadingBookings || _isLoadingStats) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF1F5F9),
      drawer: AppSidebar(
        selectedIndex: _selectedIndex,
        onMenuSelected: _navigateToPage,
        userName: _renterName,
        userRole: 'renter',
      ),
      body: SafeArea(
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _refreshData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              final isTablet =
                  constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
              final isMobile = constraints.maxWidth < 768;

              return Column(
                children: [
                  _buildAppBar(isMobile: isMobile),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: _buildDashboardContent(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                        screenWidth: constraints.maxWidth,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 768
              ? _buildBottomNavigation()
              : null,
    );
  }

  Widget _buildAppBar({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'เปิดเมนู',
          ),
          Text(
            'แดชบอร์ด',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          if (!isMobile) Row(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
    required double screenWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(isMobile: isMobile),
          SizedBox(height: 24),
          _buildStatsSection(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
          SizedBox(height: 24),
          _buildVehiclesSection(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            screenWidth: screenWidth,
          ),
          SizedBox(height: 24),
          _buildRecentBookingsSection(
            isMobile: isMobile,
            screenWidth: screenWidth,
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection({required bool isMobile}) {
    final notificationButton = ElevatedButton.icon(
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationPage()),
          ),
      icon: Icon(Icons.notifications),
      label: Text('แจ้งเตือน'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFEF4444),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF059669)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _renterName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'นี่คือข้อมูลธุรกิจการเช่าพาหนะทางการเกษตรของคุณในวันนี้',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (!isMobile) notificationButton,
            ],
          ),
          if (isMobile)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: notificationButton,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    int crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

    final stats = [
      {
        'title': 'การจองทั้งหมด',
        'value': totalBookings.toString(),
        'progress':
            totalBookingsGoal > 0 ? totalBookings / totalBookingsGoal : 0,
        'icon': FontAwesomeIcons.calendarCheck,
        'iconColor': Colors.green,
      },
      {
        'title': 'รอการตอบรับ',
        'value': pendingBookings.toString(),
        'progress':
            pendingBookingsGoal > 0 ? pendingBookings / pendingBookingsGoal : 0,
        'icon': FontAwesomeIcons.hourglassHalf,
        'iconColor': Colors.amber,
      },
      {
        'title': 'เสร็จสิ้นการจอง',
        'value': completedBookings.toString(),
        'progress':
            completedBookingsGoal > 0
                ? completedBookings / completedBookingsGoal
                : 0,
        'icon': FontAwesomeIcons.checkCircle, // หรือไอคอนอื่นที่ต้องการ
        'iconColor': Colors.green,
      },
      {
        'title': 'พาหนะทั้งหมด',
        'value': totalVehicles.toString(),
        'progress':
            totalVehiclesGoal > 0 ? totalVehicles / totalVehiclesGoal : 0,
        'icon': FontAwesomeIcons.tractor,
        'iconColor': Colors.blue,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildStatCard(stats[index]),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['title'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      stat['value'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stat['iconColor'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat['icon'], color: stat['iconColor'], size: 20),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat['progress'].clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(stat['iconColor']),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesSection({
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
    required double screenWidth,
  }) {
    int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    Widget buildTabs() {
      final tabs = [];
      return Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            _buildTabButton(tabs[i], isActive: i == 0),
            SizedBox(width: 8),
          ],
          // ปุ่มเพิ่มพาหนะถูกตัดออกไปแล้ว
        ],
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'พาหนะทางการเกษตรให้เช่า',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (!isMobile) buildTabs(),
              ],
            ),
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: buildTabs(),
                ),
              ),
            SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: (_vehicles.length / crossAxisCount).ceil(),
              itemBuilder: (context, rowIndex) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(crossAxisCount, (colIndex) {
                      final index = rowIndex * crossAxisCount + colIndex;
                      if (index < _vehicles.length) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: colIndex < crossAxisCount - 1 ? 16 : 0,
                            ),
                            child: _buildVehicleCard(_vehicles[index]),
                          ),
                        );
                      }
                      return Expanded(child: SizedBox());
                    }),
                  ),
                );
              },
            ),
            SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgriVehicleManagementPage(),
                      ),
                    ),
                icon: Icon(Icons.arrow_forward),
                label: Text('ดูพาหนะทั้งหมด'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, {bool isActive = false}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFF0FDF4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[500],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final imageUrl = vehicle['image'] ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child:
                    imageUrl.startsWith('http')
                        ? Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Image.asset(
                                'assets/placeholder_vehicle.jpg',
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                        )
                        : Image.asset(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        vehicle['status'] == 'พร้อมใช้งาน'
                            ? Color(0xFFD1FAE5)
                            : Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vehicle['status'],
                    style: TextStyle(
                      color:
                          vehicle['status'] == 'พร้อมใช้งาน'
                              ? Color(0xFF065F46)
                              : Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        vehicle['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < vehicle['rating']
                              ? Icons.star
                              : Icons.star_border,
                          color:
                              index < vehicle['rating']
                                  ? Colors.amber
                                  : Colors.grey[300],
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  vehicle['description'],
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                _buildIconTextRow(Icons.location_on, vehicle['location']),
                SizedBox(height: 8),
                _buildIconTextRow(Icons.business, vehicle['owner']),
                SizedBox(height: 8),
                _buildIconTextRow(Icons.date_range, vehicle['available_dates']),
                SizedBox(height: 12),
                ExpansionTile(
                  title: Text(
                    'รายละเอียดการใช้งาน',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.only(bottom: 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['usage_details'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      vehicle['tags'].map<Widget>((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '฿${NumberFormat("#,###").format(vehicle['price'])} ',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '/ชั่วโมง',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ลบปุ่มลบพาหนะออก (ถังขยะ)
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTextRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 16),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBookingsSection({
    required bool isMobile,
    required double screenWidth,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'การจองล่าสุด',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookingPage()),
                      ),
                  icon: Icon(Icons.chevron_right, size: 16),
                  label: Text('ดูทั้งหมด'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Table(
              columnWidths: {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                // ลบ column 4 ออก
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              children: [
                _buildTableRowHeader([
                  'ลูกค้า',
                  'บริการ',
                  'วันที่จอง',
                  'สถานะ',
                  // ลบ 'การจัดการ' ออก
                ]),
                ..._recentBookings.map(_buildTableRowBooking).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRowHeader(List<String> headers) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      children:
          headers
              .map(
                (text) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  TableRow _buildTableRowBooking(Map<String, dynamic> booking) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      children: [
        _buildTableCellCustomer(booking),
        _buildTableCellText(booking['vehicle']),
        _buildTableCellText(booking['date']),
        _buildTableCellStatus(booking),
        // ลบ column สุดท้ายออก
      ],
    );
  }

  Widget _buildTableCellCustomer(Map<String, dynamic> booking) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Text(
              booking['farmer'][0],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['farmer'],
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  booking['email'],
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCellText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text),
    );
  }

  Widget _buildTableCellStatus(Map<String, dynamic> booking) {
    final color = _getStatusColor(booking['status']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frame ${booking['frameNumber']}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              booking['status'],
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ยืนยันแล้ว':
        return const Color.fromARGB(255, 96, 208, 239);
      case 'รอการตอบรับ':
        return Colors.amber;
      case 'ยกเลิก':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Widget _buildBottomNavigation() {
    final items = [
      {'icon': FontAwesomeIcons.gaugeHigh, 'label': 'แดชบอร์ด'},
      {'icon': FontAwesomeIcons.calendarAlt, 'label': 'การจอง'},
      {'icon': FontAwesomeIcons.tractor, 'label': 'พาหนะ'},
      {'icon': FontAwesomeIcons.user, 'label': 'ข้อมูลส่วนตัว'},
      {'icon': FontAwesomeIcons.phone, 'label': 'ติดต่อผู้ดูแลระบบ'},
      {'icon': FontAwesomeIcons.rightFromBracket, 'label': 'ออกจากระบบ'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -1),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = _selectedIndex == index;
          return InkWell(
            onTap: () async {
              if (index == 5) {
                final confirm = await _confirmLogout();
                if (confirm) {
                  await supabase.auth.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage1()),
                  );
                }
              } else {
                _navigateToPage(index);
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color:
                        isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[500],
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      color:
                          isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
