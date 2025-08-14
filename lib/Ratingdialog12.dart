import 'package:appfinal/homepage6.2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // นำเข้า Supabase SDK

class Ratingdialog extends StatefulWidget {
  final Map<String, dynamic>
  bookingData; // รับข้อมูล booking จากหน้า BookingHistoryPage

  const Ratingdialog({super.key, required this.bookingData});

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<Ratingdialog> {
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  final supabase = Supabase.instance.client; // Supabase client instance

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    print('Ratingdialog initState called');
    print('Received bookingData in initState: ${widget.bookingData}');
  }

  Future<void> _submitReview() async {
    print('_submitReview called');
    final booking = widget.bookingData;
    final bookingId = booking['bookingId'];

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาให้คะแนนก่อนส่งรีวิว')),
      );
      return;
    }
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเขียนรีวิวก่อนส่ง')));
      return;
    }
    if (bookingId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ข้อมูลการจองไม่ถูกต้อง')));
      return;
    }

    try {
      // ตรวจสอบว่ามีรีวิวสำหรับ booking นี้แล้วหรือยัง
      final existingReview =
          await supabase
              .from('reviews')
              .select()
              .eq('booking_id', bookingId)
              .maybeSingle();

      if (existingReview != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('คุณได้ส่งรีวิวสำหรับการจองนี้ไปแล้ว')),
        );
        return;
      }

      // บันทึกรีวิวใหม่
      final response =
          await supabase
              .from('reviews')
              .insert({
                'booking_id': bookingId,
                'rating': _rating.toInt(),
                'comment': _reviewController.text.trim(),
              })
              .select()
              .single();

      print('Review insert response: $response'); // debug

      // อัปเดตสถานะ booking ว่าเสร็จสิ้น (completed)
      await supabase
          .from('bookings')
          .update({
            'status': 'completed',
            'has_reviewed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('booking_id', bookingId);

      // ส่งแจ้งเตือนผู้ให้บริการ (ถ้ามี)
      final renterId = widget.bookingData['renter_id'];
      print('renterId: $renterId'); // debug

      if (renterId != null) {
        try {
          final notificationResponse = await supabase
              .from('notifications')
              .insert({
                'user_id': renterId,
                'type': 'new_review',
                'message': 'คุณได้รับรีวิวใหม่จากลูกค้า',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              });
          print('Notification insert response: $notificationResponse'); // debug
        } catch (e) {
          print('Error sending notification: $e'); // debug
        }
      } else {
        print('renterId is null, skipping notification'); // debug
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งรีวิวเรียบร้อยแล้ว')));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage6()),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingData;

    // Debug print ข้อมูล bookingData และ booking_id
    print('Received bookingData: $booking');
    print('bookingId: ${booking['bookingId']}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 44, 107, 61),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รีวิวและให้คะแนน',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ข้อมูลผู้ให้บริการ
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          booking['imageUrl'] != null &&
                                  booking['imageUrl'].isNotEmpty
                              ? Image.network(
                                booking['imageUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                              : Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              ),
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
                          const SizedBox(height: 4),
                          Text(
                            booking['bookingDate'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ประเภทพาหนะ: ${booking['vehicleType'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'จำนวนไร่: ${booking['raiAmount'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'ช่วงเวลาที่จอง: ${booking['workTime'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // หัวข้อให้คะแนน
            const Text(
              'ให้คะแนนการบริการ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // แถบให้คะแนน
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder:
                  (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(height: 20),

            const Divider(),

            // หัวข้อรีวิว
            Row(
              children: const [
                Icon(Icons.edit, size: 20, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'รีวิวการบริการ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ช่องป้อนรีวิว
            TextField(
              controller: _reviewController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'กรุณาเขียนรีวิวของคุณที่นี่...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const Spacer(),

            // ปุ่มยืนยัน
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'ยืนยัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
