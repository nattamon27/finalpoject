import 'dart:async';
import 'package:appfinal/ServiceDetailPage8.dart';
import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:appfinal/CancelBookingPage10.dart';
import 'package:appfinal/Ratingdialog12.dart';
import 'package:appfinal/ServiceListPage7.dart';

class BookingHistoryPage extends StatefulWidget {
  final String farmerId; // user_id ของ farmer ที่ล็อกอิน

  const BookingHistoryPage({Key? key, required this.farmerId})
    : super(key: key);

  @override
  _BookingHistoryPageState createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;
  String? errorMessage;

  Timer? _timer;

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
      case 'waiting_farmer_confirm':
        return 'รอชาวนายืนยันเสร็จสิ้นงาน';
      default:
        return 'สถานะไม่ทราบ';
    }
  }

  @override
  void initState() {
    super.initState();
    fetchBookingHistory();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {}); // อัปเดต UI ทุกวินาที
      }
    });
  }

  // ฟังก์ชันช่วยแปลงค่า null เป็น String ปลอดภัย
  String safeString(dynamic value, {String defaultValue = '-'}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  // ฟังก์ชันช่วยจัดการลบหรือแทนที่ตัวอักษรในสตริงวันที่ให้ถูกต้องก่อนแปลง
  String sanitizeDateString(String dateStr) {
    if (dateStr.endsWith('Z') && dateStr.contains('+00:00')) {
      // ลบ 'Z' ทิ้ง
      return dateStr.replaceAll('Z', '');
    } else if (dateStr.endsWith('Z') && !dateStr.contains('+00:00')) {
      // แทนที่ 'Z' ด้วย '+00:00'
      return dateStr.replaceAll('Z', '+00:00');
    }
    return dateStr;
  }

  // ฟังก์ชันแปลงวันที่เป็นสตริงในรูปแบบ วัน/เดือน/ปี
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';

    String sanitizedDateStr = dateStr;
    if (dateStr.endsWith('Z') && dateStr.contains('+00:00')) {
      sanitizedDateStr = dateStr.replaceAll('Z', '');
    } else if (dateStr.endsWith('Z') && !dateStr.contains('+00:00')) {
      sanitizedDateStr = dateStr.replaceAll('Z', '+00:00');
    }

    DateTime? date;
    try {
      date = DateTime.parse(sanitizedDateStr).toLocal();
    } catch (e) {
      return '-';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // ฟังก์ชันแปลงช่วงเวลาเป็นภาษาไทย
  String getTimePeriodLabel(String? code) {
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

  // ฟังก์ชันคำนวณเวลานับถอยหลัง 48 ชั่วโมงจาก createdAt
  Duration _timeLeft(String createdAtStr) {
    if (createdAtStr.isEmpty) return Duration.zero;

    String sanitizedDateStr = createdAtStr;
    if (createdAtStr.endsWith('Z') && createdAtStr.contains('+00:00')) {
      sanitizedDateStr = createdAtStr.replaceAll('Z', '');
    } else if (createdAtStr.endsWith('Z') && !createdAtStr.contains('+00:00')) {
      sanitizedDateStr = createdAtStr.replaceAll('Z', '+00:00');
    }

    final createdAt = DateTime.parse(sanitizedDateStr).toLocal();
    final nowLocal = DateTime.now();
    final deadline = createdAt.add(const Duration(hours: 48));
    final diff = deadline.difference(nowLocal);

    return diff.isNegative ? Duration.zero : diff;
  }

  // ฟังก์ชันคำนวณเวลานับถอยหลัง 24 ชั่วโมงจาก createdAt
  Duration _editTimeLeft(String createdAtStr) {
    if (createdAtStr.isEmpty) return Duration.zero;

    String sanitizedDateStr = createdAtStr;
    if (createdAtStr.endsWith('Z') && createdAtStr.contains('+00:00')) {
      sanitizedDateStr = createdAtStr.replaceAll('Z', '');
    } else if (createdAtStr.endsWith('Z') && !createdAtStr.contains('+00:00')) {
      sanitizedDateStr = createdAtStr.replaceAll('Z', '+00:00');
    }

    final createdAt = DateTime.parse(sanitizedDateStr).toLocal();
    final nowLocal = DateTime.now();
    final deadline = createdAt.add(const Duration(hours: 24));
    final diff = deadline.difference(nowLocal);

    return diff.isNegative ? Duration.zero : diff;
  }

  // ฟังก์ชันแปลง Duration เป็น String HH:mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> fetchBookingHistory() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await supabase
          .from('bookings')
          .select('''
          booking_id,
          booking_start_date,
          booking_end_date,
          status,
          has_reviewed,
          created_at,
          updated_at,
          area_size,
          time_period,
          renter_id,
          vehicles!bookings_vehicle_id_fkey (
            vehicle_id,
            vehicle_name,
            vehicle_type,
            price_per_day,
            location,
            status,
            service_capacity,
            service_details,
            is_available,
            vehicleimages!fk_vehicleimages_vehicle (
              image_url,
              is_main_image
            ),
            users!fk_vehicles_renter (
              full_name,
              user_id
            )
          )
        ''')
          .eq('farmer_id', widget.farmerId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      if (data == null) {
        setState(() {
          errorMessage = 'ไม่พบข้อมูล';
          isLoading = false;
        });
        return;
      }

      if (data is! List) {
        setState(() {
          errorMessage = 'ข้อมูลไม่ถูกต้อง';
          isLoading = false;
        });
        return;
      }

      // ตรวจสอบสถานะ waiting_farmer_confirm และเวลานับถอยหลัง 24 ชม.
      for (var item in data) {
        final status = item['status']?.toString() ?? '';
        final createdAtStr = item['created_at']?.toString() ?? '';
        if (status == 'waiting_farmer_confirm' && createdAtStr.isNotEmpty) {
          final timeLeft = _editTimeLeft(createdAtStr);
          if (timeLeft == Duration.zero) {
            // อัปเดตสถานะเป็น completed อัตโนมัติ
            await supabase
                .from('bookings')
                .update({'status': 'completed'})
                .eq('booking_id', item['booking_id']);
          }
        }
      }

      // โหลดข้อมูลใหม่หลังอัปเดตสถานะ
      final updatedData = await supabase
          .from('bookings')
          .select('''
          booking_id,
          booking_start_date,
          booking_end_date,
          status,
          has_reviewed,
          created_at,
          updated_at,
          area_size,
          time_period,
          renter_id,
          vehicles!bookings_vehicle_id_fkey (
            vehicle_id,
            vehicle_name,
            vehicle_type,
            price_per_day,
            location,
            status,
            service_capacity,
            service_details,
            is_available,
            vehicleimages!fk_vehicleimages_vehicle (
              image_url,
              is_main_image
            ),
            users!fk_vehicles_renter (
              full_name,
              user_id
            )
          )
        ''')
          .eq('farmer_id', widget.farmerId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      final List<Map<String, dynamic>> loadedBookings =
          (updatedData as List)
              .map<Map<String, dynamic>>((item) {
                final vehicleRaw = item['vehicles'];
                if (vehicleRaw == null) {
                  // ข้าม booking ที่ไม่มีข้อมูลรถ
                  return {};
                }

                // แปลง vehicleRaw ให้เป็น Map<String, dynamic>
                final Map<String, dynamic> vehicle =
                    vehicleRaw is Map<String, dynamic>
                        ? vehicleRaw
                        : Map<String, dynamic>.from(vehicleRaw as Map);

                // แปลง vehicleimages ให้เป็น List<Map<String, dynamic>>
                final imagesRaw =
                    vehicle['vehicleimages'] as List<dynamic>? ?? [];
                final List<Map<String, dynamic>> images =
                    imagesRaw
                        .map(
                          (img) =>
                              img is Map<String, dynamic>
                                  ? img
                                  : Map<String, dynamic>.from(img as Map),
                        )
                        .toList();

                final mainImage = images.firstWhere(
                  (img) => img['is_main_image'] == true,
                  orElse:
                      () => images.isNotEmpty ? images[0] : <String, dynamic>{},
                );

                final providerName =
                    vehicle['users'] != null
                        ? (vehicle['users']['full_name'] ??
                            'ไม่ทราบชื่อผู้ให้บริการ')
                        : 'ไม่ทราบชื่อผู้ให้บริการ';

                final createdAtStr = item['created_at']?.toString() ?? '';

                return {
                  "bookingId": item['booking_id']?.toString() ?? '',
                  "renter_id": item['renter_id'],
                  "booking_start_date": item['booking_start_date'],
                  "booking_end_date": item['booking_end_date'],
                  "bookingDate":
                      '${_formatDate(item['booking_start_date']?.toString())} - ${_formatDate(item['booking_end_date']?.toString())}',
                  "status": item['status']?.toString() ?? 'รอดำเนินการ',
                  "hasReviewed": item['has_reviewed'] ?? false,
                  "vehicleName": vehicle['vehicle_name'] ?? 'ไม่ระบุชื่อ',
                  "vehicleType": vehicle['vehicle_type'] ?? '',
                  "vehicleCount": '${vehicle['service_capacity'] ?? '1'} คัน',
                  "pricePerDay": vehicle['price_per_day']?.toString() ?? '-',
                  "location": vehicle['location'] ?? '',
                  "provider": providerName,
                  "imageUrl":
                      mainImage != null ? mainImage['image_url'] ?? '' : '',
                  "isAvailable": vehicle['is_available'] ?? false,
                  "createdAt": createdAtStr,
                  "updatedAt": item['updated_at']?.toString() ?? '',
                  "raiAmount": item['area_size']?.toString() ?? '',
                  "serviceDetail": vehicle['service_details'] ?? '',
                  "workTime": getTimePeriodLabel(
                    item['time_period']?.toString(),
                  ),
                  "vehicles": {
                    ...vehicle,
                    "vehicleimages":
                        images, // ให้แน่ใจว่าเป็น List<Map<String, dynamic>>
                    "renter_id": item['renter_id'], // เพิ่ม renter_id เข้าไป
                  },
                  "time_period": item['time_period']?.toString() ?? '',
                };
              })
              .where(
                (e) =>
                    e != null && (e['bookingId'] ?? '').toString().isNotEmpty,
              )
              .cast<Map<String, dynamic>>()
              .toList();

      if (!mounted) return;
      setState(() {
        bookings = loadedBookings;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3e6b47);
    const accentColor = Color(0xFFf0ad4e);
    const lightGray = Color(0xFFf0f0f0);
    const borderRadius = 10.0;

    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          'ประวัติการจอง',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text('เกิดข้อผิดพลาด: $errorMessage'))
              : bookings.isEmpty
              ? const Center(child: Text('ไม่มีประวัติการจอง'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final booking = bookings[index];

                  final imageUrl = safeString(booking["imageUrl"]);
                  Widget imageWidget;
                  if (imageUrl.isNotEmpty) {
                    imageWidget = Image.network(
                      imageUrl,
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                    );
                  } else {
                    imageWidget = Container(
                      width: 100,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  }

                  final createdAtStr = booking['createdAt'] as String? ?? '';
                  final timeLeft = _timeLeft(createdAtStr);
                  final editTimeLeft = _editTimeLeft(createdAtStr);
                  final hasReviewed = booking['hasReviewed'] == true;

                  final status = safeString(booking["status"]);

                  // ตัวแปรสำหรับซ่อนปุ่มและบล็อกแก้ไข/ยกเลิก
                  final isInactiveForEditCancel =
                      status == 'cancelled' ||
                      status == 'completed' ||
                      status == 'confirmed';

                  // ตัวแปรสำหรับแสดงข้อความสถานะ (ยังคงแสดง "ยืนยันแล้ว" ตามปกติ)
                  final statusLabel = getStatusLabel(status);

                  // แสดงเวลานับถอยหลังเป็นคงที่เมื่อสถานะเป็น confirmed
                  final cancelEditDeadline =
                      isInactiveForEditCancel
                          ? 'หมดเวลา'
                          : (timeLeft > Duration.zero
                              ? _formatDuration(timeLeft)
                              : 'หมดเวลา');

                  // กำหนดสิทธิ์แก้ไขและยกเลิก
                  final canEdit =
                      status == 'waiting_farmer_confirm'
                          ? false
                          : !isInactiveForEditCancel &&
                              editTimeLeft > Duration.zero;
                  final canCancel =
                      status == 'waiting_farmer_confirm'
                          ? false
                          : !isInactiveForEditCancel &&
                              timeLeft > Duration.zero;
                  final canConfirmComplete = status == 'waiting_farmer_confirm';
                  final canRate = status == 'completed' && !hasReviewed;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: imageWidget,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      safeString(
                                        booking["vehicleName"],
                                        defaultValue: 'ไม่ระบุชื่อ',
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        Icon(
                                          Icons.star_half,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      safeString(
                                            booking["createdAt"],
                                          ).isNotEmpty
                                          ? 'จองเมื่อ: ${_formatDate(safeString(booking["createdAt"]))}'
                                          : 'จองเมื่อ: -',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFEEEEEE)),
                              bottom: BorderSide(color: Color(0xFFEEEEEE)),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Info
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ผู้ให้เช่า',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        safeString(booking["provider"]),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),

                                      const SizedBox(height: 15),
                                      const Text(
                                        'สถานที่ให้บริการ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        safeString(booking["location"]),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Status
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: const Icon(
                                              Icons.access_time,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'สถานะ: $statusLabel',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'ยกเลิกแก้ไขข้อมูลภายใน:',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 5,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: lightGray,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  status ==
                                                          'waiting_farmer_confirm'
                                                      ? _formatDuration(
                                                        editTimeLeft,
                                                      )
                                                      : cancelEditDeadline,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          Row(
                                            children: [
                                              if (canEdit)
                                                _buildActionButton(
                                                  label: 'แก้ไขการจอง',
                                                  onPressed: () async {
                                                    final vehicleData =
                                                        booking['vehicles'];
                                                    if (vehicleData == null) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'ไม่พบข้อมูลรถสำหรับการแก้ไข',
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    final result = await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (
                                                              context,
                                                            ) => ServiceDetailPage(
                                                              vehicle:
                                                                  vehicleData,
                                                              dateRange: DateTimeRange(
                                                                start: DateTime.parse(
                                                                  booking['booking_start_date'],
                                                                ),
                                                                end: DateTime.parse(
                                                                  booking['booking_end_date'],
                                                                ),
                                                              ),
                                                              rai:
                                                                  booking['raiAmount']
                                                                      .toString(),
                                                              userId:
                                                                  widget
                                                                      .farmerId,
                                                              serviceTime:
                                                                  booking['time_period'],
                                                              oldBookingId:
                                                                  booking['bookingId'],
                                                            ),
                                                      ),
                                                    );
                                                    if (result == true) {
                                                      fetchBookingHistory();
                                                    }
                                                  },
                                                  backgroundColor: const Color(
                                                    0xFFF7B733,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                ),
                                              if (canCancel)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 10,
                                                      ),
                                                  child: _buildActionButton(
                                                    label: 'ยกเลิกการจอง',
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (context) =>
                                                                  CancelBookingPage(
                                                                    bookingData:
                                                                        booking,
                                                                  ),
                                                        ),
                                                      );
                                                    },
                                                    backgroundColor:
                                                        Colors.red[700],
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                ),
                                              if (canConfirmComplete)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 10,
                                                      ),
                                                  child: _buildActionButton(
                                                    label: 'ยืนยันเสร็จสิ้นงาน',
                                                    onPressed: () async {
                                                      final bookingId =
                                                          booking['bookingId'];
                                                      await supabase
                                                          .from('bookings')
                                                          .update({
                                                            'status':
                                                                'completed',
                                                          })
                                                          .eq(
                                                            'booking_id',
                                                            bookingId,
                                                          );
                                                      await fetchBookingHistory();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'ยืนยันเสร็จสิ้นงานเรียบร้อย',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    backgroundColor:
                                                        Colors.green[700],
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (!canEdit &&
                                              !isInactiveForEditCancel &&
                                              status !=
                                                  'waiting_farmer_confirm')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                'หมดเวลาแก้ไขการจอง (24 ชั่วโมงหลังจอง)',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // รายละเอียดการจอง
                        Container(
                          width: double.infinity,
                          color: lightGray,
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 15,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text(
                                    'รายละเอียดการจอง',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 15,
                                runSpacing: 15,
                                children: [
                                  _buildDetailItem(
                                    label: 'ประเภทพาหนะ',
                                    value: safeString(booking["vehicleType"]),
                                  ),
                                  _buildDetailItem(
                                    label: 'จำนวนไร่',
                                    value: safeString(booking["raiAmount"]),
                                  ),
                                  _buildDetailItem(
                                    label: 'รายละเอียดการให้บริการ',
                                    value: safeString(booking["serviceDetail"]),
                                  ),
                                  _buildDetailItem(
                                    label: 'วันที่จอง',
                                    value: safeString(booking["bookingDate"]),
                                  ),
                                  _buildDetailItem(
                                    label: 'ช่วงเวลาที่ต้องทำงาน',
                                    value: safeString(booking["workTime"]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // รีวิวและให้คะแนน
                        Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 15,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              const SizedBox(width: 8),
                              const Text(
                                'รีวิวและให้คะแนนการบริการ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              _buildActionButton(
                                label: 'ให้คะแนน',
                                onPressed:
                                    canRate
                                        ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => Ratingdialog(
                                                    bookingData: booking,
                                                  ),
                                            ),
                                          );
                                        }
                                        : null,
                                backgroundColor:
                                    canRate
                                        ? const Color.fromARGB(
                                          255,
                                          78,
                                          197,
                                          240,
                                        )
                                        : Colors.grey[400],
                                foregroundColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildDetailItem({required String label, required String value}) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

Widget _buildActionButton({
  required String label,
  required VoidCallback? onPressed,
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  return SizedBox(
    height: 38,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? const Color(0xFF3e6b47),
        foregroundColor: foregroundColor ?? Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          fontFamily: 'Kanit', // เปลี่ยนเป็นฟอนต์ที่ใช้ในโปรเจกต์
        ),
        elevation: 0,
      ),
      child: Text(label),
    ),
  );
}
