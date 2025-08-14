import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart';

class RegistrationPage4 extends StatefulWidget {
  final String userType;

  RegistrationPage4({required this.userType});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage4> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final supabase = SupabaseManager.client;
  bool _loading = false;

  List<Map<String, dynamic>> _provinces = [];
  String? _selectedProvinceId;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    try {
      final response = await supabase
          .from('provinces')
          .select('province_id, province_name');

      setState(() {
        _provinces = List<Map<String, dynamic>>.from(response);
      });
    } catch (error) {
      print('Error loading provinces: $error');
      _showErrorDialog('ไม่สามารถโหลดรายชื่อจังหวัดได้');
    }
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^[0-9]{10}$').hasMatch(phone);
  }

  void _handleRegistration() {
    String username = _usernameController.text.trim();
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();
    String address = _addressController.text.trim();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty ||
        name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        _selectedProvinceId == null) {
      _showErrorDialog('กรุณากรอกข้อมูลให้ครบทุกช่องและเลือกจังหวัด');
      return;
    }

    if (!isValidEmail(email)) {
      _showErrorDialog('กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    if (!isValidPhone(phone)) {
      _showErrorDialog('กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง (10 หลัก)');
      return;
    }

    if (password.length < 6) {
      _showErrorDialog('รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร');
      return;
    }

    if (password.length > 15) {
      _showErrorDialog('รหัสผ่านต้องไม่เกิน 15 ตัวอักษร');
      return;
    }

    if (confirmPassword.length > 15) {
      _showErrorDialog('การยืนยันรหัสผ่านต้องไม่เกิน 15 ตัวอักษร');
      return;
    }

    if (password != confirmPassword) {
      _showErrorDialog('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ยืนยันการสมัครสมาชิก'),
          content: Text('คุณต้องการสมัครสมาชิกใช่หรือไม่?'),
          actions: [
            TextButton(
              child: Text('ยกเลิก'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('ยืนยัน'),
              onPressed: () {
                Navigator.pop(context);
                _registerWithSupabase(
                  username,
                  name,
                  email,
                  phone,
                  address,
                  _selectedProvinceId!,
                  password,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerWithSupabase(
    String username,
    String fullName,
    String email,
    String phone,
    String address,
    String provinceId,
    String password,
  ) async {
    setState(() {
      _loading = true;
    });

    try {
      final existingUsers = await supabase
          .from('users')
          .select('username, email')
          .or('username.eq.$username,email.eq.$email');

      if (existingUsers.isNotEmpty) {
        throw Exception('ชื่อผู้ใช้หรืออีเมลถูกใช้งานแล้ว');
      }

      final signUpResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = signUpResponse.user;
      if (user == null) {
        throw Exception('ไม่สามารถสร้างผู้ใช้ได้');
      }

      final userId = user.id;

      await supabase.from('users').insert({
        'user_id': userId,
        'username': username,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'user_type': widget.userType,
        'province_id': provinceId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(Duration(seconds: 2), () {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    } catch (e) {
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('แจ้งเตือน'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('ตกลง'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      filled: true,
      fillColor: Colors.orange[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  InputDecoration _inputDecorationWithToggle(
    String hint,
    IconData icon,
    bool obscure,
    VoidCallback toggle,
  ) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      filled: true,
      fillColor: Colors.orange[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: toggle,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'ลงทะเบียน',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'สร้างบัญชีใหม่ของคุณ',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _usernameController,
                      decoration: _inputDecoration('ชื่อผู้ใช้', Icons.person),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration('ชื่อ-สกุล', Icons.person),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration('กรอกอีเมล', Icons.email),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _phoneController,
                      decoration: _inputDecoration(
                        'เบอร์โทรศัพท์',
                        Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'เลือกจังหวัด',
                        filled: true,
                        fillColor: Colors.orange[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedProvinceId,
                      items:
                          _provinces.map((province) {
                            return DropdownMenuItem<String>(
                              value: province['province_id'].toString(),
                              child: Text(province['province_name']),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProvinceId = value;
                        });
                      },
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _addressController,
                      decoration: _inputDecoration('ที่อยู่', Icons.home),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      maxLength: 15, // จำกัดความยาวรหัสผ่านไม่เกิน 15 ตัว
                      decoration: _inputDecorationWithToggle(
                        'กรอกรหัสผ่าน',
                        Icons.lock,
                        _obscurePassword,
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ).copyWith(counterText: ''), // ซ่อนตัวนับจำนวนตัวอักษร
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      maxLength: 15, // จำกัดความยาวยืนยันรหัสผ่านไม่เกิน 15 ตัว
                      decoration: _inputDecorationWithToggle(
                        'กรอกยืนยันรหัสผ่าน',
                        Icons.lock,
                        _obscureConfirmPassword,
                        () => setState(
                          () =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                        ),
                      ).copyWith(counterText: ''), // ซ่อนตัวนับจำนวนตัวอักษร
                    ),
                    SizedBox(height: 20),
                    Center(
                      child:
                          _loading
                              ? CircularProgressIndicator()
                              : ElevatedButton(
                                onPressed: _handleRegistration,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 40,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  'สมัครผู้ให้เช่า',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
