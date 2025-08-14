import 'package:appfinal/DashboardPage18.dart';
import 'package:appfinal/homepage5.1.dart';
import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart';
import 'LoginPage1.dart';
import 'RegistrationSelectionPage2.dart';
import 'RegistrationPage3.dart';
import 'RegistrationPage4.dart';
import 'package:intl/date_symbol_data_local.dart'; // <== เพิ่มบรรทัดนี้

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null); // <== เพิ่มบรรทัดนี้
  await SupabaseManager.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/login': (context) => LoginPage1(),
        '/register-selection': (context) => RegistrationSelectionPage2(),
        '/register-farmer': (context) => RegistrationPage3(userType: 'farmer'),
        '/register-landlord':
            (context) => RegistrationPage4(userType: 'landlord'),
        '/homepage6.2': (context) => HomePage6(),
        '/dashboard': (context) => DashboardPage(),
      },
    );
  }
}
