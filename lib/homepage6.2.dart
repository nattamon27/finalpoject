import 'package:appfinal/%20NotificationPage15.dart';
import 'package:appfinal/ContactAdminPage11.dart';
import 'package:appfinal/ProfilePageApp13.dart';
import 'package:appfinal/ServiceDetailPage8.dart';
import 'package:appfinal/ServiceListPage7.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart';

class HomePage6 extends StatefulWidget {
  final String? username;

  HomePage6({this.username});

  @override
  _HomePage6State createState() => _HomePage6State();
}

class _HomePage6State extends State<HomePage6> {
  final supabase = SupabaseManager.client;

  TextEditingController searchController = TextEditingController();
  TextEditingController dateRangeController = TextEditingController();
  TextEditingController raiController = TextEditingController();

  DateTimeRange? selectedDateRange;
  String selectedServiceType = 'รถไถ'; // กำหนดค่าเริ่มต้น
  /* String? selectedServiceTime; // ตัวแปรเก็บช่วงเวลาบริการ */
  int selectedNavIndex = 0;

  final List<String> serviceTypes = [
    'รถไถ',
    'รถดำนา',
    'โดรนพ่นยา',
    'รถเกี่ยวข้าว',
    'รถกรองข้าว',
    'รถแทรกเตอร์',
    'คนรับจ้างทำนา',
  ];

  final List<Map<String, String>> serviceTimes = [
    {'code': 'morning', 'label': 'เช้า'},
    {'code': 'afternoon', 'label': 'บ่าย'},
    {'code': 'full_day', 'label': 'ทั้งวัน'},
  ];

  final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th');

  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> vehiclesForCount = [];
  List<Map<String, dynamic>> vehiclesForUserProvince = [];

  // ตัวแปรใหม่สำหรับเก็บจังหวัดของชาวนา
  List<Map<String, dynamic>> userProvinces = [];
  bool isLoadingUserProvinces = true;
  String? selectedUserProvince;

  bool isLoadingProvinces = true;
  bool isLoadingVehiclesForCount = true;
  bool isLoadingVehiclesForUserProvince = true;
  String? _vehiclesError;

  String? fullName;
  String? userId;

  String? userProvinceId;
  String? selectedProvinceId;

  @override
  void initState() {
    super.initState();
    userId = supabase.auth.currentUser?.id;
    final now = DateTime.now();
    selectedDateRange = DateTimeRange(
      start: now,
      end: now.add(Duration(days: 1)),
    );
    _updateDateRangeText();
    raiController.text = "";
    /*selectedServiceTime = serviceTimes[2]['code']; // 'full_day' เป็นค่าเริ่มต้น*/

    _loadUserFullNameAndProvince();
    _fetchProvinces();
    _fetchVehiclesForCount();
    _fetchUserProvinces(); // เรียกโหลดจังหวัดของชาวนา
  }

  Future<void> _loadUserFullNameAndProvince() async {
    try {
      if (userId == null) {
        setState(() {
          fullName = widget.username ?? 'ผู้ใช้';
          vehiclesForUserProvince = [];
          isLoadingVehiclesForUserProvince = false;
        });
        return;
      }
      final response =
          await supabase
              .from('users')
              .select('full_name, province_id')
              .eq('user_id', userId ?? '')
              .single();

      setState(() {
        fullName = response['full_name'] ?? widget.username ?? 'ผู้ใช้';
        userProvinceId = response['province_id']?.toString();
        selectedProvinceId = userProvinceId;
      });

      await _fetchVehiclesForUserProvince();
    } catch (e) {
      setState(() {
        fullName = widget.username ?? 'ผู้ใช้';
        vehiclesForUserProvince = [];
        isLoadingVehiclesForUserProvince = false;
      });
    }
  }

  void _updateDateRangeText() {
    if (selectedDateRange != null) {
      final startText = dateFormat.format(selectedDateRange!.start);
      final endText = dateFormat.format(selectedDateRange!.end);
      dateRangeController.text = '$startText - $endText';
    }
  }

  Future<void> _fetchProvinces() async {
    setState(() => isLoadingProvinces = true);
    try {
      final response = await supabase
          .from('provinces')
          .select('province_id, province_name, image_url')
          .order('province_name');
      provinces = (response as List).cast<Map<String, dynamic>>();
      print('Provinces loaded: ${provinces.length}');
    } catch (e) {
      provinces = [];
      print('Error loading provinces: $e');
    }
    setState(() => isLoadingProvinces = false);
  }

  Future<void> _fetchVehiclesForCount() async {
    setState(() {
      isLoadingVehiclesForCount = true;
      vehiclesForCount = [];
      _vehiclesError = null;
    });
    try {
      final response = await supabase
          .from('vehicles')
          .select('vehicle_id, province_id')
          .eq('is_published', true)
          .eq('is_available', true);
      vehiclesForCount = (response as List).cast<Map<String, dynamic>>();
      print('Vehicles for count loaded: ${vehiclesForCount.length}');
    } catch (e) {
      vehiclesForCount = [];
      _vehiclesError = e.toString();
      print('Error loading vehicles for count: $e');
    }
    setState(() => isLoadingVehiclesForCount = false);
  }

  Future<void> _fetchVehiclesForUserProvince() async {
    setState(() {
      isLoadingVehiclesForUserProvince = true;
      vehiclesForUserProvince = []; // ล้างข้อมูลเก่าใน setState
      _vehiclesError = null;
    });

    try {
      if (selectedProvinceId == null || selectedProvinceId!.isEmpty) {
        setState(() {
          vehiclesForUserProvince = [];
          isLoadingVehiclesForUserProvince = false;
        });
        return;
      }

      final startDate = selectedDateRange?.start;
      final endDate = selectedDateRange?.end;

      if (startDate == null || endDate == null) {
        setState(() {
          vehiclesForUserProvince = [];
          isLoadingVehiclesForUserProvince = false;
        });
        return;
      }

      final startDateStr = startDate.toIso8601String();
      final endDateStr = endDate.toIso8601String();

      print(
        'Fetching bookings with status pending or confirmed between $startDateStr and $endDateStr',
      );

      // ✅ แก้จาก .in_() เป็น .filter(..., 'in', [...])
      final bookingsData = await supabase
          .from('bookings')
          .select('booking_id, vehicle_id, time_period, status')
          .filter('booking_start_date', 'lte', endDateStr)
          .filter('booking_end_date', 'gte', startDateStr)
          .filter(
            'status',
            'in',
            '("pending","confirmed","waiting_farmer_confirm")',
          );

      print('Bookings fetched: ${bookingsData.length}');

      final excludedVehicleIds = <String>{};
      for (var booking in bookingsData) {
        final vehicleId = booking['vehicle_id']?.toString();

        print('Booking: vehicleId=$vehicleId, , status=${booking['status']}');

        if (vehicleId != null) {
          excludedVehicleIds.add(vehicleId);
        }
      }

      print(
        'Excluded vehicle IDs (booked with pending/confirmed): $excludedVehicleIds',
      );

      final vehiclesData = await supabase
          .from('vehicles')
          .select('''
          vehicle_id, renter_id, vehicle_name, price_per_day, location, description, service_details, service_capacity, vehicle_type, is_published, is_available, province_id,
          vehicleimages!fk_vehicleimages_vehicle (image_url, is_main_image),
          fk_vehicles_renter (full_name),
          vehiclefeatures!vehiclefeatures_vehicle_id_fkey (
            feature_id,
            features!vehiclefeatures_feature_id_fkey (feature_name)
          )
        ''')
          .eq('is_published', true)
          .eq('is_available', true)
          .eq('province_id', selectedProvinceId ?? '')
          .order('vehicle_name');

      print('Vehicles fetched: ${(vehiclesData as List).length}');

      final allVehicles = (vehiclesData as List).cast<Map<String, dynamic>>();

      vehiclesForUserProvince =
          allVehicles.where((vehicle) {
            final vehicleId = vehicle['vehicle_id']?.toString() ?? '';
            final isExcluded = excludedVehicleIds.contains(vehicleId);
            if (isExcluded) {
              print(
                'Excluding vehicle: $vehicleId (${vehicle['vehicle_name']})',
              );
            }
            return !isExcluded;
          }).toList();

      print('Vehicles to display: ${vehiclesForUserProvince.length}');
    } catch (e) {
      vehiclesForUserProvince = [];
      _vehiclesError = e.toString();
      print('Error fetching vehicles for user province: $e');
    }

    setState(() => isLoadingVehiclesForUserProvince = false);
  }

  // ฟังก์ชันดึงจังหวัดของชาวนา
  Future<void> _fetchUserProvinces() async {
    setState(() => isLoadingUserProvinces = true);

    try {
      final userProvinceIdsResponse = await supabase
          .from('users')
          .select('province_id')
          .not('province_id', 'is', null);

      final userProvinceIds =
          (userProvinceIdsResponse as List)
              .map((e) => e['province_id'])
              .toSet()
              .toList();

      if (userProvinceIds.isEmpty) {
        userProvinces = [];
      } else {
        final provinceIdsString = userProvinceIds.join(',');
        final provincesResponse = await supabase
            .from('provinces')
            .select('province_id, province_name, image_url')
            .filter('province_id', 'in', '($provinceIdsString)');

        userProvinces =
            (provincesResponse as List).cast<Map<String, dynamic>>();
      }
    } catch (e, stackTrace) {
      userProvinces = [];
      print('Error fetching user provinces: $e');
      print(stackTrace);
    }

    setState(() => isLoadingUserProvinces = false);
  }

  Map<String, int> _countVehiclesByProvince() {
    Map<String, int> counts = {};
    for (var vehicle in vehiclesForCount) {
      final provinceId = vehicle['province_id']?.toString();
      if (provinceId != null) {
        counts[provinceId] = (counts[provinceId] ?? 0) + 1;
      }
    }
    return counts;
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType) {
      case 'รถไถ':
      case 'รถแทรกเตอร์':
        return Icons.agriculture;
      case 'รถดำนา':
        return Icons.grass;
      case 'โดรนพ่นยา':
        return Icons.air;
      case 'รถเกี่ยวข้าว':
        return Icons.grain;
      case 'รถกรองข้าว':
        return Icons.local_shipping;
      case 'คนรับจ้างทำนา':
        return Icons.people;
      default:
        return Icons.agriculture;
    }
  }

  void _showServiceTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('เลือกประเภทบริการ'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: serviceTypes.length,
                itemBuilder: (context, index) {
                  final type = serviceTypes[index];
                  return ListTile(
                    title: Text(type),
                    leading: Icon(
                      _getServiceIcon(type),
                      color: Color(0xFF2A7D43),
                    ),
                    selected: selectedServiceType == type,
                    selectedTileColor: Colors.green.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        selectedServiceType = type;
                      });
                      Navigator.of(context).pop();
                      _showSnackBar('เลือกบริการ: $type');
                    },
                  );
                },
              ),
            ),
          ),
    );
  }

  /* void _showServiceTimeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('เลือกช่วงเวลาให้บริการ'),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: serviceTimes.length,
                itemBuilder: (context, index) {
                  final time = serviceTimes[index];
                  return RadioListTile<String>(
                    title: Text(time['label']!),
                    value: time['code']!,
                    groupValue: selectedServiceTime,
                    onChanged: (value) {
                      setState(() {
                        selectedServiceTime = value;
                      });
                      Navigator.of(context).pop();
                      _showSnackBar('เลือกช่วงเวลา: ${time['label']}');
                    },
                  );
                },
              ),
            ),
          ),
    );
  } */

  // เพิ่มฟังก์ชันนี้ใน _HomePage6State
  Future<Map<String, dynamic>> fetchVehicleReviewStats(String vehicleId) async {
    try {
      // ดึงรีวิวที่ booking_id ของ booking นั้นมี vehicle_id ตรงกับที่ต้องการ
      final response = await supabase
          .from('reviews')
          .select('rating, booking_id, bookings!fk_reviews_booking(vehicle_id)')
          .eq('bookings.vehicle_id', vehicleId);

      final reviews = response as List;
      if (reviews.isEmpty) {
        return {'average': 0.0, 'count': 0};
      }

      double sum = 0;
      for (var review in reviews) {
        sum += (review['rating'] as num).toDouble();
      }
      double avg = sum / reviews.length;

      return {
        'average': double.parse(avg.toStringAsFixed(1)), // ปัดทศนิยม 1 ตำแหน่ง
        'count': reviews.length,
      };
    } catch (e) {
      print('Error fetching reviews: $e');
      return {'average': 0.0, 'count': 0};
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange =
        selectedDateRange ??
        DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(Duration(days: 1)),
        );

    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              primaryColor: Color(0xFF2A7D43),
              colorScheme: ColorScheme.light(
                primary: Color(0xFF2A7D43),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          ),
    );

    if (newDateRange != null) {
      setState(() {
        selectedDateRange = newDateRange;
        _updateDateRangeText();
      });
      await _fetchVehiclesForUserProvince();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาดในการออกจากระบบ');
    }
  }

  bool _validateSearchInputs() {
    if (selectedDateRange == null) {
      _showAlertDialog('กรุณาเลือกช่วงวันที่ที่ต้องการจอง');
      return false;
    }
    /*if (selectedServiceTime == null || selectedServiceTime!.isEmpty) {
      _showAlertDialog('กรุณาเลือกช่วงเวลาที่ต้องการใช้บริการ');
      return false;
    }*/
    if (raiController.text.trim().isEmpty) {
      _showAlertDialog('กรุณากรอกจำนวนไร่');
      return false;
    }
    final rai = int.tryParse(raiController.text.trim());
    if (rai == null || rai <= 0) {
      _showAlertDialog('กรุณากรอกเป็นตัวเลข');
      return false;
    }
    return true;
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('แจ้งเตือน'),
            content: Text(message),
            actions: [
              TextButton(
                child: Text('ตกลง'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  Widget _buildDestinationCard(
    String imageUrl,
    String name,
    String count,
    bool isSmallScreen,
  ) {
    return InkWell(
      // onTap: null, // ปิดการกด
      // หรือจะลบ onTap ออกไปเลยก็ได้
      child: Container(
        margin: EdgeInsets.only(right: 15),
        width: isSmallScreen ? 140 : 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  imageUrl.isNotEmpty
                      ? SizedBox(
                        height: isSmallScreen ? 100 : 120,
                        width: isSmallScreen ? 140 : 160,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                height: isSmallScreen ? 100 : 120,
                                width: isSmallScreen ? 140 : 160,
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                ),
                              ),
                        ),
                      )
                      : Container(
                        height: isSmallScreen ? 100 : 120,
                        width: isSmallScreen ? 140 : 160,
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported, size: 40),
                      ),
            ),
            SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              count,
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 12 : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard(
    String? imageUrl,
    String name,
    double rating,
    String service,
    String location,
    String availability,
    int price,
    bool isSmallScreen,
    Map<String, dynamic> vehicleData, {
    int? reviewCount, // Added named parameter
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ServiceDetailPage(
                  vehicle: vehicleData,
                  userId: userId,
                  dateRange: selectedDateRange,
                  /*serviceTime: selectedServiceTime,*/
                  rai:
                      (int.tryParse(raiController.text.trim()) ?? 0).toString(),
                ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(right: 15),
        width: isSmallScreen ? 180 : 220,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: isSmallScreen ? 280 : 300,
            maxHeight: isSmallScreen ? 300 : 320,
          ),
          child: Card(
            elevation: 2,
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    child:
                        imageUrl != null
                            ? SizedBox(
                              height: isSmallScreen ? 130 : 150,
                              width: double.infinity,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        _buildPlaceholderImage(isSmallScreen),
                              ),
                            )
                            : _buildPlaceholderImage(isSmallScreen),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 13 : 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: isSmallScreen ? 14 : 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$rating',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            service,
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: isSmallScreen ? 12 : 14,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11 : 12,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            availability,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$price บ. /ชั่วโมง',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 14 : 16,
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
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isSmallScreen) {
    return Container(
      height: isSmallScreen ? 130 : 150,
      width: double.infinity,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.agriculture,
          size: isSmallScreen ? 40 : 50,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildPopularDestinations(bool isSmallScreen) {
    if (isLoadingProvinces || isLoadingVehiclesForCount)
      return Center(child: CircularProgressIndicator());
    if (provinces.isEmpty)
      return Center(
        child: Text(
          'ไม่พบข้อมูลจังหวัด',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );

    final vehicleCounts = _countVehiclesByProvince();

    return SizedBox(
      height: isSmallScreen ? 180 : 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provinces.length,
        itemBuilder: (context, index) {
          final province = provinces[index];
          return _buildDestinationCard(
            province['image_url'] ?? '',
            province['province_name'] ?? 'ไม่ระบุชื่อ',
            '${vehicleCounts[province['province_id'].toString()] ?? 0} ',
            isSmallScreen,
          );
        },
      ),
    );
  }

  Widget _buildRecommendedVehicles(bool isSmallScreen) {
    if (isLoadingVehiclesForUserProvince)
      return Center(child: CircularProgressIndicator());
    if (_vehiclesError != null)
      return Center(
        child: Text(
          'เกิดข้อผิดพลาด: $_vehiclesError',
          style: TextStyle(color: Colors.red),
        ),
      );
    if (vehiclesForUserProvince.isEmpty)
      return Center(
        child: Text(
          'ไม่พบข้อมูลพาหนะ',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );

    return SizedBox(
      height: isSmallScreen ? 300 : 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vehiclesForUserProvince.length,
        itemBuilder: (context, index) {
          final vehicle = vehiclesForUserProvince[index];
          double price = 0;
          final priceRaw = vehicle['price_per_day'];
          if (priceRaw != null) {
            if (priceRaw is int)
              price = priceRaw.toDouble();
            else if (priceRaw is double)
              price = priceRaw;
            else if (priceRaw is String)
              price = double.tryParse(priceRaw) ?? 0;
          }

          String? imageUrl;

          if (vehicle['vehicleimages'] != null &&
              vehicle['vehicleimages'] is List) {
            final images = vehicle['vehicleimages'] as List;
            final mainImage = images.firstWhere(
              (img) => img['is_main_image'] == true,
              orElse: () => images.isNotEmpty ? images[0] : null,
            );
            if (mainImage != null) {
              imageUrl = mainImage['image_url'] as String?;
            }
          }

          return FutureBuilder<Map<String, dynamic>>(
            future: fetchVehicleReviewStats(vehicle['vehicle_id'].toString()),
            builder: (context, snapshot) {
              double rating = 0.0;
              int reviewCount = 0;
              if (snapshot.hasData) {
                rating = snapshot.data!['average'];
                reviewCount = snapshot.data!['count'];
              }

              return _buildEquipmentCard(
                imageUrl,
                vehicle['vehicle_name'] ?? 'ไม่ระบุชื่อ',
                rating, // ใช้คะแนนจริง
                vehicle['description'] ?? '',
                vehicle['location'] ?? '',
                'พร้อมใช้งาน',
                price.toInt(),
                isSmallScreen,
                vehicle,
                reviewCount: reviewCount, // ส่งจำนวนรีวิวไปด้วย (ถ้าต้องการ)
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopBarItem(
    String text,
    int index, {
    IconData? icon,
    Color? iconColor,
    bool showText = true,
  }) {
    bool isSelected = selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          selectedNavIndex = index;
        });
        Widget? page;
        switch (text) {
          case 'หน้าแรก':
            page = HomePage6(username: widget.username);
            break;
          case 'โปรไฟล์':
            page = ProfilePageApp();
            break;
          case 'การแจ้งเตือน':
            page = NotificationPage();
            break;
          case 'ติดต่อเรา':
            page = ContactAdminPage();
            break;
          case 'ออกจากระบบ':
            signOut();
            return;
        }

        if (page != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page!),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border:
              isSelected
                  ? Border(bottom: BorderSide(color: Colors.white, width: 3.0))
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
            if (icon != null && showText) SizedBox(width: 4),
            if (showText)
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2A7D43)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.asset(
                      'lib/assets/IMG_4118 2.jpg',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            Icons.person,
                            color: Color(0xFF2A7D43),
                            size: 40,
                          ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  fullName ?? widget.username ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ...[
            {'icon': Icons.home, 'title': 'หน้าแรก', 'index': 0},
            {'icon': Icons.person, 'title': 'โปรไฟล์', 'index': 1},
            {'icon': Icons.notifications, 'title': 'การแจ้งเตือน', 'index': 2},
            {'icon': Icons.contact_support, 'title': 'ติดต่อเรา', 'index': 3},
            {'icon': Icons.logout, 'title': 'ออกจากระบบ', 'index': 4},
          ].map((item) {
            print('Building drawer item: ${item['title']}');
            return ListTile(
              leading: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color?,
              ),
              title: Text(item['title'] as String),
              selected: selectedNavIndex == item['index'],
              onTap: () async {
                setState(() {
                  selectedNavIndex = item['index'] as int;
                });
                Navigator.pop(context);

                if (item['title'] == 'ออกจากระบบ') {
                  await signOut();
                  return;
                }
                Widget? page;
                switch (item['title']) {
                  case 'หน้าแรก':
                    page = HomePage6(username: widget.username);
                    break;
                  case 'โปรไฟล์':
                    page = ProfilePageApp();
                    break;
                  case 'การแจ้งเตือน':
                    page = NotificationPage();
                    break;
                  case 'ติดต่อเรา':
                    page = ContactAdminPage();
                    break;
                }

                if (page != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => page!),
                  );
                }
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
    final isLargeScreen = screenWidth >= 900;

    return Scaffold(
      drawer: isSmallScreen ? _buildMobileDrawer() : null,
      body: Column(
        children: [
          // App Bar
          Container(
            color: Color(0xFF2A7D43),
            height: 70,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (isSmallScreen)
                  Builder(
                    builder:
                        (context) => IconButton(
                          icon: Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'lib/assets/IMG_4118 2.jpg',
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) =>
                              Icon(Icons.agriculture, color: Color(0xFF2A7D43)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                if (!isSmallScreen)
                  _buildTopBarItem(
                    'หน้าแรก',
                    0,
                    icon: Icons.home,
                    showText: isLargeScreen,
                  ),
                if (!isSmallScreen) SizedBox(width: 16),
                if (!isSmallScreen)
                  _buildTopBarItem(
                    'โปรไฟล์',
                    1,
                    icon: Icons.person,
                    showText: isLargeScreen,
                  ),
                Spacer(),
                if (!isSmallScreen)
                  _buildTopBarItem(
                    'การแจ้งเตือน',
                    2,
                    icon: Icons.notifications,
                    showText: isLargeScreen,
                  ),
                SizedBox(width: 24),
                if (!isSmallScreen)
                  _buildTopBarItem('ติดต่อเรา', 3, showText: isLargeScreen),
                SizedBox(width: 16),

                if (!isSmallScreen)
                  _buildTopBarItem(
                    'ออกจากระบบ',
                    4,
                    icon: Icons.logout,
                    showText: isLargeScreen,
                  ),
                SizedBox(width: 24),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header with Background Image and Title
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.35,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('lib/assets/background.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'ค้นหาบริการที่ถูกใจ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 24 : 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Card
                  Transform.translate(
                    offset: Offset(0, -50),
                    child: Container(
                      width:
                          isSmallScreen
                              ? MediaQuery.of(context).size.width * 0.95
                              : (isMediumScreen
                                  ? MediaQuery.of(context).size.width * 0.9
                                  : MediaQuery.of(context).size.width * 0.85),
                      padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isSmallScreen
                              ? Column(
                                children: [
                                  _buildSearchField(),
                                  SizedBox(height: 10),
                                  _buildServiceTypeButton(),
                                  SizedBox(height: 10),
                                  /* _buildServiceTimeButton(),*/
                                ],
                              )
                              : Row(
                                children: [
                                  Expanded(flex: 2, child: _buildSearchField()),
                                  SizedBox(width: 10),
                                  Expanded(
                                    flex: 1,
                                    child: _buildServiceTypeButton(),
                                  ),
                                  SizedBox(width: 10),
                                  /*Expanded(
                                    flex: 1,
                                    child: _buildServiceTimeButton(),
                                  ),*/
                                ],
                              ),
                          SizedBox(height: 15),
                          Text(
                            'วันเริ่มต้นและวันสิ้นสุด',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          _buildDateRangePicker(),
                          SizedBox(height: 15),
                          isSmallScreen
                              ? Column(children: [_buildRaiField()])
                              : Row(
                                children: [Expanded(child: _buildRaiField())],
                              ),
                          SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: isSmallScreen ? double.infinity : 200,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_validateSearchInputs()) return;

                                  // ส่งข้อมูลไปหน้า ServiceListPage
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ServiceListPage(
                                            provinceId: selectedProvinceId,
                                            serviceType: selectedServiceType,
                                            dateRange: selectedDateRange,
                                            /*serviceTime: selectedServiceTime,*/
                                            rai: int.parse(
                                              raiController.text.trim(),
                                            ), // ✅ ปิดวงเล็บตรงนี้ก่อน
                                            userId:
                                                userId, // ✅ ส่ง userId ได้แล้ว
                                          ),
                                    ),
                                  );
                                  print(
                                    'Selected Service Type: $selectedServiceType',
                                  );

                                  print(
                                    'Selected Date Range: $selectedDateRange',
                                  );
                                  print(
                                    'Selected Rai: ${raiController.text.trim()}',
                                  );
                                  print('Selected userId: $userId');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFE8A845),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: Text(
                                  'ค้นหา',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /*// Popular Destinations Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ประเภทพาหนะยอดนิยมในแต่ละจังหวัด',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        _buildPopularDestinations(isSmallScreen),
                      ],
                    ),
                  ),
*/
                  // Recommended Vehicles Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ประเภทพาหนะที่แนะนำสำหรับท่าน',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        _buildRecommendedVehicles(isSmallScreen),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dropdown จังหวัดยังคง disabled เหมือนเดิม
  Widget _buildSearchField() {
    if (isLoadingUserProvinces) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }

    if (userProvinces.isEmpty) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: Text('ไม่พบจังหวัดที่ชาวนาลงทะเบียน'),
      );
    }

    // กำหนด selectedUserProvince ถ้ายังไม่ถูกตั้งค่า ให้ตั้งเป็นจังหวัดของ userProvinceId
    if (selectedUserProvince == null && userProvinceId != null) {
      final matchedProvince = userProvinces.firstWhere(
        (p) => p['province_id'].toString() == userProvinceId,
        orElse: () => {},
      );
      if (matchedProvince.isNotEmpty) {
        selectedUserProvince = matchedProvince['province_name'];
        selectedProvinceId = userProvinceId;
      }
    }

    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedUserProvince,
          isExpanded: true,
          items:
              userProvinces.map((province) {
                return DropdownMenuItem<String>(
                  value: province['province_name'],
                  child: Text(province['province_name']),
                );
              }).toList(),
          onChanged: null, // ปิดการเลือก (disabled)
          disabledHint: Text(
            selectedUserProvince ?? 'ไม่พบจังหวัด',
            style: TextStyle(color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTypeButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton.icon(
        onPressed: () => _showServiceTypeDialog(context),
        icon: Icon(
          _getServiceIcon(selectedServiceType),
          color: Color(0xFF2A7D43),
        ),
        label: Text(
          selectedServiceType.length > 10
              ? selectedServiceType.substring(0, 10) + '...'
              : selectedServiceType,
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  /*Widget _buildServiceTimeButton() {
    String label = 'เลือกช่วงเวลา';
    final selected = serviceTimes.firstWhere(
      (e) => e['code'] == selectedServiceTime,
      orElse: () => {'label': 'เลือกช่วงเวลา'},
    );
    label = selected['label'] ?? label;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: ElevatedButton(
        onPressed: () => _showServiceTimeDialog(context),
        child: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  } */

  Widget _buildDateRangePicker() {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: InkWell(
        onTap: () => _selectDateRange(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.date_range, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                dateRangeController.text,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaiField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: raiController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'จำนวนไร่',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}
