import 'package:appfinal/%20NotificationPage15.dart';
import 'package:appfinal/ContactAdminPage11.dart';
import 'package:appfinal/ProfilePageApp13.dart';
import 'package:appfinal/ServiceDetailPage8.dart';
import 'package:appfinal/homepage6.2.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceListPage extends StatefulWidget {
  final String? provinceId; // รับจังหวัดจาก Homepage6
  final String? serviceType;
  final DateTimeRange? dateRange;
  final int? rai;
  final String? serviceTime;
  final String? userId;

  const ServiceListPage({
    Key? key,
    this.provinceId,
    this.serviceType,
    this.dateRange,
    this.rai,
    this.serviceTime,
    this.userId,
  }) : super(key: key);

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  final supabase = Supabase.instance.client;

  double priceRangeValue = 2500;
  String activeFilterTab = "ทั้งหมด";
  String activeCategory = "ทั้งหมด";
  String sortOption = "แนะนำ";
  int selectedNavIndex = 0;
  double minPrice = 0;
  double maxPrice = 5000;
  bool isMenuOpen = false;
  List<bool> selectedRatings = [false, false, false, false, false];

  late TextEditingController searchController;
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;

  final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th');
  RangeValues priceRange = RangeValues(0, 5000);

  DateTimeRange? _selectedDateRange;
  late TextEditingController raiController;

  final List<Map<String, dynamic>> categories = [
    {"name": "ทั้งหมด", "icon": Icons.grid_view, "isSelected": true},
    {"name": "รถไถ", "icon": Icons.agriculture, "isSelected": false},
    {"name": "รถดำนา", "icon": Icons.eco, "isSelected": false},
    {"name": "โดรนพ่นยา", "icon": Icons.flight, "isSelected": false},
    {"name": "รถเกี่ยวข้าว", "icon": Icons.local_shipping, "isSelected": false},
    {"name": "รถกรองข้าว", "icon": Icons.filter_alt, "isSelected": false},
    {
      "name": "รถแทรกเตอร์",
      "icon": Icons.agriculture_outlined,
      "isSelected": false,
    },
    {
      "name": "คนรับจ้างทำนา",
      "icon": Icons.person_outline,
      "isSelected": false,
    },
  ];

  final List<Map<String, dynamic>> ratings = [
    {"stars": "★★★★★", "count": 8},
    {"stars": "★★★★☆", "count": 12},
    {"stars": "★★★☆☆", "count": 6},
    {"stars": "★★☆☆☆", "count": 3},
    {"stars": "★☆☆☆☆", "count": 1},
  ];

  List<Map<String, dynamic>> allServices = [];
  List<Map<String, dynamic>> filteredServices = [];
  bool isLoading = true;

  late String selectedServiceTime;

  @override
  void initState() {
    super.initState();

    priceRange = RangeValues(minPrice, maxPrice);

    minPrice = 0;
    maxPrice = 5000;

    minPriceController = TextEditingController(
      text: minPrice.toInt().toString(),
    );
    maxPriceController = TextEditingController(
      text: maxPrice.toInt().toString(),
    );

    _selectedDateRange = widget.dateRange;
    raiController = TextEditingController(text: widget.rai?.toString() ?? '');

    searchController = TextEditingController();

    if (widget.serviceType != null && widget.serviceType!.isNotEmpty) {
      for (var cat in categories) {
        cat["isSelected"] = cat["name"] == widget.serviceType;
      }
      activeCategory = widget.serviceType!;
    }

    selectedServiceTime = widget.serviceTime ?? 'ทั้งวัน';

    fetchServices();
  }

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    raiController.dispose();
    super.dispose();
  }

  Future<void> fetchServices() async {
    setState(() {
      isLoading = true;
    });

    try {
      var query = supabase
          .from('vehicles')
          .select('''
      vehicle_id,
      vehicle_name,
      price_per_day,
      location,
      description,
      service_details,
      service_capacity,
      status,
      renter_id,
      vehicle_type,
      is_published,
      is_available,
      province_id,
      vehicleimages!fk_vehicleimages_vehicle (
        image_url,
        is_main_image
      ),
      fk_vehicles_renter (
        full_name
      ),
      vehiclefeatures!vehiclefeatures_vehicle_id_fkey (
        feature_id,
        features!vehiclefeatures_feature_id_fkey (
          feature_name
        )
      ),
      bookings!bookings_vehicle_id_fkey (
        booking_id,
        status,
        booking_start_date,
        booking_end_date,
        reviews!reviews_booking_id_fkey (
          rating
        )
      )
    ''')
          .eq('is_published', true)
          .eq('is_available', true)
          .eq('status', 'active');

      final provinceId = widget.provinceId;
      if (provinceId != null) {
        query = query.eq('province_id', provinceId);
      }

      final List data = await query.order('vehicle_name').limit(100);

      allServices =
          data
              .where((service) {
                final bookings = service['bookings'] as List<dynamic>? ?? [];
                bool hasActiveBooking = bookings.any((booking) {
                  final status = booking['status'] ?? '';
                  return status == 'pending' ||
                      status == 'confirmed' ||
                      status == 'waiting_farmer_confirm';
                });
                return !hasActiveBooking;
              })
              .map<Map<String, dynamic>>((service) {
                final bookings = service['bookings'] as List<dynamic>? ?? [];
                List<num> allRatings = [];

                for (var booking in bookings) {
                  final reviews = booking['reviews'] as List<dynamic>? ?? [];
                  for (var review in reviews) {
                    final rating = review['rating'] ?? 0;
                    if (rating is num && rating > 0) {
                      allRatings.add(rating);
                    }
                  }
                }

                double avgRating = 0.0;
                if (allRatings.isNotEmpty) {
                  avgRating =
                      allRatings.reduce((a, b) => a + b) / allRatings.length;
                }

                service['rating'] = avgRating;
                return service;
              })
              .toList();

      _applyFilters();
    } catch (e) {
      print('เกิดข้อผิดพลาด: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล')),
      );
      allServices = [];
      filteredServices = [];
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredServices =
          allServices.where((service) {
            bool matchesCategory =
                activeCategory == "ทั้งหมด" ||
                service['vehicle_type'] == activeCategory;

            final price = (service['price_per_day'] ?? 0);
            final priceValue =
                price is int ? price : int.tryParse(price.toString()) ?? 0;
            bool matchesPrice =
                priceValue >= minPrice && priceValue <= maxPrice;

            // กรองคะแนนผู้ให้บริการ
            bool matchesRating = true;
            if (selectedRatings.contains(true)) {
              final rating = (service['rating'] ?? 0.0).toDouble();
              matchesRating = false;
              for (int i = 0; i < selectedRatings.length; i++) {
                if (selectedRatings[i]) {
                  double lowerBound = 5 - i - 1 + 0.01;
                  double upperBound = 5 - i + 0.0;
                  if (rating >= lowerBound && rating <= upperBound) {
                    matchesRating = true;
                    break;
                  }
                }
              }
            }

            return matchesCategory && matchesPrice && matchesRating;
          }).toList();
    });
  }

  void _goToDetail(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ServiceDetailPage(
              vehicle: service,
              dateRange: widget.dateRange,
              rai: widget.rai?.toString(),
              serviceTime: selectedServiceTime,
              userId: widget.userId,
            ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    String imageUrl = '';
    if (service['vehicleimages'] != null &&
        (service['vehicleimages'] as List).isNotEmpty) {
      final mainImage = (service['vehicleimages'] as List).firstWhere(
        (img) => img['is_main_image'] == true,
        orElse: () => (service['vehicleimages'] as List).first,
      );
      imageUrl = mainImage['image_url'] ?? '';
    }
    if (imageUrl.isEmpty) {
      imageUrl = "https://placehold.co/400x300/00796B/FFFF?text=รถ";
    }

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              imageUrl,
              height: 120, // ลดความสูงลง
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                );
              },
            ),
          ),
          // ใช้ Expanded ครอบ Padding
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        activeCategory = service['vehicle_type'];
                        fetchServices();
                      });
                    },
                    child: Text(
                      service["vehicle_name"] ?? 'ไม่มีชื่อ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            Icons.star,
                            color: Color(0xFFE6A94E),
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        "(${(service['rating'] ?? 0).toStringAsFixed(1)})",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "฿${service["price_per_day"] ?? 0}/ชั่วโมง",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A7D43),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Color(0xFF2A7D43),
                        size: 20,
                      ),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          service["location"] ?? 'ไม่ระบุสถานที่',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () => _goToDetail(service),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2A7D43),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ดูรายละเอียด',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  // ช่องเลือกช่วงวันที่เดียว
  Widget _buildDateRangeField() {
    String text;
    if (widget.dateRange == null) {
      text = 'เลือกช่วงวันที่';
    } else {
      final start = dateFormat.format(widget.dateRange!.start);
      final end = dateFormat.format(widget.dateRange!.end);
      text = '$start - $end';
    }

    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () => _selectDateRange(context),
        borderRadius: BorderRadius.circular(25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          widget.dateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(Duration(days: 1)),
          ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      locale: const Locale('th', 'TH'),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Widget _buildRaiField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: raiController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'จำนวนไร่',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Container(
      height: 45,
      width: 45,
      decoration: BoxDecoration(
        color: Color(0xFFE8A845),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(Icons.search, color: Colors.white),
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('กำลังค้นหา...')));
        },
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.menu, color: Color(0xFF2A7D43), size: 24),
          SizedBox(width: 15),
          Text(
            "หมวดหมู่",
            style: TextStyle(
              color: Color(0xFF2A7D43),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    bool isSelected = category["isSelected"];
    return InkWell(
      onTap: () {
        setState(() {
          for (var cat in categories) {
            cat["isSelected"] = false;
          }
          category["isSelected"] = true;
          activeCategory = category["name"];
          _applyFilters();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFD5E8E4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(category["icon"], color: Color(0xFF2A7D43), size: 24),
            SizedBox(width: 15),
            Text(
              category["name"],
              style: TextStyle(
                color: Color(0xFF2A7D43),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        child,
        const SizedBox(height: 25),
        const Divider(height: 1, color: Color(0xFFE0E0E0)),
        const SizedBox(height: 25),
      ],
    );
  }

  Widget _buildRatingItem({
    required String stars,
    required int count,
    required int index,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedRatings[index] = !selectedRatings[index];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${selectedRatings[index] ? "เลือก" : "ยกเลิก"}คะแนน: $stars',
              ),
              duration: Duration(seconds: 1),
            ),
          );
          _applyFilters();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              stars,
              style: const TextStyle(color: Color(0xFFE6A94E), fontSize: 16),
            ),
            const Spacer(),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFFE0E0E0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child:
                  selectedRatings[index]
                      ? Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageItem({String? text, IconData? icon, bool isActive = false}) {
    return InkWell(
      onTap: () {
        // TODO: จัดการ pagination
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isActive ? Theme.of(context).primaryColor : Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child:
              icon != null
                  ? Icon(
                    icon,
                    color: isActive ? Colors.white : Color(0xFF757575),
                    size: 20,
                  )
                  : Text(
                    text!,
                    style: TextStyle(
                      color: isActive ? Colors.white : Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildTopBarItem(
    String text,
    int index, {
    IconData? icon,
    Color? iconColor,
  }) {
    bool isSelected = selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          selectedNavIndex = index;
        });

        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage6()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePageApp()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationPage()),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactAdminPage()),
            );
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เลือกเมนู: $text'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border:
              isSelected
                  ? Border(bottom: BorderSide(color: Colors.white, width: 3.0))
                  : null,
        ),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
            if (icon != null) SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A7D43),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Color(0xFF2A7D43)),
                      ),
                      SizedBox(width: 15),
                      Text(
                        'ประกาศิต วิวกรรม์',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildMobileMenuItem('หน้าแรก', Icons.home, 0),
                      _buildMobileMenuItem('โปรไฟล์', Icons.person, 1),
                      _buildMobileMenuItem(
                        'การแจ้งเตือน',
                        Icons.notifications,
                        3,
                      ),
                      _buildMobileMenuItem(
                        'ติดต่อเรา',
                        Icons.contact_support,
                        4,
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text(
                          'ออกจากระบบ',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ออกจากระบบแล้ว')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildMobileMenuItem(String title, IconData icon, int index) {
    bool isSelected = selectedNavIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() {
          selectedNavIndex = index;
        });
        Navigator.pop(context);

        switch (index) {
          case 0:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage6()),
            );
            break;
          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePageApp()),
            );
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationPage()),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactAdminPage()),
            );
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เลือกเมนู: $title'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  // -------------------------------
  // Sidebar Responsive
  Widget _buildSidebarContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarSection(
          title: "ค้นหา",
          icon: Icons.search,
          child: SizedBox.shrink(),
        ),
        _buildCategoryHeader(),
        ...categories.map((category) => _buildCategoryItem(category)).toList(),
        SizedBox(height: 20),
        Divider(height: 1, color: Color(0xFFE0E0E0)),
        SizedBox(height: 20),
        _buildSidebarSection(
          title: "ช่วงราคาต่อชั่วโมง",
          icon: Icons.local_offer,
          child: Column(
            children: [
              RangeSlider(
                values: RangeValues(minPrice, maxPrice),
                min: 0,
                max: 5000,
                activeColor: Theme.of(context).primaryColor,
                inactiveColor: const Color(0xFFE0E0E0),
                onChanged: (RangeValues values) {
                  setState(() {
                    minPrice = values.start;
                    maxPrice = values.end;
                    minPriceController.text = minPrice.toInt().toString();
                    maxPriceController.text = maxPrice.toInt().toString();
                    _applyFilters();
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        final val = double.tryParse(value) ?? 0;
                        setState(() {
                          minPrice = val.clamp(0, maxPrice);
                          minPriceController.text = minPrice.toInt().toString();
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                  const Text("-"),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        final val = double.tryParse(value) ?? 5000;
                        setState(() {
                          maxPrice = val.clamp(minPrice, 5000);
                          maxPriceController.text = maxPrice.toInt().toString();
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildSidebarSection(
          title: "คะแนนผู้ให้บริการ",
          icon: Icons.star,
          child: Column(
            children: List.generate(
              ratings.length,
              (index) => _buildRatingItem(
                stars: ratings[index]["stars"],
                count: ratings[index]["count"],
                index: index,
              ),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (MediaQuery.of(context).size.width <= 768) {
              Navigator.of(context).pop(); // ปิด Drawer เฉพาะบน mobile
            }
            setState(() {
              searchController.clear();
              activeCategory = "ทั้งหมด";
              for (var cat in categories) {
                cat["isSelected"] = cat["name"] == "ทั้งหมด";
              }
              activeFilterTab = "ทั้งหมด";
              priceRangeValue = 2500;
              selectedRatings = [false, false, false, false, false];
              selectedServiceTime = 'ทั้งวัน';
              _applyFilters();
            });
          },
          icon: const Icon(Icons.filter_list),
          label: const Text("รีเซ็ตข้อมูล"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
  // -------------------------------

  @override
  Widget build(BuildContext context) {
    // Responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 768 && screenWidth <= 1024;
    final isMobile = screenWidth <= 768;

    double sidebarWidth;
    if (isDesktop) {
      sidebarWidth = 280;
    } else if (isTablet) {
      sidebarWidth = screenWidth * 0.4;
    } else {
      sidebarWidth = screenWidth * 0.85;
    }

    return Scaffold(
      drawer:
          isMobile
              ? Drawer(
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: _buildSidebarContent(),
                    ),
                  ),
                ),
              )
              : null,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Container(
          color: Color(0xFF2A7D43),
          height: 70,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
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
              SizedBox(width: 32),
              if (!isMobile) ...[
                _buildTopBarItem('หน้าแรก', 0),
                SizedBox(width: 24),
                _buildTopBarItem('โปรไฟล์', 1),
                Spacer(),
                SizedBox(width: 24),
                _buildTopBarItem('การแจ้งเตือน', 3, icon: Icons.notifications),
                SizedBox(width: 24),
                _buildTopBarItem('ติดต่อเรา', 4),
                SizedBox(width: 24),
                Text(
                  '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (isMobile) ...[
                Spacer(),
                IconButton(
                  icon: Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      isMenuOpen = !isMenuOpen;
                    });
                    _showMobileMenu(context);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1500382017468-9049fed747ef?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1932&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (!isMobile)
                  Container(
                    width: sidebarWidth,
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: _buildSidebarContent(),
                      ),
                    ),
                  ),
                Expanded(
                  child:
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 15.0 : 25.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                  ),
                                  const SizedBox(height: 25),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount:
                                              isDesktop
                                                  ? 3
                                                  : (isTablet ? 2 : 1),
                                          childAspectRatio: 0.75,
                                          crossAxisSpacing: isDesktop ? 25 : 15,
                                          mainAxisSpacing: isDesktop ? 25 : 15,
                                        ),
                                    itemCount: filteredServices.length,
                                    itemBuilder: (context, index) {
                                      final service = filteredServices[index];
                                      return _buildServiceCard(service, index);
                                    },
                                  ),
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildPageItem(icon: Icons.chevron_left),
                                      _buildPageItem(text: "1", isActive: true),
                                      _buildPageItem(text: "2"),
                                      if (!isMobile) ...[
                                        _buildPageItem(text: "3"),
                                        _buildPageItem(text: "4"),
                                      ],
                                      _buildPageItem(icon: Icons.chevron_right),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          isMobile
              ? Builder(
                builder:
                    (context) => FloatingActionButton(
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.filter_list),
                    ),
              )
              : null,
    );
  }
}
