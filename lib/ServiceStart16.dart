import 'package:appfinal/LoginPage1.dart';
import 'package:flutter/material.dart';

class Servicestart extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const Servicestart({Key? key, required this.vehicle}) : super(key: key);

  @override
  _ServicestartState createState() => _ServicestartState();
}

class _ServicestartState extends State<Servicestart> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    // สีหลักตามไฟล์ CSS
    const primaryColor = Color.fromRGBO(16, 104, 63, 1);
    const primaryLight = Color(0xFFB2DFDB);
    const primaryDark = Color(0xFF004D40);
    const accentColor = Color(0xFFFF6E40);
    const textSecondary = Color(0xFF757575);

    final vehicle = widget.vehicle;

    // ดึงข้อมูลรูปภาพจาก vehicleimages และเรียงรูปหลักไว้ก่อน
    final List vehicleImages = vehicle['vehicleimages'] ?? [];
    final List sortedImages = [
      ...vehicleImages.where((img) => img['is_main_image'] == true),
      ...vehicleImages.where((img) => img['is_main_image'] != true),
    ];

    // ดึงข้อมูลฟีเจอร์จาก vehiclefeatures (embed relationship)
    final List vehicleFeatures = vehicle['vehiclefeatures'] ?? [];
    // ดึงชื่อฟีเจอร์จาก embed features (สมมติชื่อคอลัมน์ feature_name)
    final List<String> featureNames =
        vehicleFeatures
            .map<String>((vf) {
              final feature = vf['features'];
              return feature != null ? (feature['feature_name'] ?? '') : '';
            })
            .where((name) => name.isNotEmpty)
            .toList();

    // ดึงข้อมูลอื่นๆ
    final String vehicleName = vehicle['vehicle_name'] ?? 'ไม่ระบุชื่อ';
    final int pricePerDay = vehicle['price_per_day'] ?? 0;
    final String location = vehicle['location'] ?? '';
    final String vehicleType = vehicle['vehicle_type'] ?? '';
    final bool isAvailable = vehicle['is_available'] ?? false;
    final String availability =
        isAvailable ? 'พร้อมให้บริการ' : 'ไม่พร้อมให้บริการ';

    final String serviceDetails = vehicle['service_details'] ?? '';

    final int serviceCapacity = vehicle['service_capacity'] ?? 0;

    final Map<String, dynamic>? user = vehicle['fk_vehicles_renter'];
    final String providerName =
        user != null && user['full_name'] != null
            ? user['full_name']
            : 'ไม่ทราบชื่อผู้ให้บริการ';

    final String status = (vehicle['status'] ?? '').toString().toLowerCase();
    final bool isOnline = status == 'active';
    final String providerStatusText = isOnline ? 'ออนไลน์' : 'ออฟไลน์';
    final Color providerStatusColor = isOnline ? Colors.green : Colors.red;

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
                  // รูปภาพสไลด์เลื่อน
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: SizedBox(
                      height: 400,
                      child: Stack(
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
                                  sortedImages[index]['image_url'] ?? '';
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
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 100,
                                      ),
                                    ),
                              );
                            },
                          ),
                          // Indicator dots
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                sortedImages.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: _currentImageIndex == index ? 12 : 8,
                                  height: _currentImageIndex == index ? 12 : 8,
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

                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ราคา สถานะ และฟีเจอร์
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      36,
                                      88,
                                      50,
                                    ),
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

                            // แสดงฟีเจอร์เป็นกล่องเล็ก ๆ ด้านล่างแถวราคา
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
                          ],
                        ),

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
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ติดต่อผู้ให้บริการ'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.phone),
                                label: const Text('ติดต่อ'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    46,
                                    120,
                                    85,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 20,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
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

                        _buildDetailRow(
                          icon: Icons.star,
                          label: 'คะแนน',
                          valueWidget: Row(
                            children: const [
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              Icon(
                                Icons.star_half,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('4.5/5'),
                              SizedBox(width: 8),
                              Text(
                                '(จาก 28 รีวิว)',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildDetailRow(
                          icon: Icons.agriculture,
                          label: 'ประเภทการบริการ',
                          value: vehicleType,
                        ),

                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: 'วันที่ให้บริการ',
                          value: 'รอข้อมูลวันที่ให้บริการ',
                        ),

                        _buildDetailRow(
                          icon: Icons.location_on,
                          label: 'พื้นที่ให้บริการ',
                          value: location,
                        ),

                        _buildDetailRow(
                          icon: Icons.grass,
                          label: 'รายละเอียดการให้บริการ',
                          value: serviceDetails,
                        ),

                        const SizedBox(height: 30),

                        // ปุ่มแก้ไขและยืนยัน
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoginPage1(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  color: primaryColor,
                                ),
                                label: const Text(
                                  'แก้ไขการจอง',
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
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoginPage1(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('ยืนยันการจอง'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ศูนย์ช่วยเหลือ\nหากต้องการความช่วยเหลือเพิ่มเติม กรุณาติดต่อ 099-999-9999',
              ),
            ),
          );
        },
        child: const Icon(Icons.question_mark),
        tooltip: 'ช่วยเหลือ',
      ),
    );
  }

  // ฟังก์ชันช่วยสร้างแถวรายละเอียด
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

  // ฟังก์ชันช่วยสร้าง widget แสดงฟีเจอร์
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
