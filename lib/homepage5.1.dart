import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/RegistrationSelectionPage2.dart';
import 'package:appfinal/ServiceDetailPage8.dart';
import 'package:appfinal/ServiceStart16.dart'; // เพิ่ม import หน้า Servicestart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart'; // ปรับตามที่คุณตั้งค่า Supabase client

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = SupabaseManager.client;

  TextEditingController searchController = TextEditingController();
  TextEditingController dateRangeController = TextEditingController();
  TextEditingController raiController = TextEditingController();
  TextEditingController vehicleController = TextEditingController();

  DateTimeRange? selectedDateRange;
  String selectedServiceType = 'รถเกี่ยวข้าว';
  int selectedNavIndex = 0;

  Map<String, bool> hoverStates = {
    'การแจ้งเตือน': false,
    'ติดต่อเรา': false,
    'เข้าสู่ระบบ': false,
    'สมัครสมาชิก': false,
  };

  final List<String> serviceTypes = [
    'รถเกี่ยวข้าว',
    'รถไถนา',
    'รถปลูกข้าว',
    'รถพ่นยา',
    'รถขนส่ง',
    'แรงงานเกษตร',
  ];

  final DateFormat dateFormat = DateFormat('d MMM yyyy', 'th');

  List<Map<String, dynamic>> provinces = [];
  List<Map<String, dynamic>> vehicles = [];

  bool isLoadingProvinces = true;
  bool isLoadingVehicles = true;

  String? _vehiclesError; // เก็บข้อความ error กรณีดึงข้อมูลไม่สำเร็จ

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDateRange = DateTimeRange(
      start: now,
      end: now.add(Duration(days: 1)),
    );
    _updateDateRangeText();
    raiController.text = "";
    vehicleController.text = "";
    _fetchProvinces();
    _fetchVehicles();
  }

  void _updateDateRangeText() {
    if (selectedDateRange != null) {
      dateRangeController.text =
          '${dateFormat.format(selectedDateRange!.start)} - ${dateFormat.format(selectedDateRange!.end)}';
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
    } catch (e) {
      provinces = [];
      print('Error fetching provinces: $e');
    }
    setState(() => isLoadingProvinces = false);
  }

  Future<void> _fetchVehicles() async {
    setState(() {
      isLoadingVehicles = true;
      vehicles = [];
      _vehiclesError = null;
    });
    try {
      final response = await supabase
          .from('vehicles')
          .select('''
          vehicle_id, vehicle_name, price_per_day, location, description, service_details, service_capacity, status, vehicle_type, is_published, is_available, province_id,
          vehicleimages!fk_vehicleimages_vehicle (image_url, is_main_image),
          fk_vehicles_renter (full_name),
vehiclefeatures!vehiclefeatures_vehicle_id_fkey (
  feature_id,
  features!vehiclefeatures_feature_id_fkey (feature_name)
)
        ''')
          .eq('is_published', true)
          .eq('is_available', true)
          .order('vehicle_name');
      vehicles = (response as List).cast<Map<String, dynamic>>();
    } catch (e, stacktrace) {
      vehicles = [];
      _vehiclesError = e.toString();
      print('Error fetching vehicles: $e');
      print(stacktrace);
    }
    setState(() => isLoadingVehicles = false);
  }

  Map<String, int> _countVehiclesByProvince() {
    Map<String, int> counts = {};
    for (var vehicle in vehicles) {
      final provinceId = vehicle['province_id']?.toString();
      if (provinceId != null) {
        counts[provinceId] = (counts[provinceId] ?? 0) + 1;
      }
    }
    return counts;
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType) {
      case 'รถเกี่ยวข้าว':
        return Icons.agriculture;
      case 'รถไถนา':
        return Icons.agriculture;
      case 'รถปลูกข้าว':
        return Icons.grass;
      case 'รถพ่นยา':
        return Icons.water_drop;
      case 'รถขนส่ง':
        return Icons.local_shipping;
      case 'แรงงานเกษตร':
        return Icons.people;
      default:
        return Icons.agriculture;
    }
  }

  void _showServiceTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('เลือกประเภทบริการ'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: serviceTypes.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(serviceTypes[index]),
                  leading: Icon(
                    _getServiceIcon(serviceTypes[index]),
                    color: Color(0xFF2A7D43),
                  ),
                  selected: selectedServiceType == serviceTypes[index],
                  selectedTileColor: Colors.green.withOpacity(0.1),
                  onTap: () {
                    setState(() {
                      selectedServiceType = serviceTypes[index];
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เลือกบริการ: ${serviceTypes[index]}'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    _fetchVehicles();
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
      builder: (BuildContext context, Widget? child) {
        return Theme(
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
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        selectedDateRange = newDateRange;
        _updateDateRangeText();
      });
      _fetchVehicles();
    }
  }

  void _navigateToLoginPage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กำลังนำทางไปยังหน้าเข้าสู่ระบบ'),
        duration: Duration(milliseconds: 800),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage1()),
    );
  }

  void _navigateToRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrationSelectionPage2()),
    );
  }

  void _navigateToSearchResults() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'กำลังค้นหา ${selectedServiceType} ในพื้นที่ ${searchController.text}',
        ),
        duration: Duration(milliseconds: 800),
      ),
    );
    _navigateToPage(
      'ผลการค้นหา ${selectedServiceType}',
      _getServiceIcon(selectedServiceType),
    );
  }

  void _navigateToPage(String pageName, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage1()),
    );
  }

  Widget _buildNavItem(String text, int index, IconData icon) {
    bool isSelected = selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          selectedNavIndex = index;
        });
        if (index != 0) {
          _navigateToPage(text, icon);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border:
              isSelected
                  ? Border(bottom: BorderSide(color: Colors.white, width: 2.0))
                  : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData? icon,
    String text,
    Color iconColor,
    VoidCallback onTap,
    String key,
  ) {
    return MouseRegion(
      onEnter: (_) => setState(() => hoverStates[key] = true),
      onExit: (_) => setState(() => hoverStates[key] = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border:
                  hoverStates[key] == true
                      ? Border(
                        bottom: BorderSide(color: Colors.white, width: 1.0),
                      )
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    color: iconColor,
                    size: hoverStates[key] == true ? 18 : 16,
                  ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight:
                          hoverStates[key] == true
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationCard(String imageUrl, String name, int vehicleCount) {
    return InkWell(
      onTap: () {
        _navigateToPage('จังหวัด $name', Icons.location_city);
      },
      child: Container(
        margin: EdgeInsets.only(right: 15),
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  imageUrl.isNotEmpty
                      ? Image.network(
                        imageUrl,
                        height: 120,
                        width: 160,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => Container(
                              height: 120,
                              width: 160,
                              color: Colors.grey[300],
                              child: Icon(Icons.image_not_supported, size: 40),
                            ),
                      )
                      : Container(
                        height: 120,
                        width: 160,
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported, size: 40),
                      ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
            Text('$vehicleCount', style: TextStyle(color: Colors.grey)),
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
    VoidCallback onTap, // เพิ่ม onTap
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 15),
        constraints: BoxConstraints(maxWidth: 280),
        child: Card(
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                child:
                    imageUrl != null
                        ? Image.network(
                          imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  _buildPlaceholderImage(),
                        )
                        : _buildPlaceholderImage(),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '$rating',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      service,
                      style: TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      availability,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '$price บ. /ชั่วโมง',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.agriculture, size: 50, color: Colors.grey[400]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicleCounts = _countVehiclesByProvince();

    return Scaffold(
      body: Column(
        children: [
          // App Bar
          Container(
            color: Color(0xFF2A7D43),
            height: 70,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'lib/assets/IMG_4118 2.jpg',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.agriculture,
                                color: Color(0xFF2A7D43),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    _buildNavItem('หน้าแรก', 0, Icons.home),
                    SizedBox(width: 16),
                    _buildNavItem('โปรไฟล์', 1, Icons.person),
                  ],
                ),
                Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16),
                    _buildActionButton(
                      Icons.notifications,
                      ' การแจ้งเตือน',
                      Colors.white,
                      () =>
                          _navigateToPage('การแจ้งเตือน', Icons.notifications),
                      'การแจ้งเตือน',
                    ),
                    SizedBox(width: 16),
                    _buildActionButton(
                      Icons.contact_support,
                      'ติดต่อเรา',
                      Colors.white,
                      () => _navigateToPage('ติดต่อเรา', Icons.contact_support),
                      'ติดต่อเรา',
                    ),
                    SizedBox(width: 16),
                    _buildActionButton(
                      Icons.login,
                      'เข้าสู่ระบบ',
                      Colors.white,
                      () => _navigateToLoginPage(),
                      'เข้าสู่ระบบ',
                    ),
                    SizedBox(width: 16),
                    _buildActionButton(
                      Icons.person_add,
                      'สมัครสมาชิก',
                      Colors.white,
                      () => _navigateToRegisterPage(),
                      'สมัครสมาชิก',
                    ),
                  ],
                ),
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
                    height: 300,
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
                              fontSize: 32,
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
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: EdgeInsets.all(20),
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
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: TextField(
                                    controller: searchController,
                                    decoration: InputDecoration(
                                      hintText: 'ใส่จุดหมายปลายทาง',
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Colors.grey,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => _showServiceTypeDialog(context),
                                    icon: Icon(
                                      _getServiceIcon(selectedServiceType),
                                      color: Color(0xFF2A7D43),
                                    ),
                                    label: Flexible(
                                      child: Text(
                                        selectedServiceType.length > 10
                                            ? '${selectedServiceType.substring(0, 10)}...'
                                            : selectedServiceType,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[100],
                                      foregroundColor: Colors.black87,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),
                          Text(
                            'วันเริ่มต้นและวันสิ้นสุด',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          Container(
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
                                  Icon(
                                    Icons.date_range,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      dateRangeController.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
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
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: 200,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _navigateToSearchResults,
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

                  /*    // Provinces Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ประเภทพาหนะยอดนิยมในแต่ละจังหวัด',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        isLoadingProvinces
                            ? Center(child: CircularProgressIndicator())
                            : provinces.isEmpty
                            ? Text('ไม่พบข้อมูลจังหวัด')
                            : SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: provinces.length,
                                itemBuilder: (context, index) {
                                  final province = provinces[index];
                                  return _buildDestinationCard(
                                    province['image_url'] ?? '',
                                    province['province_name'] ?? 'ไม่ระบุชื่อ',
                                    vehicleCounts[province['province_id']
                                            .toString()] ??
                                        0,
                                  );
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
*/
                  // Vehicles Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ประเภทพาหนะที่แนะนำสำหรับท่าน',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        isLoadingVehicles
                            ? Center(child: CircularProgressIndicator())
                            : _vehiclesError != null
                            ? Text(
                              'เกิดข้อผิดพลาดในการโหลดข้อมูลพาหนะ: $_vehiclesError',
                            )
                            : vehicles.isEmpty
                            ? Text('ไม่พบข้อมูลพาหนะ')
                            : SizedBox(
                              height: 320,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: vehicles.length,
                                itemBuilder: (context, index) {
                                  final vehicle = vehicles[index];
                                  double price = 0;
                                  if (vehicle['price_per_day'] != null) {
                                    if (vehicle['price_per_day'] is int) {
                                      price =
                                          (vehicle['price_per_day'] as int)
                                              .toDouble();
                                    } else if (vehicle['price_per_day']
                                        is double) {
                                      price = vehicle['price_per_day'];
                                    } else if (vehicle['price_per_day']
                                        is String) {
                                      price =
                                          double.tryParse(
                                            vehicle['price_per_day'],
                                          ) ??
                                          0;
                                    }
                                  }

                                  // ดึงรูปภาพหลักจากความสัมพันธ์ vehicleimages
                                  String? mainImageUrl;
                                  if (vehicle['vehicleimages'] != null &&
                                      vehicle['vehicleimages'] is List) {
                                    final images =
                                        vehicle['vehicleimages'] as List;
                                    final mainImage = images.firstWhere(
                                      (img) => img['is_main_image'] == true,
                                      orElse:
                                          () =>
                                              images.isNotEmpty
                                                  ? images[0]
                                                  : null,
                                    );
                                    if (mainImage != null) {
                                      mainImageUrl = mainImage['image_url'];
                                    }
                                  }

                                  return _buildEquipmentCard(
                                    mainImageUrl,
                                    vehicle['vehicle_name'] ?? 'ไม่ระบุชื่อ',
                                    4.5,
                                    vehicle['description'] ?? '',
                                    vehicle['location'] ?? '',
                                    'พร้อมใช้งาน',
                                    price.toInt(),
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => Servicestart(
                                                vehicle: vehicle,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
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
}
