import 'package:appfinal/BookingHistoryPage9.dart';
import 'package:appfinal/ServiceListPage7.dart';
import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceDetailPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final DateTimeRange? dateRange;
  final String? rai;
  final String? userId; // userId ของ farmer ที่ล็อกอิน
  final String? serviceTime;
  final String? oldBookingId; // ช่วงเวลาบริการ

  const ServiceDetailPage({
    Key? key,
    required this.vehicle,
    this.dateRange,
    this.rai,
    this.userId,
    this.serviceTime,
    this.oldBookingId,
  }) : super(key: key);

  @override
  _ServicestartState createState() => _ServicestartState();
}

class _ServicestartState extends State<ServiceDetailPage> {
  int _currentImageIndex = 0;
  final supabase = Supabase.instance.client;

  double averageRating = 0.0;
  int reviewCount = 0;
  bool isLoadingReviews = true;

  DateTime? bookingStartDate;
  DateTime? bookingEndDate;
  String? timePeriod;
  double? areaSize;

  bool isCheckingBooking = false;
  bool isSavingBooking = false;

  /*String? _normalizeServiceTime(String? input) {
    if (input == null) return null;
    switch (input.toLowerCase()) {
      case 'เช้า':
        return 'morning';
      case 'บ่าย':
        return 'afternoon';
      case 'ทั้งวัน':
        return 'full_day';
      case 'morning':
      case 'afternoon':
      case 'full_day':
        return input.toLowerCase();
      default:
        return null;
    }
  } 

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
  } */

  Future<void> _showBookingInfoDialog() async {
    DateTimeRange? selectedDateRange =
        bookingStartDate != null && bookingEndDate != null
            ? DateTimeRange(start: bookingStartDate!, end: bookingEndDate!)
            : null;
    String? selectedTimePeriod = timePeriod;
    final raiController = TextEditingController(
      text: areaSize != null ? areaSize.toString() : '',
    );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('กรุณากรอกข้อมูลการจอง'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDateRange: selectedDateRange,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDateRange = picked;
                          });
                        }
                      },
                      child: Text(
                        selectedDateRange == null
                            ? 'เลือกวันที่จอง'
                            : '${selectedDateRange!.start.day}/${selectedDateRange!.start.month}/${selectedDateRange!.start.year} - ${selectedDateRange!.end.day}/${selectedDateRange!.end.month}/${selectedDateRange!.end.year}',
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: raiController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนไร่',
                        hintText: 'กรอกจำนวนไร่',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ปิด'),
                ),
                TextButton(
                  onPressed:
                      isSavingBooking
                          ? null
                          : () async {
                            if (selectedDateRange == null ||
                                raiController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('กรุณากรอกข้อมูลให้ครบ'),
                                ),
                              );
                              return;
                            }

                            if (widget.userId == null ||
                                widget.userId!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('กรุณาเข้าสู่ระบบก่อนทำการจอง'),
                                ),
                              );
                              return;
                            }

                            final canBook = await canBookNew(
                              vehicleId: widget.vehicle['vehicle_id'],
                              userId: widget.userId!,
                              startDate: selectedDateRange!.start,
                              endDate: selectedDateRange!.end,
                              oldBookingId:
                                  widget.oldBookingId, // <<<< เพิ่มบรรทัดนี้
                            );

                            if (!canBook) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ไม่สามารถจองได้ เนื่องจากมีการจองทับซ้อนหรือสถานะการจองเดิมยังไม่เสร็จ',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              bookingStartDate = selectedDateRange!.start;
                              bookingEndDate = selectedDateRange!.end;
                              // timePeriod = selectedTimePeriod; //
                              areaSize = double.tryParse(
                                raiController.text.trim(),
                              );
                            });
                            Navigator.of(context).pop();
                          },
                  child:
                      isSavingBooking
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> fetchActiveBookingInfo(String vehicleId) async {
    try {
      final bookings = await supabase
          .from('bookings')
          .select(
            'booking_id, booking_start_date, booking_end_date, status, time_period, area_size',
          )
          .eq('vehicle_id', vehicleId)
          .or(
            'status.eq.confirmed,status.eq.pending,status.eq.waiting_farmer_confirm',
          );
      if (bookings == null || bookings.isEmpty) {
        setState(() {
          bookingStartDate = null;
          bookingEndDate = null;
          timePeriod = null;
          areaSize = null;
        });
        return;
      }

      for (var booking in bookings) {
        final bookingId = booking['booking_id'];

        final statusHistories = await supabase
            .from('bookingstatushistory')
            .select('new_status')
            .eq('booking_id', bookingId)
            .order('changed_at', ascending: false)
            .limit(1);

        String latestStatus = booking['status'] ?? '';
        if (statusHistories != null && statusHistories.isNotEmpty) {
          latestStatus = statusHistories[0]['new_status'] ?? latestStatus;
        }

        if (latestStatus == 'cancelled' || latestStatus == 'completed') {
          continue;
        }

        setState(() {
          bookingStartDate =
              booking['booking_start_date'] != null
                  ? DateTime.parse(booking['booking_start_date'])
                  : null;
          bookingEndDate =
              booking['booking_end_date'] != null
                  ? DateTime.parse(booking['booking_end_date'])
                  : null;
          timePeriod = booking['time_period'];
          areaSize =
              booking['area_size'] != null
                  ? double.tryParse(booking['area_size'].toString())
                  : null;
        });
        return;
      }

      setState(() {
        bookingStartDate = null;
        bookingEndDate = null;
        timePeriod = null;
        areaSize = null;
      });
    } catch (e) {
      setState(() {
        bookingStartDate = null;
        bookingEndDate = null;
        timePeriod = null;
        areaSize = null;
      });
    }
  }

  Future<void> sendNotificationToRenter({
    required String renterId,
    required String title,
    required String message,
    BuildContext? context, // เพิ่ม context เป็น optional parameter
  }) async {
    try {
      final response =
          await Supabase.instance.client.from('notifications').insert({
            'user_id': renterId,
            'message': message,
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          }).select();

      print('Notification inserted: $response');

      if (context != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ส่งแจ้งเตือนสำเร็จ')));
      }
    } catch (e) {
      print('Exception sending notification: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งแจ้งเตือน: $e')),
        );
      }
    }
  }

  Future<void> fetchReviewData(String vehicleId) async {
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final bookingsResponse = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('vehicle_id', vehicleId);

      if (bookingsResponse == null ||
          bookingsResponse is! List ||
          bookingsResponse.isEmpty) {
        setState(() {
          averageRating = 0.0;
          reviewCount = 0;
          isLoadingReviews = false;
        });
        return;
      }

      final bookingIds =
          bookingsResponse
              .map<String>((b) => b['booking_id'].toString())
              .toList();

      final reviewsResponse = await supabase
          .from('reviews')
          .select('rating')
          .filter('booking_id', 'in', bookingIds);

      if (reviewsResponse == null ||
          reviewsResponse is! List ||
          reviewsResponse.isEmpty) {
        setState(() {
          averageRating = 0.0;
          reviewCount = 0;
          isLoadingReviews = false;
        });
        return;
      }

      double sum = 0;
      for (var r in reviewsResponse) {
        final ratingValue = r['rating'];
        if (ratingValue != null) {
          sum += double.tryParse(ratingValue.toString()) ?? 0;
        }
      }

      setState(() {
        reviewCount = reviewsResponse.length;
        averageRating = sum / reviewCount;
        isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        averageRating = 0.0;
        reviewCount = 0;
        isLoadingReviews = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // แปลงช่วงเวลาบริการให้เป็นโค้ดที่ใช้ในระบบ

    // กำหนดวันที่และจำนวนไร่จากพารามิเตอร์
    if (widget.dateRange != null) {
      bookingStartDate = widget.dateRange!.start;
      bookingEndDate = widget.dateRange!.end;
    }
    if (widget.rai != null) {
      areaSize = double.tryParse(widget.rai!);
    }

    final vehicleId = widget.vehicle['vehicle_id']?.toString() ?? '';
    if (vehicleId.isNotEmpty) {
      fetchReviewData(vehicleId);
      fetchActiveBookingInfo(vehicleId).then((_) async {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // ตรวจสอบว่ามีข้อมูลจาก widget ครบหรือไม่
          final hasInitialBookingInfo =
              widget.dateRange != null &&
              widget.rai != null &&
              widget.serviceTime != null &&
              (double.tryParse(widget.rai!) ?? 0) > 0;

          if (hasInitialBookingInfo) {
            setState(() {
              bookingStartDate = widget.dateRange!.start;
              bookingEndDate = widget.dateRange!.end;
              areaSize = double.tryParse(widget.rai!);
            });
          }
          // *** ตรงนี้จะไม่มีการเรียก _showBookingInfoDialog() อัตโนมัติอีกต่อไป ***
        });
      });
    } else {
      isLoadingReviews = false;
    }
  }

  Future<bool> canBookNew({
    required String vehicleId,
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    String? oldBookingId,
  }) async {
    if (userId.isEmpty) return false;
    if (isCheckingBooking) return false;
    isCheckingBooking = true;

    try {
      String startDateStr = startDate.toIso8601String().substring(0, 10);
      String endDateStr = endDate.toIso8601String().substring(0, 10);

      // ตรวจสอบว่าผู้ใช้มีการจองทับซ้อนหรือไม่
      final userBookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('vehicle_id', vehicleId)
          .eq('farmer_id', userId)
          .filter('status', 'in', [
            'pending',
            'confirmed',
            'waiting_farmer_confirm',
          ])
          .lte('booking_start_date', endDateStr)
          .gte('booking_end_date', startDateStr);

      print('userBookings ทั้งหมด: $userBookings');
      print('oldBookingId ที่ใช้ filter: $oldBookingId');
      final filteredUserBookings =
          (userBookings as List)
              .where((b) => b['booking_id'].toString() != (oldBookingId ?? ''))
              .toList();

      print('userBookings หลัง filter booking เดิม: $filteredUserBookings');

      if (filteredUserBookings.isNotEmpty) {
        print('พบ userBookings ซ้อนทับ: $filteredUserBookings');
        return false;
      }

      final overlappingBookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('vehicle_id', vehicleId)
          .filter('status', 'in', [
            'pending',
            'confirmed',
            'waiting_farmer_confirm',
          ])
          .lte('booking_start_date', endDateStr)
          .gte('booking_end_date', startDateStr);

      print('overlappingBookings ทั้งหมด: $overlappingBookings');
      final filteredOverlapping =
          (overlappingBookings as List)
              .where((b) => b['booking_id'].toString() != (oldBookingId ?? ''))
              .toList();
      print(
        'overlappingBookings หลัง filter booking เดิม: $filteredOverlapping',
      );

      if (filteredOverlapping.isNotEmpty) {
        print('พบ overlappingBookings ซ้อนทับ: $filteredOverlapping');
        return false;
      }
      return true;
    } catch (e) {
      return false;
    } finally {
      isCheckingBooking = false;
    }
  }

  Future<bool> createBooking() async {
    final renterId = widget.vehicle['renter_id'];
    print('renterId: $renterId');
    if (bookingStartDate == null ||
        bookingEndDate == null ||
        areaSize == null ||
        widget.userId == null ||
        widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ข้อมูลการจองไม่ครบถ้วน หรือ กรุณาเข้าสู่ระบบ'),
        ),
      );
      return false;
    }
    if (isSavingBooking) return false;

    setState(() {
      isSavingBooking = true;
    });

    try {
      if (renterId == null || renterId.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลเจ้าของพาหนะ (renter_id)')),
        );
        return false;
      }

      // **เพิ่มส่วนนี้: ยกเลิก booking เดิมถ้ามี**
      if (widget.oldBookingId != null && widget.oldBookingId!.isNotEmpty) {
        await supabase
            .from('bookings')
            .update({'status': 'cancelled'})
            .eq('booking_id', widget.oldBookingId ?? '');
      }

      // **ส่วนเดิม: insert booking ใหม่**
      final response =
          await supabase.from('bookings').insert({
            'vehicle_id': widget.vehicle['vehicle_id'],
            'farmer_id': widget.userId,
            'renter_id': renterId,
            'booking_start_date': bookingStartDate!.toIso8601String(),
            'booking_end_date': bookingEndDate!.toIso8601String(),

            'area_size': areaSize,
            'status': 'pending',
          }).select();

      if (response != null && response.isNotEmpty) {
        // ส่งแจ้งเตือนไปยังผู้ให้เช่า
        print('Sending notification to renter...');
        await sendNotificationToRenter(
          renterId: renterId.toString(),
          title: 'มีการจองพาหนะใหม่',
          message:
              'พาหนะของคุณถูกจองในวันที่ ${bookingStartDate!.day}/${bookingStartDate!.month}/${bookingStartDate!.year} - ${bookingEndDate!.day}/${bookingEndDate!.month}/${bookingEndDate!.year}  จำนวนไร่: $areaSize',
        );
        print('Notification function completed');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('จองพาหนะสำเร็จ')));
        return true;
      } else {
        throw Exception('ไม่สามารถบันทึกข้อมูลได้');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      return false;
    } finally {
      setState(() {
        isSavingBooking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(16, 104, 63, 1);
    const primaryLight = Color(0xFFB2DFDB);
    const primaryDark = Color(0xFF004D40);
    const textSecondary = Color(0xFF757575);

    final vehicle = widget.vehicle;

    final List vehicleImages = vehicle['vehicleimages'] ?? [];
    final List sortedImages = [
      ...vehicleImages.where((img) => img['is_main_image'] == true),
      ...vehicleImages.where((img) => img['is_main_image'] != true),
    ];

    final List vehicleFeatures = vehicle['vehiclefeatures'] ?? [];
    final List<String> featureNames =
        vehicleFeatures
            .map<String>((vf) {
              final feature = vf['features'];
              return feature != null ? (feature['feature_name'] ?? '') : '';
            })
            .where((name) => name.isNotEmpty)
            .toList();

    final String vehicleName = vehicle['vehicle_name'] ?? 'ไม่ระบุชื่อ';
    final double pricePerDay = vehicle['price_per_day'] ?? 0;
    final String location = vehicle['location'] ?? '';
    final String vehicleType = vehicle['vehicle_type'] ?? '';
    final bool isAvailable = vehicle['is_available'] ?? false;
    final String availability =
        isAvailable ? 'พร้อมให้บริการ' : 'ไม่พร้อมให้บริการ';

    final String serviceDetails = vehicle['service_details'] ?? '';
    final int serviceCapacity = vehicle['service_capacity'] ?? 0;

    final Map<String, dynamic>? user =
        vehicle['users'] ?? vehicle['fk_vehicles_renter'];
    final String providerName =
        user != null && user['full_name'] != null
            ? user['full_name']
            : 'ไม่ทราบชื่อผู้ให้บริการ';

    final String status = (vehicle['status'] ?? '').toString().toLowerCase();
    final bool isOnline = status == 'active';
    final String providerStatusText = isOnline ? 'ออนไลน์' : 'ออฟไลน์';
    final Color providerStatusColor = isOnline ? Colors.green : Colors.red;

    String dateRangeText =
        (bookingStartDate != null && bookingEndDate != null)
            ? '${bookingStartDate!.day}/${bookingStartDate!.month}/${bookingStartDate!.year} - ${bookingEndDate!.day}/${bookingEndDate!.month}/${bookingEndDate!.year}'
            : '-';

    String raiText =
        (areaSize != null && areaSize! > 0) ? '$areaSize ไร่' : '-';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 250, 246, 246),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 22, 74, 39),
        title: Text(
          'รายละเอียด: $vehicleName',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: const Color.fromARGB(
                255,
                255,
                253,
                253,
              ).withOpacity(0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ภาพพาหนะ
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 400,
                      child:
                          sortedImages.isEmpty
                              ? Container(
                                color: Colors.grey[300],
                                child: const Center(child: Text('ไม่มีรูปภาพ')),
                              )
                              : Stack(
                                children: [
                                  PageView.builder(
                                    itemCount: sortedImages.length,
                                    controller: PageController(
                                      initialPage: _currentImageIndex,
                                    ),
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      final imgUrl =
                                          sortedImages[index]['image_url'] ??
                                          '';
                                      if (imgUrl.isEmpty) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            size: 100,
                                          ),
                                        );
                                      }
                                      return Image.network(
                                        imgUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        loadingBuilder: (
                                          context,
                                          child,
                                          progress,
                                        ) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  progress.expectedTotalBytes !=
                                                          null
                                                      ? progress
                                                              .cumulativeBytesLoaded /
                                                          progress
                                                              .expectedTotalBytes!
                                                      : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    size: 100,
                                                  ),
                                                ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 16,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        sortedImages.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          width:
                                              _currentImageIndex == index
                                                  ? 12
                                                  : 8,
                                          height:
                                              _currentImageIndex == index
                                                  ? 12
                                                  : 8,
                                          decoration: BoxDecoration(
                                            color:
                                                _currentImageIndex == index
                                                    ? Colors.white
                                                    : Colors.white54,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                  // รายละเอียดพาหนะ
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ราคาและสถานะ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 36, 88, 50),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_offer,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '฿$pricePerDay/ชั่วโมง',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      isAvailable
                                          ? const Color(0xFF4CAF50)
                                          : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  availability,
                                  style: TextStyle(
                                    color:
                                        isAvailable
                                            ? const Color(0xFF4CAF50)
                                            : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (featureNames.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                featureNames
                                    .map(
                                      (feature) => _buildFeature(
                                        icon: Icons.check,
                                        text: feature,
                                      ),
                                    )
                                    .toList(),
                          ),
                        ],
                        const SizedBox(height: 25),
                        // ข้อมูลผู้ให้บริการ
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      providerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: providerStatusColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          providerStatusText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: providerStatusColor,
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
                        const SizedBox(height: 30),
                        // รายละเอียดบริการ
                        const Text(
                          'รายละเอียดบริการ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: primaryDark,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // คะแนนรีวิว
                        _buildDetailRow(
                          icon: Icons.star,
                          label: 'คะแนน',
                          valueWidget:
                              isLoadingReviews
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        if (averageRating >= index + 1) {
                                          return const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        } else if (averageRating > index &&
                                            averageRating < index + 1) {
                                          return const Icon(
                                            Icons.star_half,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        } else {
                                          return const Icon(
                                            Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        }
                                      }),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${averageRating.toStringAsFixed(1)}/5',
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(จาก $reviewCount รีวิว)',
                                        style: const TextStyle(
                                          color: Color(0xFF757575),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                        // วันที่จอง
                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: 'วันที่จอง',
                          value: dateRangeText,
                        ),
                        // จำนวนไร่
                        _buildDetailRow(
                          icon: Icons.grass,
                          label: 'จำนวนไร่',
                          value: raiText,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: Icon(Icons.edit_calendar),
                            label: Text('แก้ไขข้อมูลการจอง'),
                            onPressed: _showBookingInfoDialog,
                          ),
                        ),
                        _buildDetailRow(
                          icon: Icons.agriculture,
                          label: 'ประเภทการบริการ',
                          value: vehicleType,
                        ),
                        _buildDetailRow(
                          icon: Icons.location_on,
                          label: 'พื้นที่ให้บริการ',
                          value: location,
                        ),

                        _buildDetailRow(
                          icon: Icons.description,
                          label: 'รายละเอียดการให้บริการ',
                          value: serviceDetails,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  color: primaryColor,
                                ),
                                label: const Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: primaryColor),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    (isSavingBooking || !isAvailable)
                                        ? null
                                        : () async {
                                          if (bookingStartDate == null ||
                                              bookingEndDate == null ||
                                              areaSize == null ||
                                              areaSize! <= 0) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'กรุณากรอกข้อมูลการจองให้ครบถ้วนและจำนวนไร่ต้องมากกว่า 0',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final vehicleId =
                                              widget.vehicle['vehicle_id']
                                                  ?.toString() ??
                                              '';
                                          final userId = widget.userId ?? '';
                                          print(
                                            'เรียก canBookNew ด้วย oldBookingId: ${widget.oldBookingId}',
                                          );

                                          final canBook = await canBookNew(
                                            vehicleId: vehicleId,
                                            userId: userId,
                                            startDate: bookingStartDate!,
                                            endDate: bookingEndDate!,
                                            oldBookingId:
                                                widget
                                                    .oldBookingId, // ส่ง property ของ widget เข้าไป
                                          );

                                          if (!canBook) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'ไม่สามารถจองได้ เนื่องจากมีการจองทับซ้อนในช่วงวันที่เลือก',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final success = await createBooking();
                                          if (success) {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        BookingHistoryPage(
                                                          farmerId:
                                                              widget.userId ??
                                                              '',
                                                        ),
                                              ),
                                            );
                                          }
                                        },
                                icon:
                                    isSavingBooking
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.check_circle),
                                label: const Text('ยืนยันการจอง'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  elevation: 8,
                                  shadowColor: primaryColor.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isAvailable)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'รถไม่ว่างในช่วงเวลานี้',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
  }) {
    const primaryColor = Color(0xFF00796B);
    const primaryLight = Color(0xFFB2DFDB);
    const textSecondary = Color(0xFF757575);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                valueWidget ??
                    Text(
                      value ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({required IconData icon, required String text}) {
    const primaryColor = Color(0xFF00796B);
    const primaryLight = Color(0xFFB2DFDB);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
