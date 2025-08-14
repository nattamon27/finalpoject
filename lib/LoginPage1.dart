import 'package:appfinal/homepage6.2.dart';
import 'package:appfinal/RegistrationSelectionPage2.dart';
import 'package:appfinal/DashboardPage18.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart';

class LoginPage1 extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage1> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final supabase = SupabaseManager.client;

  bool _obscureText = true;
  bool _rememberMe = false;
  bool _loading = false;

  Future<void> _login() async {
    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('กรุณากรอกอีเมลและรหัสผ่าน');
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      // ล็อกอินด้วย Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _showError('อีเมลหรือรหัสผ่านไม่ถูกต้อง');
        setState(() {
          _loading = false;
        });
        return;
      }

      final userId = response.user!.id;
      print('Debug: Logged in userId = $userId');

      // อัปเดต last_active_at และ status เป็น active ทุกครั้งที่ล็อกอินสำเร็จ
      await supabase
          .from('users')
          .update({
            'last_active_at': DateTime.now().toIso8601String(),
            'status': 'active',
          })
          .eq('user_id', userId);

      // ดึงข้อมูล user_type จากตาราง users โดยใช้ user_id ที่ได้จาก Auth
      final userData =
          await supabase
              .from('users')
              .select('user_type')
              .eq('user_id', userId)
              .maybeSingle();

      if (userData == null) {
        _showError('ไม่พบข้อมูลผู้ใช้ในระบบ');
        print('Debug: userData is null for userId = $userId');
        setState(() {
          _loading = false;
        });
        return;
      }

      final role = userData['user_type'] as String? ?? '';
      print('Debug: user role = $role');

      setState(() {
        _loading = false;
      });

      // นำทางไปหน้าตามบทบาท
      if (role.toLowerCase() == 'farmer' || role == 'ชาวนา') {
        print('Debug: Navigating to homepage6.2');
        Navigator.pushReplacementNamed(context, '/homepage6.2');
      } else if (role.toLowerCase() == 'renter' || role == 'ผู้ให้เช่า') {
        print('Debug: Navigating to dashboard');
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        _showError('บทบาทผู้ใช้ไม่ถูกต้อง');
        print('Debug: Invalid user role: $role');
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: ${e.toString()}');
      print('Debug: Exception caught: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
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
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'lib/assets/IMG_4118 2.jpg',
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'เข้าสู่ระบบ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        hintText: 'กรอกอีเมล',
                        filled: true,
                        fillColor: Colors.orange[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscureText,
                      maxLength: 15, // จำกัดความยาวรหัสผ่านไม่เกิน 15 ตัว
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        hintText: 'รหัสผ่าน',
                        filled: true,
                        fillColor: Colors.orange[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                        counterText: '', // ซ่อนตัวนับจำนวนตัวอักษร
                      ),
                    ),
                    SizedBox(height: 20),
                    _loading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        text: 'ยังไม่มีบัญชีใช่ไหม? ',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                        children: [
                          TextSpan(
                            text: 'ลงทะเบียน',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                RegistrationSelectionPage2(),
                                      ),
                                    );
                                  },
                          ),
                        ],
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
