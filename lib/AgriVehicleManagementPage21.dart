import 'package:appfinal/AddAgriculturalVehiclePage19.dart';
import 'package:appfinal/BookingPage20.dart';
import 'package:appfinal/ContactAdminPage24.dart';
import 'package:appfinal/DashboardPage18.dart';
import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/ProfilePage22.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_sidebar.dart';

class AgriVehicleManagementPage extends StatefulWidget {
  const AgriVehicleManagementPage({Key? key}) : super(key: key);

  @override
  State<AgriVehicleManagementPage> createState() =>
      _AgriVehicleManagementPageState();
}

class _AgriVehicleManagementPageState extends State<AgriVehicleManagementPage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> vehicles = [];
  bool _isLoading = true;

  Map<String, dynamic>? userProfile;
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchVehicles();
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

  Future<void> _fetchVehicles() async {
    setState(() {
      _isLoading = true;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        vehicles = [];
        _isLoading = false;
      });
      return;
    }

    try {
      var query = supabase.from('vehicles').select('''
        vehicle_id,
        vehicle_name,
        vehicle_type,
        description,
        price_per_day,
        status,
        location,
        service_capacity,
        is_available,
        is_published,
        vehicleimages!fk_vehicleimages_vehicle(image_url),
        vehiclefeatures!fk_vehiclefeatures_vehicle(
          features!fk_vehiclefeatures_feature(feature_name)
        )
      ''');

      query = query.eq('renter_id', user.id);
      query.order('vehicle_id', ascending: false);
      query.limit(50);

      final response = await query;

      if (response != null && response is List) {
        setState(() {
          vehicles =
              response.map<Map<String, dynamic>>((e) {
                final map = Map<String, dynamic>.from(e);
                map['vehicleimages'] = map['vehicleimages'] ?? [];
                map['vehiclefeatures'] = map['vehiclefeatures'] ?? [];

                final status = map['status']?.toString().toLowerCase() ?? '';
                if (status == 'active') {
                  map['status'] = 'พร้อมใช้งาน';
                } else if (status == 'inactive') {
                  map['status'] = 'ไม่พร้อมใช้งาน';
                } else {
                  map['status'] = 'พร้อมใช้งาน';
                }

                return map;
              }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          vehicles = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching vehicles: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    // 1. กำหนดสถานะ booking ที่ถือว่า active จริงๆ
    final activeStatuses = ['pending', 'confirmed', 'waiting_farmer_confirm'];
    final orStatus = activeStatuses.map((s) => 'status.eq.$s').join(',');

    // 2. ตรวจสอบว่ามี booking ที่ active หรือไม่
    try {
      final bookings = await supabase
          .from('bookings')
          .select('booking_id')
          .eq('vehicle_id', vehicleId)
          .or(orStatus);

      // 3. ถ้ามี booking ที่ active ห้ามลบ
      if (bookings != null && bookings is List && bookings.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถลบพาหนะนี้ได้ เนื่องจากมีการจองที่ยังไม่เสร็จสิ้นหรือยังไม่ถูกยกเลิก',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการตรวจสอบการจอง: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. ถ้าไม่มี booking ที่ active ให้แสดง dialog ยืนยันการลบ
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบรถเกษตรคันนี้?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await supabase.from('bookings').delete().eq('vehicle_id', vehicleId);
      try {
        final deleted =
            await supabase
                .from('vehicles')
                .delete()
                .eq('vehicle_id', vehicleId)
                .select();

        if (deleted.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบรถเกษตรเรียบร้อยแล้ว')),
          );
          _fetchVehicles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบข้อมูลรถหรือไม่สามารถลบได้')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  void openNewServiceModal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAgriculturalVehiclePage()),
    ).then((value) {
      if (value == true) {
        _fetchVehicles();
      }
    });
  }

  void openViewServiceModal(Map<String, dynamic> vehicle) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'รายละเอียดรถเกษตร',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child:
                          (vehicle['vehicleimages'] != null &&
                                  vehicle['vehicleimages'].isNotEmpty)
                              ? SizedBox(
                                height: 200,
                                child: PageView.builder(
                                  itemCount: vehicle['vehicleimages'].length,
                                  itemBuilder: (context, index) {
                                    final img =
                                        vehicle['vehicleimages'][index]['image_url'];
                                    return img.toString().startsWith('http')
                                        ? Image.network(
                                          img,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          width: double.infinity,
                                          height: 200,
                                          color: Colors.grey.shade300,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                        );
                                  },
                                ),
                              )
                              : Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              vehicle['vehicle_name'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (vehicle['status'] == 'พร้อมใช้งาน'
                                      ? Colors.green
                                      : vehicle['status'] == 'ไม่พร้อมใช้งาน'
                                      ? Colors.red
                                      : Colors.orange)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              vehicle['status'] ?? '-',
                              style: TextStyle(
                                color:
                                    vehicle['status'] == 'พร้อมใช้งาน'
                                        ? Colors.green
                                        : vehicle['status'] == 'ไม่พร้อมใช้งาน'
                                        ? Colors.red
                                        : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'สถานที่จัดเก็บ: ${vehicle['location'] ?? '-'}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ราคา: ฿${vehicle['price_per_day'] ?? '-'} / ชั่วโมง',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vehicle['description'] ?? '-',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    if (vehicle['vehiclefeatures'] != null &&
                        (vehicle['vehiclefeatures'] as List).isNotEmpty) ...[
                      const Text(
                        'คุณสมบัติ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            (vehicle['vehiclefeatures'] as List).map<Widget>((
                              vf,
                            ) {
                              final feature = vf['features'];
                              final featureName =
                                  feature != null
                                      ? feature['feature_name'] ?? ''
                                      : '';
                              return Chip(
                                label: Text(featureName),
                                backgroundColor: Colors.green.shade100,
                              );
                            }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
          ),
    );
  }

  void openEditVehicleModal(Map<String, dynamic> vehicle) {
    final _priceController = TextEditingController(
      text: vehicle['price_per_day']?.toString() ?? '',
    );

    String status = 'พร้อมใช้งาน';
    final rawStatus = vehicle['status']?.toString().toLowerCase() ?? '';
    if (rawStatus == 'active' || rawStatus == 'พร้อมใช้งาน') {
      status = 'พร้อมใช้งาน';
    } else if (rawStatus == 'inactive' || rawStatus == 'ไม่พร้อมใช้งาน') {
      status = 'ไม่พร้อมใช้งาน';
    } else {
      status = 'พร้อมใช้งาน';
    }

    bool isAvailable = vehicle['is_available'] ?? true;
    bool isPublished = vehicle['is_published'] ?? false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('แก้ไขข้อมูลรถเกษตร'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ราคา (บาท/ชั่วโมง) *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(
                              value: 'พร้อมใช้งาน',
                              child: Text('พร้อมใช้งาน'),
                            ),
                            DropdownMenuItem(
                              value: 'ไม่พร้อมใช้งาน',
                              child: Text('ไม่พร้อมใช้งาน'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => status = val);
                          },
                          decoration: const InputDecoration(labelText: 'สถานะ'),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          title: const Text('อนุญาตการจอง'),
                          value: isAvailable,
                          onChanged: (val) {
                            if (val != null) setState(() => isAvailable = val);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          title: const Text('เผยแพร่'),
                          value: isPublished,
                          onChanged: (val) {
                            if (val != null) setState(() => isPublished = val);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(_priceController.text);
                        if (price == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('กรุณากรอกราคาที่ถูกต้อง'),
                            ),
                          );
                          return;
                        }

                        String dbStatus = 'active';
                        if (status == 'พร้อมใช้งาน') {
                          dbStatus = 'active';
                        } else if (status == 'ไม่พร้อมใช้งาน') {
                          dbStatus = 'inactive';
                        }

                        try {
                          final updates = {
                            'price_per_day': price,
                            'status': dbStatus,
                            'is_available': isAvailable,
                            'is_published': isPublished,
                          };

                          final response =
                              await supabase
                                  .from('vehicles')
                                  .update(updates)
                                  .eq('vehicle_id', vehicle['vehicle_id'])
                                  .select();

                          if (response != null &&
                              (response as List).isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('แก้ไขข้อมูลเรียบร้อยแล้ว'),
                              ),
                            );
                            Navigator.pop(context);
                            _fetchVehicles();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ไม่สามารถแก้ไขข้อมูลได้'),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                          );
                        }
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget buildVehicleCard(Map<String, dynamic> vehicle) {
    final List<dynamic> images = vehicle['vehicleimages'] ?? [];
    final List<dynamic> features = vehicle['vehiclefeatures'] ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child:
                images.isNotEmpty
                    ? PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final imgUrl = images[index]['image_url'] ?? '';
                        return imgUrl.toString().startsWith('http')
                            ? Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                            : Container(
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                      },
                    )
                    : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey,
                        ),
                      ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              vehicle['vehicle_name'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              vehicle['description'] ?? '',
              style: TextStyle(color: Colors.grey.shade700),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ราคา: ฿${vehicle['price_per_day'] ?? '-'} / ชั่วโมง',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children:
                  features.map<Widget>((vf) {
                    final feature = vf['features'];
                    final featureName =
                        feature != null ? feature['feature_name'] ?? '' : '';
                    return Chip(
                      label: Text(featureName),
                      backgroundColor: Colors.green.shade100,
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'สถานะ: ${vehicle['status'] ?? '-'}',
              style: TextStyle(
                color:
                    vehicle['status'] == 'พร้อมใช้งาน'
                        ? Colors.green
                        : vehicle['status'] == 'ไม่พร้อมใช้งาน'
                        ? Colors.red
                        : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ความจุ: ${vehicle['service_capacity'] ?? '-'}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'สถานที่: ${vehicle['location'] ?? '-'}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye, color: Colors.green),
                  tooltip: 'ดูรายละเอียด',
                  onPressed: () => openViewServiceModal(vehicle),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'แก้ไขข้อมูล',
                  onPressed: () => openEditVehicleModal(vehicle),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'ลบรถเกษตร',
                  onPressed: () => deleteVehicle(vehicle['vehicle_id']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _onMenuSelected(int index) {
    Navigator.pop(context);
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BookingPage()),
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

  @override
  Widget build(BuildContext context) {
    if (_isUserLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppSidebar(
        selectedIndex: 2,
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
        title: const Text(
          'การจัดการรถเกษตร',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard, color: Colors.grey),
            tooltip: 'หน้า Dashboard',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => DashboardPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.book_online, color: Colors.grey),
            tooltip: 'หน้า Booking',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BookingPage()),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'จัดการรถเกษตร',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'จัดการและปรับแต่งรถเกษตรทั้งหมดในระบบ',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: openNewServiceModal,
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มรถเกษตรใหม่'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 1;
                        if (constraints.maxWidth >= 1024) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth >= 768) {
                          crossAxisCount = 2;
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: vehicles.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3 / 4,
                              ),
                          itemBuilder: (context, index) {
                            final vehicle = vehicles[index];
                            return buildVehicleCard(vehicle);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {},
                            child: const Icon(Icons.chevron_left),
                          ),
                          for (int i = 1; i <= 5; i++)
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    i == 1
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: i == 1 ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
    );
  }
}
