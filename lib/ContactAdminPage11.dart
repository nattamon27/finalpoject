import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactAdminPage extends StatefulWidget {
  const ContactAdminPage({super.key});

  @override
  State<ContactAdminPage> createState() => _ContactAdminPageState();
}

class _ContactAdminPageState extends State<ContactAdminPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      print('No user is currently logged in.');
      return;
    }

    try {
      final data =
          await supabase
              .from('users') // ตรวจสอบให้แน่ใจว่าชื่อตารางคือ 'users'
              .select('username, email, phone')
              .eq('user_id', userId)
              .maybeSingle(); // ใช้ maybeSingle หรือ getSingle สำหรับ Supabase SDK ใหม่

      if (data != null) {
        setState(() {
          _nameController.text =
              data['username'] ?? ''; // ชื่อ field ต้องตรงกับ select
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
        });
      } else {
        print('No user data found');
      }
    } catch (error) {
      print('Error loading user data: $error');
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

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
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
                              enabled: false,
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
