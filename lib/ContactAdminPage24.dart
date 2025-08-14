import 'package:appfinal/AgriVehicleManagementPage21.dart';
import 'package:appfinal/BookingPage20.dart';
import 'package:appfinal/DashboardPage18.dart';
import 'package:appfinal/LoginPage1.dart';
import 'package:appfinal/ProfilePage22.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:appfinal/app_sidebar.dart'; // สมมติว่ามีไฟล์นี้อยู่ในโปรเจค
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactAdminPage2 extends StatefulWidget {
  @override
  _ContactAdminPageState createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage2> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 6; // สมมติเมนู ContactAdmin อยู่ index 6 หรือปรับตามจริง

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  Map<String, dynamic>? userProfile;
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final supabase = Supabase.instance.client;
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
              .select('user_id, full_name, user_type, profile_image_url, phone')
              .eq('user_id', user.id)
              .single();

      setState(() {
        userProfile = response;
        _nameController.text = userProfile?['full_name'] ?? '';
        _emailController.text =
            user.email ??
            ''; // ถ้าต้องการดึงอีเมลจาก user.email สามารถตั้งค่าได้ที่นี่
        _phoneController.text = userProfile?['phone'] ?? ''; // เพิ่มบรรทัดนี้
        _isUserLoading = false;
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() {
        _isUserLoading = false;
      });
    }
  }

  void _onMenuSelected(int index) {
    if (index == _selectedIndex) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BookingPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AgriVehicleManagementPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage()),
        );
        break;
      case 6:
        // อยู่หน้า ContactAdmin อยู่แล้ว
        break;
      case 5:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage1()),
        );
        break;
      default:
        break;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final supabase = Supabase.instance.client;

      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนส่งข้อความ')),
          );
          return;
        }

        await supabase.from('contactmessages').insert({
          'user_id': userId,
          'subject': _subjectController.text,
          'message': _messageController.text,
        });

        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('ส่งข้อความเรียบร้อย'),
                content: const Text('ขอบคุณที่ติดต่อผู้ดูแลระบบ'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _formKey.currentState!.reset();
                      _phoneController.clear();
                      _subjectController.clear();
                      _messageController.clear();
                    },
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isUserLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppSidebar(
        selectedIndex: _selectedIndex,
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
          icon: Icon(Icons.menu, color: Colors.grey[700]),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'ติดต่อผู้ดูแลระบบ',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 24),
              ],
            ),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool singleColumn = constraints.maxWidth < 600;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        runSpacing: 25,
                        spacing: 40,
                        children: [
                          SizedBox(
                            width:
                                singleColumn
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 40) / 2,
                            child: _buildTextField(
                              label: 'ชื่อ-นามสกุล',
                              controller: _nameController,
                              hintText: 'กรอกชื่อของคุณ',
                              validator:
                                  (v) =>
                                      v == null || v.isEmpty
                                          ? 'กรุณากรอกชื่อ-นามสกุล'
                                          : null,
                              enabled:
                                  false, // ปิดไม่ให้แก้ไขชื่อที่ดึงมาจากโปรไฟล์
                            ),
                          ),
                          SizedBox(
                            width:
                                singleColumn
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 40) / 2,
                            child: _buildTextField(
                              label: 'อีเมล',
                              controller: _emailController,
                              hintText: 'example@email.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'กรุณากรอกอีเมล';
                                final emailRegex = RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                );
                                if (!emailRegex.hasMatch(v))
                                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                                return null;
                              },
                              enabled: false,
                            ),
                          ),
                          SizedBox(
                            width:
                                singleColumn
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 40) / 2,
                            child: _buildTextField(
                              label: 'เบอร์โทรศัพท์ (ถ้ามี)',
                              controller: _phoneController,
                              hintText: '081-234-5678',
                              keyboardType: TextInputType.phone,
                              validator: (v) => null,
                              enabled: false,
                            ),
                          ),
                          SizedBox(
                            width:
                                singleColumn
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 40) / 2,
                            child: _buildTextField(
                              label: 'หัวข้อ',
                              controller: _subjectController,
                              hintText: 'หัวข้อเรื่องที่ติดต่อ',
                              validator:
                                  (v) =>
                                      v == null || v.isEmpty
                                          ? 'กรุณากรอกหัวข้อ'
                                          : null,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _buildTextField(
                              label: 'ข้อความ',
                              controller: _messageController,
                              hintText: 'พิมพ์ข้อความที่ต้องการติดต่อ...',
                              maxLines: 6,
                              validator:
                                  (v) =>
                                      v == null || v.isEmpty
                                          ? 'กรุณากรอกข้อความ'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                31,
                                138,
                                35,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              minimumSize: const Size(140, 48),
                            ),
                            child: const Text(
                              'ส่งข้อความ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF34495e),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFbdc3c7), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2980b9), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
