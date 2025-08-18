import 'dart:async';
import 'package:appfinal/AgriVehicleManagementPage21.dart';
import 'package:appfinal/ContactAdminPage24.dart';
import 'package:appfinal/DashboardPage18.dart';
import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/ProfilePage22.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_sidebar.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({Key? key}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filters
  String? selectedStatus;
  String? selectedVehicleType;

  String mapTimePeriodLabel(dynamic timePeriod) {
    switch (timePeriod) {
      case 'morning':
        return 'ช่วงเช้า';
      case 'afternoon':
        return 'ช่วงบ่าย';
      case 'evening':
        return 'ช่วงเย็น';
      case 1:
        return 'ช่วงเช้า';
      case 2:
        return 'ช่วงบ่าย';
      case 3:
        return 'ช่วงเย็น';
      default:
        return '-';
    }
  }

  // Tabs
  final List<Map<String, dynamic>> tabs = [
    {'label': 'ทั้งหมด', 'count': 0, 'value': null},
    {'label': 'ยืนยันแล้ว', 'count': 0, 'value': 'confirmed'},
    {'label': 'รอการยืนยัน', 'count': 0, 'value': 'pending'},
    {'label': 'ยกเลิก', 'count': 0, 'value': 'cancelled'},
    {'label': 'เสร็จสิ้น', 'count': 0, 'value': 'completed'},
    {'label': 'รอชาวนายืนยัน', 'count': 0, 'value': 'waiting_farmer_confirm'},
  ];
  String? activeTabValue;

  List<Map<String, dynamic>> bookings = [];
  bool _isLoading = true;

  Map<String, dynamic>? userProfile;
  bool _isUserLoading = true;

  // คำขอยกเลิกการจอง
  List<Map<String, dynamic>> cancellationRequests = [];
  bool _isLoadingCancellationRequests = true;

  Timer? _cancellationTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    activeTabValue = null;
    selectedStatus = null;
    selectedVehicleType = null;
    _refreshData();
    _startCancellationTimer();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _cancellationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Trigger rebuild to update countdown timers
      });
    });
  }

  void _startCancellationTimer() {
    _cancellationTimer?.cancel();
    _cancellationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndAutoApproveCancellations();
    });
  }

  Future<void> _checkAndAutoApproveCancellations() async {
    final now = DateTime.now().toUtc();
    List<Map<String, dynamic>> expiredRequests = [];

    for (var request in cancellationRequests) {
      final cancelledAt = DateTime.tryParse(request['cancelledAt'] ?? '');
      if (cancelledAt != null) {
        final diff = now.difference(cancelledAt);
        if (diff.inHours >= 24) {
          expiredRequests.add(request);
        }
      }
    }

    if (expiredRequests.isNotEmpty) {
      for (var request in expiredRequests) {
        await _autoApproveCancellation(
          request['cancellationId'],
          request['bookingId'],
        );
      }
      // Refresh data after auto-approval
      await _fetchCancellationRequests();
      await _fetchBookings();
    }
  }

  Future<void> _refreshData() async {
    await _fetchUserProfile();
    await _fetchBookings();
    await _fetchCancellationRequests();
  }

  Future<void> _fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isUserLoading = false;
      });
      return;
    }
    try {
      final response =
          await supabase
              .from('users')
              .select('user_id, full_name, user_type, profile_image_url')
              .eq('user_id', user.id)
              .single();

      setState(() {
        userProfile = response;
        _isUserLoading = false;
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() {
        _isUserLoading = false;
      });
    }
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentRenterId = supabase.auth.currentUser?.id;

      if (currentRenterId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      var query = supabase.from('bookings').select('''
        booking_id,
        farmer_id,
        status,
        created_at,
        booking_start_date,
        booking_end_date,
        renter_id,
        time_period,
        area_size,
        farmer:users!fk_bookings_farmer(full_name,email,phone,address),
        vehicle:vehicles!fk_bookings_vehicle(
          vehicle_id,
          vehicle_name,
          vehicle_type,
          description,
          price_per_day,
          location,
          renter_id,
          service_details,
          owner:users!fk_vehicles_renter(full_name),
          vehicleimages:vehicleimages!fk_vehicleimages_vehicle(
            image_url
          )
        ),
        reviews:reviews!fk_reviews_booking(
          rating
        ),
        created_at
      ''');

      query = query.eq('renter_id', currentRenterId);

      if (activeTabValue != null && activeTabValue!.isNotEmpty) {
        query = query.eq('status', activeTabValue!);
      }

      if (selectedStatus != null && selectedStatus!.isNotEmpty) {
        query = query.eq('status', selectedStatus!);
      }

      if (selectedVehicleType != null && selectedVehicleType!.isNotEmpty) {
        query = query.eq('vehicle.vehicle_type', selectedVehicleType!);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);
      print('จำนวน booking ที่ดึงมา: ${response?.length ?? 0}');

      if (response != null && response is List) {
        bookings =
            response.map((e) {
              final farmer = e['farmer'] ?? {};
              final vehicle = e['vehicle'] ?? {};
              final vehicleImages = vehicle['vehicleimages'] ?? [];
              final reviews = e['reviews'] ?? [];

              double avgRating = 0;
              if (reviews is List && reviews.isNotEmpty) {
                final ratings =
                    reviews.map((r) => (r['rating'] ?? 0) as num).toList();
                avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
              }

              String? mainImageUrl;
              if (vehicleImages is List && vehicleImages.isNotEmpty) {
                mainImageUrl = vehicleImages[0]['image_url'];
              }

              return {
                'id': e['booking_id'] ?? '',
                'userId': e['farmer_id'] ?? '',
                'customerName': farmer['full_name'] ?? 'ไม่ทราบชื่อ',
                'customerEmail': farmer['email'] ?? '',
                'phone': farmer['phone'] ?? '-',
                'address': farmer['address'] ?? '-',
                'vehicle': {
                  'name': vehicle['vehicle_name'] ?? '-',
                  'vehicle_type': vehicle['vehicle_type'] ?? '',
                  'rating': avgRating,
                  'description': vehicle['description'] ?? '',
                  'price_per_day': vehicle['price_per_day'] ?? 0,
                  'location': vehicle['location'] ?? '',
                  'owner':
                      vehicle['owner'] != null
                          ? vehicle['owner']['full_name'] ?? '-'
                          : '-',
                  'service_details': vehicle['service_details'] ?? '',
                  'vehicleimages': vehicleImages,
                  'image_url': mainImageUrl ?? '',
                },
                'bookingStartDate':
                    e['booking_start_date'] != null
                        ? DateTime.parse(
                          e['booking_start_date'],
                        ).toLocal().toString().split(' ')[0]
                        : '-',
                'bookingEndDate':
                    e['booking_end_date'] != null
                        ? DateTime.parse(
                          e['booking_end_date'],
                        ).toLocal().toString().split(' ')[0]
                        : '-',
                'created_at': e['created_at'] ?? '',
                'areaSize': e['area_size'] ?? '-',
                'time_period': e['time_period'] ?? null,
                'bookingDate':
                    e['booking_start_date'] != null
                        ? DateTime.parse(
                          e['booking_start_date'],
                        ).toLocal().toString().split(' ')[0]
                        : '',
                'duration':
                    (e['booking_start_date'] != null &&
                            e['booking_end_date'] != null)
                        ? _calculateDuration(
                          e['booking_start_date'],
                          e['booking_end_date'],
                        )
                        : '',
                'status': e['status'] ?? '',
                'statusLabel': _mapStatusLabel(e['status']),
                'statusColor': _mapStatusColor(e['status']),
              };
            }).toList();

        // เพิ่มตรงนี้
        print('=== DEBUG: Booking created_at ===');
        for (var b in bookings) {
          print('booking_id: ${b['id']} | created_at: ${b['created_at']}');
        }
      } else {
        bookings = [];
      }

      await _updateTabsCount(currentRenterId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await supabase.from('notifications').insert({
        'user_id': userId,
        'message': message,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _updateTabsCount(String renterId) async {
    try {
      for (var tab in tabs) {
        var query = supabase
            .from('bookings')
            .select('booking_id')
            .eq('renter_id', renterId);

        if (tab['value'] != null && tab['value'].toString().isNotEmpty) {
          query = query.eq('status', tab['value']);
        }

        final response = await query;

        final count = (response is List) ? response.length : 0;
        tab['count'] = count;
      }

      setState(() {});
    } catch (e) {
      print('Error updating tabs count: $e');
    }
  }

  String _calculateDuration(String start, String end) {
    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      final diff = endDate.difference(startDate);

      if (diff.inDays >= 1) {
        return '${diff.inDays} วัน';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} ชั่วโมง';
      } else {
        return '${diff.inMinutes} นาที';
      }
    } catch (_) {
      return '';
    }
  }

  String _mapStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'pending':
        return 'รอการยืนยัน';
      case 'cancelled':
        return 'ยกเลิก';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'waiting_farmer_confirm':
        return 'รอชาวนายืนยัน';
      default:
        return status ?? '';
    }
  }

  Color _mapStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color.fromARGB(255, 96, 208, 239);
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'waiting_farmer_confirm':
        return const Color.fromARGB(255, 218, 103, 238);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get filteredBookings {
    return bookings.where((booking) {
      final matchTab =
          activeTabValue == null || booking['status'] == activeTabValue;
      final matchStatus =
          selectedStatus == null ||
          selectedStatus == '' ||
          booking['status'] == selectedStatus;
      final matchVehicleType =
          selectedVehicleType == null ||
          selectedVehicleType == '' ||
          (booking['vehicle']['vehicle_type']?.toString().toLowerCase() ==
              selectedVehicleType!.toLowerCase());
      return matchTab && matchStatus && matchVehicleType;
    }).toList();
  }

  // ฟังก์ชันดึงคำขอยกเลิกการจองจาก bookingcancellations
  Future<void> _fetchCancellationRequests() async {
    setState(() {
      _isLoadingCancellationRequests = true;
    });

    try {
      final currentRenterId = supabase.auth.currentUser?.id;
      if (currentRenterId == null) {
        setState(() {
          _isLoadingCancellationRequests = false;
        });
        return;
      }

      final now = DateTime.now().toUtc();
      final yesterday = now.subtract(const Duration(hours: 24));

      final response = await supabase
          .from('bookingcancellations')
          .select('''
      cancellation_id,
      booking_id,
      cancelled_by,
      cancel_reason,
      cancelled_at,
      booking:bookings!bookingcancellations_booking_id_fkey(
        booking_id,
        farmer_id,
        time_period,
        area_size,
        status,
        booking_start_date,
        booking_end_date,
        renter_id,
        farmer:users!fk_bookings_farmer(full_name,email,phone,address),
        vehicle:vehicles!fk_bookings_vehicle(
          vehicle_id,
          vehicle_name,
          vehicle_type,
          description,
          price_per_day,
          location,
          renter_id,
          service_details,
          owner:users!fk_vehicles_renter(full_name),
          vehicleimages:vehicleimages!fk_vehicleimages_vehicle(
            image_url
          )
        )
      )
    ''')
          .eq('booking.renter_id', currentRenterId)
          .eq('cancelled_by', 'farmer')
          .gte('cancelled_at', yesterday.toIso8601String())
          .order('cancelled_at', ascending: false);

      if (response != null && response is List) {
        cancellationRequests =
            response.map((e) {
              final booking = e['booking'] ?? {};
              final farmer = booking['farmer'] ?? {};
              final vehicle = booking['vehicle'] ?? {};
              final vehicleImages = vehicle['vehicleimages'] ?? [];

              String? mainImageUrl;
              if (vehicleImages is List && vehicleImages.isNotEmpty) {
                mainImageUrl = vehicleImages[0]['image_url'];
              }

              return {
                'cancellationId': e['cancellation_id'],
                'bookingId': e['booking_id'],
                'cancelledBy': e['cancelled_by'],
                'cancelReason': e['cancel_reason'] ?? '',
                'cancelledAt': e['cancelled_at'],
                'booking': {
                  'id': booking['booking_id'] ?? '',
                  'userId': booking['farmer_id'] ?? '',
                  'customerName': farmer['full_name'] ?? 'ไม่ทราบชื่อ',
                  'customerEmail': farmer['email'] ?? '',
                  'vehicle': {
                    'name': vehicle['vehicle_name'] ?? '-',
                    'vehicle_type': vehicle['vehicle_type'] ?? '',
                    'description': vehicle['description'] ?? '',
                    'price_per_day': vehicle['price_per_day'] ?? 0,
                    'location': vehicle['location'] ?? '',
                    'owner': vehicle['owner']?['full_name'] ?? '-',
                    'service_details': vehicle['service_details'] ?? '',
                    'image_url': mainImageUrl ?? '',
                  },
                  'bookingDate':
                      booking['booking_start_date'] != null
                          ? DateTime.parse(
                            booking['booking_start_date'],
                          ).toLocal().toString().split(' ')[0]
                          : '',
                  'duration':
                      (booking['booking_start_date'] != null &&
                              booking['booking_end_date'] != null)
                          ? _calculateDuration(
                            booking['booking_start_date'],
                            booking['booking_end_date'],
                          )
                          : '',
                  'status': booking['status'] ?? '',
                },
              };
            }).toList();
      } else {
        cancellationRequests = [];
      }

      setState(() {
        _isLoadingCancellationRequests = false;
      });
    } catch (e) {
      print('Error fetching booking cancellations: $e');
      setState(() {
        _isLoadingCancellationRequests = false;
      });
    }
  }

  Future<void> _approveCancellation(
    String cancellationId,
    String bookingId,
  ) async {
    try {
      // อัพเดตสถานะ booking เป็น cancelled
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('booking_id', bookingId);

      // ดึงข้อมูล booking เพื่อหาผู้จอง (farmer_id)
      final bookingResponse =
          await supabase
              .from('bookings')
              .select('farmer_id')
              .eq('booking_id', bookingId)
              .single();

      final farmerId = bookingResponse?['farmer_id'];

      if (farmerId != null) {
        await _sendNotification(
          userId: farmerId,
          title: 'อนุมัติการยกเลิกการจอง',
          message: 'คำขอยกเลิกการจองพาหนะของคุณได้รับการอนุมัติแล้ว',
        );
      }

      // ลบแถวคำขอยกเลิก
      await supabase
          .from('bookingcancellations')
          .delete()
          .eq('cancellation_id', cancellationId);

      _showSnackBar('อนุมัติการยกเลิกการจองเรียบร้อยแล้ว');
      await _fetchCancellationRequests();
      await _fetchBookings();
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _autoApproveCancellation(
    String cancellationId,
    String bookingId,
  ) async {
    try {
      // อัพเดตสถานะ booking เป็น cancelled
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('booking_id', bookingId);

      // ดึงข้อมูล booking เพื่อหาผู้จอง (farmer_id)
      final bookingResponse =
          await supabase
              .from('bookings')
              .select('farmer_id')
              .eq('booking_id', bookingId)
              .single();

      final farmerId = bookingResponse?['farmer_id'];

      if (farmerId != null) {
        await _sendNotification(
          userId: farmerId,
          title: 'อนุมัติการยกเลิกการจองอัตโนมัติ',
          message:
              'คำขอยกเลิกการจองพาหนะของคุณได้รับการอนุมัติอัตโนมัติเนื่องจากครบกำหนด 24 ชั่วโมง',
        );
      }

      // ลบแถวคำขอยกเลิก
      await supabase
          .from('bookingcancellations')
          .delete()
          .eq('cancellation_id', cancellationId);

      print(
        'Auto-approved cancellation: $cancellationId for booking: $bookingId',
      );
    } catch (e) {
      print('Error auto-approving cancellation: $e');
    }
  }

  Future<void> _rejectCancellation(String cancellationId) async {
    try {
      // ลบแถวคำขอยกเลิก
      await supabase
          .from('bookingcancellations')
          .delete()
          .eq('cancellation_id', cancellationId);

      _showSnackBar('ปฏิเสธคำขอยกเลิกเรียบร้อยแล้ว');
      await _fetchCancellationRequests();
      await _fetchBookings(); // Refresh bookings to show buttons again
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e', backgroundColor: Colors.red);
    }
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // ฟังก์ชันแสดงรายละเอียดการจอง
  void _showBookingDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'รายละเอียดการจองพาหนะเกษตร',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Booking ID and status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'รหัสการจอง: ${booking['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: booking['statusColor'].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                booking['statusLabel'],
                                style: TextStyle(
                                  color: booking['statusColor'],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'สร้างเมื่อ: ${booking['bookingDate']}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      // Customer info
                      Text(
                        'ข้อมูลลูกค้า',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.purple.shade100,
                              child: Text(
                                (booking['customerName'] ?? '??')
                                    .toString()
                                    .split(' ')
                                    .map((e) => e.isNotEmpty ? e[0] : '')
                                    .join(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking['customerName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'User ID: ${booking['userId'] ?? '-'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    booking['customerEmail'] ?? '-',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        booking['phone']?.toString() ?? '-',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'address: ${booking['address'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Vehicle info
                      Text(
                        'ข้อมูลพาหนะ',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['vehicle']?['vehicle_name'] ??
                                  booking['vehicle']?['name'] ??
                                  '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index <
                                          (booking['vehicle']['rating'] ?? 0)
                                              .round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              booking['vehicle']['description'] ?? '-',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ราคาเช่า: ${booking['vehicle']['price_per_day']?.toString() ?? booking['vehicle']['price']?.toString() ?? '-'} บาท/วัน',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  booking['vehicle']['location'] ?? '-',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'เจ้าของ: ${booking['vehicle']['owner'] ?? '-'}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'รายละเอียดการใช้งาน: ${booking['vehicle']['service_details'] ?? '-'}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Booking details
                      Text(
                        'รายละเอียดการจอง',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'วันที่จอง',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${booking['bookingStartDate'] ?? '-'} ถึง ${booking['bookingEndDate'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'จำนวนไร่',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        booking['areaSize']?.toString() ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ช่วงเวลา',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        mapTimePeriodLabel(
                                          booking['time_period'],
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('ปิด'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
            );
          },
        );
      },
    );
  }

  Widget _buildCancellationRequestsSection() {
    if (_isLoadingCancellationRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cancellationRequests.isEmpty) {
      return const Center(child: Text('ไม่มีคำขอยกเลิกการจองใหม่'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'คำขอยกเลิกการจองใหม่ (ภายใน 24 ชั่วโมง)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cancellationRequests.length,
          itemBuilder: (context, index) {
            final request = cancellationRequests[index];
            final booking = request['booking'];
            final cancelledAt = DateTime.tryParse(request['cancelledAt'] ?? '');
            String timeLeft = '';
            Color timeLeftColor = Colors.black;

            if (cancelledAt != null) {
              final now = DateTime.now().toUtc();
              final diff = now.difference(cancelledAt);
              final totalDuration = Duration(hours: 24);
              final elapsed = now.difference(cancelledAt);
              final remaining = totalDuration - elapsed;

              final hoursLeft = remaining.inHours;
              final minutesLeft = remaining.inMinutes % 60;

              if (hoursLeft > 0) {
                timeLeft = '${hoursLeft}h ${minutesLeft}m';
                timeLeftColor = hoursLeft > 3 ? Colors.green : Colors.orange;
              } else if (hoursLeft == 0 && minutesLeft > 0) {
                timeLeft = '${minutesLeft}m';
                timeLeftColor = Colors.orange;
              } else {
                timeLeft = 'หมดเวลา';
                timeLeftColor = Colors.red;
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'คำขอยกเลิกการจอง: ${request['bookingId']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: timeLeftColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            timeLeft,
                            style: TextStyle(
                              color: timeLeftColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('ลูกค้า: ${booking['customerName']}'),
                    Text('พาหนะ: ${booking['vehicle']['name']}'),
                    Text('วันที่จอง: ${booking['bookingDate']}'),
                    Text('เหตุผล: ${request['cancelReason']}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed:
                              () => _approveCancellation(
                                request['cancellationId'],
                                request['bookingId'],
                              ),
                          child: const Text('อนุมัติ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed:
                              () => _rejectCancellation(
                                request['cancellationId'],
                              ),
                          child: const Text('ปฏิเสธ'),
                          style: OutlinedButton.styleFrom(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: Colors.green.shade700,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        _onMenuSelected(index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าหลัก'),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'การจอง',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.agriculture),
          label: 'พาหนะเกษตร',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
      ],
    );
  }

  void _onMenuSelected(int index) {
    if (index == 1) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AgriVehicleManagementPage(),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ContactAdminPage2()),
        );
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage1()),
        );
        break;
      default:
        break;
    }
  }

  // Helper function to convert UTC to Thailand time (UTC+7)
  DateTime convertUtcToThailandTime(DateTime utcTime) {
    return utcTime.add(const Duration(hours: 7));
  }

  // Helper function to format countdown time
  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Function to check if cancellation is still allowed (within 24 hours from created_at)
  bool _isCancellationAllowed(String bookingId) {
    final booking = bookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => {},
    );
    final createdAtStr = booking['created_at'] as String?;

    if (createdAtStr == null || createdAtStr.isEmpty) return false;

    final createdAtUtc = DateTime.tryParse(createdAtStr);
    if (createdAtUtc == null) return false;

    final createdAtThailand = convertUtcToThailandTime(createdAtUtc);
    final nowThailand = convertUtcToThailandTime(DateTime.now().toUtc());
    final diff = nowThailand.difference(createdAtThailand);
    return diff.inHours < 24;
  }

  // Function to get remaining time for cancellation (from created_at)
  Duration _getRemainingTime(String bookingId) {
    final booking = bookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => {},
    );
    final createdAtStr = booking['created_at'] as String?;

    if (createdAtStr == null || createdAtStr.isEmpty) return Duration.zero;

    final createdAtUtc = DateTime.tryParse(createdAtStr);
    if (createdAtUtc == null) return Duration.zero;

    final createdAtThailand = convertUtcToThailandTime(createdAtUtc);
    final nowThailand = convertUtcToThailandTime(DateTime.now().toUtc());
    final elapsed = nowThailand.difference(createdAtThailand);
    final totalDuration = const Duration(hours: 24);

    if (elapsed >= totalDuration) {
      return Duration.zero;
    }

    return totalDuration - elapsed;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (_isUserLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppSidebar(
        selectedIndex: 1, // index สำหรับ BookingPage
        onMenuSelected: _onMenuSelected,
        userName: userProfile?['full_name'] ?? 'ไม่มีชื่อ',
        userRole:
            userProfile?['user_type'] == 'renter' ? 'ผู้ให้เช่า' : 'เกษตรกร',
        userAvatarUrl: userProfile?['profile_image_url'],
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.grey),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          'การจอง',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filters section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'สถานะการจอง',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  value: selectedStatus ?? '',
                                  items: const [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text('ทั้งหมด'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'confirmed',
                                      child: Text('ยืนยันแล้ว'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('รอการยืนยัน'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cancelled',
                                      child: Text('ยกเลิก'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'completed',
                                      child: Text('เสร็จสิ้น'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'waiting_farmer_confirm',
                                      child: Text('รอชาวนายืนยัน'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      selectedStatus = val == '' ? null : val;
                                      _fetchBookings();
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'ประเภทพาหนะ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  value: selectedVehicleType ?? '',
                                  items: const [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text('ทั้งหมด'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถไถ',
                                      child: Text('รถไถ'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถดำนา',
                                      child: Text('รถดำนา'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'โดรนพ่นยา',
                                      child: Text('โดรนพ่นยา'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถเกี่ยวข้าว',
                                      child: Text('รถเกี่ยวข้าว'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถกรองข้าว',
                                      child: Text('รถกรองข้าว'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถแทรกเตอร์',
                                      child: Text('รถแทรกเตอร์'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'คนรับจ้างทำนา',
                                      child: Text('คนรับจ้างทำนา'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      selectedVehicleType =
                                          val == '' ? null : val;
                                      _fetchBookings();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    selectedStatus = null;
                                    selectedVehicleType = null;
                                    _fetchBookings();
                                  });
                                },
                                icon: const Icon(Icons.redo),
                                label: const Text('รีเซ็ต'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _fetchBookings();
                                },
                                icon: const Icon(Icons.filter_list),
                                label: const Text('กรอง'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // แสดงคำขอยกเลิกการจอง
                    _buildCancellationRequestsSection(),
                    // Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            tabs.map((tab) {
                              final isActive = activeTabValue == tab['value'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ChoiceChip(
                                  label: Text(
                                    '${tab['label']} (${tab['count']})',
                                  ),
                                  selected: isActive,
                                  onSelected: (_) {
                                    setState(() {
                                      activeTabValue = tab['value'];
                                      _fetchBookings();
                                    });
                                  },
                                  selectedColor: Colors.green.shade100,
                                  labelStyle: TextStyle(
                                    color:
                                        isActive
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                    fontWeight:
                                        isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                  backgroundColor: Colors.grey.shade200,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Booking table
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                headingRowHeight: 56,
                                dataRowHeight: 72,
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'รหัสการจอง',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ลูกค้า',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'พาหนะ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'วันที่จอง',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ระยะเวลา',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'สถานะ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'การจัดการ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows:
                                    filteredBookings.map((booking) {
                                      print(
                                        'จำนวน booking ที่แสดง: ${filteredBookings.length}',
                                      );
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(booking['id'])),
                                          DataCell(
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  booking['customerName'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  booking['customerEmail'],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              booking['vehicle']['name'] ??
                                                  booking['vehicle']['vehicle_name'] ??
                                                  '-',
                                            ),
                                          ),
                                          DataCell(
                                            Text(booking['bookingDate']),
                                          ),
                                          DataCell(Text(booking['duration'])),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: booking['statusColor']
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    booking['statusLabel'],
                                                    style: TextStyle(
                                                      color:
                                                          booking['statusColor'],
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (booking['status'] ==
                                                      'confirmed') ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 20,
                                                    ),
                                                  ] else if (booking['status'] ==
                                                      'pending') ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.access_time,
                                                      color: Colors.orange,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_red_eye,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed:
                                                      () => _showBookingDetails(
                                                        booking,
                                                      ),
                                                  tooltip: 'ดูรายละเอียด',
                                                ),
                                                // Check if there's a cancellation request for this booking
                                                if (cancellationRequests.any(
                                                  (request) =>
                                                      request['bookingId'] ==
                                                      booking['id'],
                                                )) ...[
                                                  // If there is, don't show the buttons
                                                ]
                                                // สำหรับ booking ที่อยู่ในสถานะ pending
                                                else if (booking['status'] ==
                                                    'pending') ...[
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                    ),
                                                    onPressed:
                                                        () => _confirmBooking(
                                                          booking['id'],
                                                        ),
                                                    tooltip: 'ยืนยันการจอง',
                                                  ),
                                                  // แสดงเวลานับถอยหลังถาวร
                                                  if (_isCancellationAllowed(
                                                    booking['id'],
                                                  )) ...[
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            _formatCountdown(
                                                              _getRemainingTime(
                                                                booking['id'],
                                                              ),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.cancel,
                                                              color: Colors.red,
                                                            ),
                                                            onPressed:
                                                                () => _showCancelReasonDialog(
                                                                  booking['id'],
                                                                ),
                                                            tooltip:
                                                                'ยกเลิกการจอง',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    // เมื่อเวลาหมด แสดงปุ่มยกเลิกที่ถูกปิดใช้งาน
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.cancel,
                                                        color: Colors.grey,
                                                      ),
                                                      onPressed: null,
                                                      tooltip:
                                                          'หมดเวลาการยกเลิก',
                                                    ),
                                                  ],
                                                ] else if (booking['status'] ==
                                                    'confirmed') ...[
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.check,
                                                      color: Colors.purple,
                                                    ),
                                                    onPressed:
                                                        () => _markAsComplete(
                                                          booking['id'],
                                                          booking['userId'],
                                                        ),
                                                    tooltip: 'แจ้งเสร็จสิ้นงาน',
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      bottomNavigationBar:
          MediaQuery.of(context).size.width < 768
              ? _buildMobileBottomNav()
              : null,
    );
  }

  // ฟังก์ชันยืนยันการจอง
  Future<void> _confirmBooking(String bookingId) async {
    try {
      // อัพเดตสถานะ booking เป็น confirmed
      await supabase
          .from('bookings')
          .update({'status': 'confirmed'})
          .eq('booking_id', bookingId);

      // ดึงข้อมูล booking เพื่อหาผู้จอง (farmer_id)
      final bookingResponse =
          await supabase
              .from('bookings')
              .select('farmer_id')
              .eq('booking_id', bookingId)
              .single();

      final farmerId = bookingResponse?['farmer_id'];

      if (farmerId != null) {
        await _sendNotification(
          userId: farmerId,
          title: 'ยืนยันการจองพาหนะ',
          message: 'การจองพาหนะของคุณได้รับการยืนยันแล้ว',
        );
      }

      _showSnackBar('ยืนยันการจองเรียบร้อยแล้ว');
      _fetchBookings();
    } catch (e) {
      _showSnackBar(
        'เกิดข้อผิดพลาดในการยืนยัน: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _markAsComplete(String bookingId, String farmerId) async {
    try {
      // อัปเดตสถานะ booking เป็น waiting_farmer_confirm
      await supabase
          .from('bookings')
          .update({'status': 'waiting_farmer_confirm'})
          .eq('booking_id', bookingId);

      // ส่ง notification ไปหาชาวนา
      await _sendNotification(
        userId: farmerId,
        title: 'แจ้งเสร็จสิ้นงาน',
        message:
            'ผู้ให้เช่าแจ้งว่าได้ดำเนินการเสร็จสิ้นงานแล้ว กรุณาตรวจสอบและยืนยัน',
      );

      _showSnackBar('แจ้งเสร็จสิ้นงานเรียบร้อยแล้ว');
      _fetchBookings();
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _showCancelReasonDialog(String bookingId) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ระบุเหตุผลการยกเลิก'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'กรุณาระบุเหตุผลการยกเลิก',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  // แจ้งเตือนถ้าไม่กรอกเหตุผล
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กรุณาระบุเหตุผลก่อนยกเลิก')),
                  );
                  return;
                }
                Navigator.of(context).pop(reasonController.text.trim());
              },
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _cancelBookingWithReason(bookingId, result);
    }
  }

  // ฟังก์ชันยกเลิกการจอง
  Future<void> _cancelBookingWithReason(String bookingId, String reason) async {
    try {
      // ดึง user_type ของผู้ใช้ปัจจุบัน
      final currentUserId = supabase.auth.currentUser?.id;
      String? userType;

      if (currentUserId != null) {
        final userResponse =
            await supabase
                .from('users')
                .select('user_type')
                .eq('user_id', currentUserId)
                .single();

        userType = userResponse?['user_type'];
      }

      // อัพเดตสถานะ booking เป็น cancelled
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('booking_id', bookingId);

      // บันทึกเหตุผลการยกเลิกพร้อม user_type แทน cancelled_by
      await supabase.from('bookingcancellations').insert({
        'booking_id': bookingId,
        'cancel_reason': reason,
        'cancelled_by': userType ?? 'unknown',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      });

      // ดึงข้อมูล booking เพื่อหาผู้จอง (farmer_id)
      final bookingResponse =
          await supabase
              .from('bookings')
              .select('farmer_id')
              .eq('booking_id', bookingId)
              .single();

      final farmerId = bookingResponse?['farmer_id'];

      if (farmerId != null) {
        await _sendNotification(
          userId: farmerId,
          title: 'ยกเลิกการจองพาหนะ',
          message: 'การจองพาหนะของคุณถูกยกเลิกแล้ว เหตุผล: $reason',
        );
      }

      _showSnackBar('ยกเลิกการจองเรียบร้อยแล้ว');
      _fetchBookings();
    } catch (e) {
      _showSnackBar(
        'เกิดข้อผิดพลาดในการยกเลิก: $e',
        backgroundColor: Colors.red,
      );
    }
  }
}
