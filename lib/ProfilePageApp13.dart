import 'package:appfinal/EditProfilePage17.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:appfinal/BookingHistoryPage9.dart';
import 'package:appfinal/homepage6.2.dart';

class ProfilePageApp extends StatefulWidget {
  @override
  _ProfilePageAppState createState() => _ProfilePageAppState();
}

class _ProfilePageAppState extends State<ProfilePageApp> {
  final supabase = Supabase.instance.client;

  final Color mainGreen = const Color(0xFF2E6B3B);
  final Color mainYellow = const Color(0xFFF7D58A);

  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> bookingHistoryList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAllUserData();
  }

  Future<void> fetchAllUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final userId = user.id;

    try {
      // ดึงข้อมูลโปรไฟล์
      final profileResponse =
          await supabase
              .from('users')
              .select(
                'user_id, full_name, email, phone, address, profile_image_url',
              )
              .eq('user_id', userId)
              .single();

      // ดึงข้อมูล booking ปกติ
      final bookingsResponse = await supabase
          .from('bookings')
          .select('''
            booking_id,
            vehicle_id,
            booking_start_date,
            booking_end_date,
            time_period,
            status,
            created_at,
            area_size,
            renter_id,
            vehicles!fk_bookings_vehicle_id (
              vehicle_name,location,
              vehicleimages!fk_vehicleimages_vehicle (is_main_image, image_url),
              users!fk_vehicles_renter (full_name)
            )
          ''')
          .eq('farmer_id', userId)
          .order('created_at', ascending: false);

      // ใช้ข้อมูล bookingsResponse เป็น bookingHistoryList ด้วย
      List<Map<String, dynamic>> bookingHistoryList = [];
      if (bookingsResponse != null && bookingsResponse is List) {
        bookingHistoryList = List<Map<String, dynamic>>.from(bookingsResponse);
      }

      setState(() {
        profileData = profileResponse;
        bookings = List<Map<String, dynamic>>.from(bookingsResponse);
        this.bookingHistoryList = bookingHistoryList;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profileData == null) {
      return Scaffold(body: Center(child: Text('ไม่พบข้อมูลผู้ใช้')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileAppBar(mainGreen: mainGreen),
            ProfileHeaderDynamic(
              mainGreen: mainGreen,
              mainYellow: mainYellow,
              profileData: profileData!,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: 'ข้อมูลการจอง', color: mainGreen),
                    const SizedBox(height: 8),
                    bookings.isNotEmpty
                        ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 1, // แสดงแค่รายการเดียวล่าสุด
                          itemBuilder: (context, index) {
                            final booking = bookingHistoryList[index];
                            // สร้างข้อมูล bookingData สำหรับ BookingCardFullDynamic
                            final bookingData = {
                              'status': booking['status'] ?? 'unknown',
                              'booking_start_date':
                                  booking['booking_start_date'] ?? '',
                              'booking_end_date':
                                  booking['booking_end_date'] ?? '',
                              'time_period': booking['time_period'] ?? '',
                              'area_size':
                                  booking['area_size']?.toString() ?? '',
                              'fk_bookings_renter': {
                                'full_name':
                                    booking['vehicles']?['users']?['full_name'] ??
                                    'ไม่ทราบผู้ให้เช่า',
                                'location':
                                    booking['vehicles']?['location'] ?? '',
                              },
                              'fk_bookings_vehicle': {
                                'vehicle_name':
                                    booking['vehicles']?['vehicle_name'] ??
                                    'ไม่ทราบชื่อพาหนะ',
                                'vehicleimages':
                                    booking['vehicles']?['vehicleimages'] ?? [],
                              },
                            };
                            return BookingCardFullDynamic(
                              mainGreen: mainGreen,
                              mainYellow: mainYellow,
                              bookingData: bookingData,
                            );
                          },
                        )
                        : const Text('ไม่มีข้อมูลการจอง'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SectionTitle(title: 'ประวัติการจอง', color: mainGreen),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainYellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BookingHistoryPage(
                                      farmerId: profileData!['user_id'],
                                    ),
                              ),
                            );
                          },
                          child: const Text('ดูทั้งหมด'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    bookingHistoryList.isNotEmpty
                        ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: bookingHistoryList.length,
                          itemBuilder: (context, index) {
                            final booking = bookingHistoryList[index];

                            // สร้างข้อมูล bookingData สำหรับ BookingCardFullDynamic
                            final bookingData = {
                              'status': booking['status'] ?? 'unknown',
                              'booking_start_date':
                                  booking['booking_start_date'] ?? '',
                              'booking_end_date':
                                  booking['booking_end_date'] ?? '',
                              'time_period': booking['time_period'] ?? '',
                              'area_size':
                                  booking['area_size']?.toString() ?? '',
                              'fk_bookings_renter': {
                                'full_name':
                                    booking['vehicles']?['users']?['full_name'] ??
                                    'ไม่ทราบผู้ให้เช่า',
                                'location':
                                    booking['vehicles']?['location'] ??
                                    '', // <--- ตรงนี้
                              },
                              'fk_bookings_vehicle': {
                                'vehicle_name':
                                    booking['vehicles']?['vehicle_name'] ??
                                    'ไม่ทราบชื่อพาหนะ',
                                'vehicleimages':
                                    booking['vehicles']?['vehicleimages'] ?? [],
                              },
                            };

                            return BookingCardFullDynamic(
                              mainGreen: mainGreen,
                              mainYellow: mainYellow,
                              bookingData: bookingData,
                            );
                          },
                        )
                        : const Text('ไม่มีประวัติการจอง'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileAppBar extends StatelessWidget {
  final Color mainGreen;
  const ProfileAppBar({required this.mainGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mainGreen,
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomePage6()),
                );
              },
            ),
          ),
          const Center(
            child: Text(
              'โปรไฟล์',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.normal,
                fontFamily: 'Prompt',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileHeaderDynamic extends StatelessWidget {
  final Color mainGreen;
  final Color mainYellow;
  final Map<String, dynamic> profileData;

  const ProfileHeaderDynamic({
    required this.mainGreen,
    required this.mainYellow,
    required this.profileData,
  });

  @override
  Widget build(BuildContext context) {
    bool isNarrow = MediaQuery.of(context).size.width < 700;
    final profileImagePath = profileData['profile_image_url'] as String?;
    return Container(
      width: double.infinity,
      color: mainGreen,
      padding: const EdgeInsets.only(top: 36, bottom: 36, left: 20, right: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child:
              isNarrow
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfilePicture(
                        isLarge: false,
                        imagePath: profileImagePath,
                      ),
                      const SizedBox(height: 20),
                      ProfileInfoBlockDynamic(
                        mainYellow: mainYellow,
                        profileData: profileData,
                        isNarrow: true,
                      ),
                    ],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfilePicture(
                        isLarge: true,
                        imagePath: profileImagePath,
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: ProfileInfoBlockDynamic(
                          mainYellow: mainYellow,
                          profileData: profileData,
                          isNarrow: false,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class ProfilePicture extends StatelessWidget {
  final bool isLarge;
  final String? imagePath;

  const ProfilePicture({this.isLarge = false, this.imagePath});

  @override
  Widget build(BuildContext context) {
    final double size = isLarge ? 180 : 140;
    final supabase = Supabase.instance.client;

    String? imageUrl;
    if (imagePath != null && imagePath!.isNotEmpty) {
      imageUrl = supabase.storage.from('profile').getPublicUrl(imagePath!);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD9D9D9),
        border: Border.all(color: Colors.white, width: 6),
      ),
      child: ClipOval(
        child:
            imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        'รูป',
                        style: TextStyle(color: Colors.grey, fontSize: 28),
                      ),
                    );
                  },
                )
                : const Center(
                  child: Text(
                    'รูป',
                    style: TextStyle(color: Colors.grey, fontSize: 28),
                  ),
                ),
      ),
    );
  }
}

class ProfileInfoBlockDynamic extends StatelessWidget {
  final Color mainYellow;
  final Map<String, dynamic> profileData;
  final bool isNarrow;

  const ProfileInfoBlockDynamic({
    required this.mainYellow,
    required this.profileData,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, top: 8, right: 0, bottom: 8),
      child: Column(
        crossAxisAlignment:
            isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            profileData['full_name'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          ProfileInfoText(label: 'UserID', value: profileData['user_id'] ?? ''),
          ProfileInfoText(label: 'อีเมล', value: profileData['email'] ?? ''),
          ProfileInfoText(
            label: 'ที่อยู่',
            value: profileData['address'] ?? '',
          ),
          ProfileInfoText(
            label: 'เบอร์โทรศัพท์',
            value: profileData['phone'] ?? '',
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditProfilePage(profileData: profileData),
                  ),
                );
              },
              child: const Text('แก้ไขโปรไฟล์'),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoText extends StatelessWidget {
  final String label;
  final String value;
  const ProfileInfoText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          text: '$label : ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.normal,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
    );
  }
}

class BookingCardFullDynamic extends StatelessWidget {
  final Color mainGreen;
  final Color mainYellow;
  final Map<String, dynamic> bookingData;

  const BookingCardFullDynamic({
    required this.mainGreen,
    required this.mainYellow,
    required this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    String status = bookingData['status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;
    Color statusTextColor;

    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFF7B733);
        statusIcon = Icons.info_outline;
        statusTextColor = const Color(0xFFF7B733);
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusTextColor = Colors.blue;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTextColor = Colors.red;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTextColor = Colors.green;
        break;
      case 'waiting_farmer_confirm': // <--- เพิ่มตรงนี้
        statusColor = const Color.fromARGB(255, 216, 118, 234);
        statusIcon = Icons.hourglass_bottom;
        statusTextColor = const Color.fromARGB(255, 216, 118, 234);
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusTextColor = Colors.grey;
    }

    return BookingCardFull(
      mainGreen: mainGreen,
      mainYellow: mainYellow,
      status: status,
      statusColor: statusColor,
      statusIcon: statusIcon,
      statusTextColor: statusTextColor,
      bookingData: bookingData,
    );
  }
}

class BookingCardFull extends StatelessWidget {
  final Color mainGreen;
  final Color mainYellow;
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final Color statusTextColor;
  final Map<String, dynamic> bookingData;

  String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'waiting_farmer_confirm': // <--- เพิ่มตรงนี้
        return 'รอชาวนายืนยัน';
      default:
        return 'สถานะไม่ทราบ';
    }
  }

  String formatDateThai(String dateStr) {
    if (dateStr.isEmpty) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  String getTimePeriodLabel(String code) {
    switch (code) {
      case 'morning':
        return 'เช้า';
      case 'afternoon':
        return 'บ่าย';
      case 'full_day':
        return 'ทั้งวัน';
      default:
        return 'ไม่มีข้อมูล';
    }
  }

  const BookingCardFull({
    required this.mainGreen,
    required this.mainYellow,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.statusTextColor,
    required this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width;
    bool isNarrow = maxWidth < 800;

    final bookingStartDate = bookingData['booking_start_date'] ?? '';
    final bookingEndDate = bookingData['booking_end_date'] ?? '';
    final timePeriod = bookingData['time_period'] ?? '';
    final areaSize = bookingData['area_size']?.toString() ?? '';

    // แปลงวันที่เป็นรูปแบบไทย
    final bookingStartDateFormatted = formatDateThai(bookingStartDate);
    final bookingEndDateFormatted = formatDateThai(bookingEndDate);

    // แปลงสถานะเป็นภาษาไทย
    final displayStatus = getStatusLabel(status);
    final timePeriodRaw = bookingData['time_period'] ?? '';
    final timePeriodLabel = getTimePeriodLabel(timePeriodRaw);

    // ข้อมูลผู้ให้เช่า
    final renter = bookingData['fk_bookings_renter'] ?? {};
    final renterName = renter['full_name'] ?? 'ไม่ทราบชื่อผู้ให้เช่า';
    final renterLocation = renter['location'] ?? '';

    // ข้อมูลยานพาหนะ
    final vehicle = bookingData['fk_bookings_vehicle'] ?? {};
    final vehicleName = vehicle['vehicle_name'] ?? 'ไม่ทราบชื่อพาหนะ';

    // รูปภาพหลักของยานพาหนะ
    final List vehicleImages = vehicle['vehicleimages'] ?? [];
    String? mainImageUrl;
    for (var img in vehicleImages) {
      if (img['is_main_image'] == true) {
        mainImageUrl = img['image_url'];
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child:
          isNarrow
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, isNarrow: true),
                  const SizedBox(height: 12),
                  _buildImage(mainImageUrl),
                  const SizedBox(height: 12),
                  _buildStatus(
                    context,
                    isNarrow: true,
                    displayStatus: displayStatus,
                  ),
                  const SizedBox(height: 16),
                  BookingDetailAll(
                    mainGreen: mainGreen,
                    bookingStartDate:
                        bookingStartDateFormatted, // ใช้วันที่แปลงแล้ว
                    bookingEndDate:
                        bookingEndDateFormatted, // ใช้วันที่แปลงแล้ว
                    timePeriod: timePeriodLabel,
                    areaSize: areaSize,
                    renterName: renterName,
                    renterLocation: renterLocation,
                    vehicleName: vehicleName,
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [_buildImage(mainImageUrl)]),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, isNarrow: false),
                        const SizedBox(height: 16),
                        BookingDetailAll(
                          mainGreen: mainGreen,
                          bookingStartDate:
                              bookingStartDateFormatted, // ใช้วันที่แปลงแล้ว
                          bookingEndDate:
                              bookingEndDateFormatted, // ใช้วันที่แปลงแล้ว
                          timePeriod: timePeriodLabel,
                          areaSize: areaSize,
                          renterName: renterName,
                          renterLocation: renterLocation,
                          vehicleName: vehicleName,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatus(
                        context,
                        isNarrow: false,
                        displayStatus: displayStatus,
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isNarrow}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'ข้อมูลการจอง',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: mainGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          height: 130,
          color: Colors.grey[300],
          child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        width: 180,
        height: 130,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 180,
            height: 130,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildStatus(
    BuildContext context, {
    required bool isNarrow,
    required String displayStatus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'สถานะ : ',
            style: TextStyle(
              color: statusTextColor,
              fontWeight: FontWeight.bold,
              fontSize: isNarrow ? 16 : 18,
            ),
          ),
          Flexible(
            child: Text(
              displayStatus,
              style: TextStyle(
                color: statusTextColor,
                fontWeight: FontWeight.bold,
                fontSize: isNarrow ? 16 : 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(statusIcon, color: statusTextColor, size: 22),
        ],
      ),
    );
  }
}

class BookingDetailAll extends StatelessWidget {
  final Color mainGreen;
  final String bookingStartDate;
  final String bookingEndDate;
  final String timePeriod;
  final String areaSize;
  final String renterName;
  final String renterLocation;
  final String vehicleName;

  const BookingDetailAll({
    required this.mainGreen,
    required this.bookingStartDate,
    required this.bookingEndDate,
    required this.timePeriod,
    required this.areaSize,
    required this.renterName,
    required this.renterLocation,
    required this.vehicleName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoText('ผู้ให้เช่า', renterName),
        _infoText('สถานที่ให้บริการ', renterLocation),
        _infoText('ชื่อพาหนะ', vehicleName),
        const SizedBox(height: 12),
        _infoText('วันที่เริ่มต้น', bookingStartDate),
        _infoText('วันที่สิ้นสุด', bookingEndDate),
        _infoText('ขนาดพื้นที่', areaSize),
      ],
    );
  }

  Widget _infoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: TextStyle(
              color: mainGreen,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
