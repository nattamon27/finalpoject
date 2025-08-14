import 'package:appfinal/RegistrationPage3.dart';
import 'package:appfinal/RegistrationPage4.dart';
import 'package:flutter/material.dart';

class RegistrationSelectionPage2 extends StatelessWidget {
  const RegistrationSelectionPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // White Card
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(30),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    // Logo
                    Center(
                      child: ClipOval(
                        child: Image.asset(
                          'lib/assets/IMG_4118 2.jpg',
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Center(
                      child: Text(
                        'เลือกวิธีการสมัคร',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Farmer Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      RegistrationPage3(userType: 'farmer'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[400],
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 40,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'สมัคร ชาวนา',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Landlord Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      RegistrationPage4(userType: 'renter'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 40,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'สมัคร ผู้ให้เช่า',
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
