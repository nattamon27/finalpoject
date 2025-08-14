import 'package:appfinal/BookingHistoryPage9.dart';
import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CancelBookingPage extends StatefulWidget {
  final Map<String, dynamic>
  bookingData; // รับข้อมูล booking จากหน้า BookingHistoryPage

  const CancelBookingPage({super.key, required this.bookingData});

  @override
  _CancelBookingPageState createState() => _CancelBookingPageState();
}

class _CancelBookingPageState extends State<CancelBookingPage> {
  final TextEditingController _reasonController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool isSaving = false;

  Future<void> _saveCancellation() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกเหตุผลในการยกเลิก")),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final bookingId = widget.bookingData['bookingId'];

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('ผู้ใช้ยังไม่ล็อกอิน');
      }
      final userId = user.id;

      final userData =
          await supabase
              .from('users')
              .select('user_type')
              .eq('user_id', userId)
              .maybeSingle();

      if (userData == null || userData['user_type'] == null) {
        throw Exception('ไม่พบข้อมูลประเภทผู้ใช้');
      }

      final userType = userData['user_type'] as String;

      // ตรวจสอบว่ามีคำขอยกเลิกของ booking นี้แล้วหรือยัง
      final existingCancellation =
          await supabase
              .from('bookingcancellations')
              .select()
              .eq('booking_id', bookingId)
              .maybeSingle();

      if (existingCancellation != null) {
        // มีคำขอยกเลิกแล้ว
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("พาหนะนี้ได้ทำการยกเลิกการจองไปแล้ว")),
        );
        setState(() {
          isSaving = false;
        });
        return;
      }

      // บันทึกคำขอยกเลิกใน bookingcancellations
      final insertResponse =
          await supabase
              .from('bookingcancellations')
              .insert({
                'booking_id': bookingId,
                'cancel_reason': reason,
                'cancelled_at': DateTime.now().toIso8601String(),
                'cancelled_by': userType,
              })
              .select()
              .maybeSingle();

      if (insertResponse == null) {
        throw Exception('ไม่สามารถบันทึกคำขอยกเลิกได้');
      }

      // ดึง renter_id จาก bookingData
      final vehicleOwnerId = widget.bookingData['renter_id'] as String?;

      if (vehicleOwnerId != null) {
        try {
          final notificationResponse =
              await supabase
                  .from('notifications')
                  .insert({
                    'user_id': vehicleOwnerId,
                    'type': 'booking_cancelled_request',
                    'message': 'มีคำขอยกเลิกการจองจากผู้เช่า รอการอนุมัติ',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  })
                  .select()
                  .maybeSingle();

          // ไม่ต้องเช็คหรือแสดง error ถ้า notificationResponse เป็น null
        } catch (_) {
          // จับ error เงียบ ๆ ไม่แสดงหรือ throw
        }
      }

      // แสดงข้อความสำเร็จและไปหน้าที่กำหนด
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ส่งคำขอยกเลิกเรียบร้อยแล้ว รอการอนุมัติจากเจ้าของพาหนะ',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage6()),
      );
    } catch (e) {
      // แสดง error เฉพาะกรณีบันทึกคำขอยกเลิกหลักล้มเหลว
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void _goToHomePage() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("รายละเอียดการยกเลิกการจอง"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ส่วนของข้อมูลการจอง
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    booking['imageUrl'] != null &&
                            booking['imageUrl'].isNotEmpty
                        ? Image.network(
                          booking['imageUrl'],
                          width: 100,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                        : Container(
                          width: 100,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['provider'] ?? 'ไม่ทราบชื่อผู้ให้บริการ',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          ),
                          Text(
                            booking['bookingDate'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const Text(
                  "📌 รับคำจองจาก",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(booking['provider'] ?? '-'),
                const SizedBox(height: 8),
                const Text(
                  "📍 สถานที่ในการจอง",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(booking['location'] ?? '-'),
                const Divider(),
                // รายละเอียดการจอง
                const Text(
                  "📋 รายละเอียดการจอง",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("ประเภทพาหนะ : ${booking['vehicleType'] ?? '-'}"),
                Text("จำนวนไร่ : ${booking['raiAmount'] ?? '-'}"),
                Text("วันที่จอง : ${booking['bookingDate'] ?? '-'}"),
                
                const Divider(),
                // เหตุผลในการยกเลิก (TextField)
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      "เหตุผลในการยกเลิก",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "กรุณาระบุเหตุผล...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const Spacer(),
                // ปุ่ม ยกเลิก / ตกลง
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSaving ? null : _goToHomePage,
                        child: const Text("ยกเลิก"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSaving ? null : _saveCancellation,
                        child:
                            isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text("ตกลง"),
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
}
