import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage2 extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage2({Key? key, required this.profileData})
    : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage2> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  final supabase = Supabase.instance.client;

  bool _isSaving = false;
  Uint8List? _selectedImageBytes;
  String? _uploadedImagePath;
  String? _profileImageUrl; // URL สำหรับแสดงรูป

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profileData['full_name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.profileData['phone'] ?? '',
    );
    _uploadedImagePath = widget.profileData['profile_image_url'];
    _loadProfileImageUrl();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImageUrl() async {
    if (_uploadedImagePath != null && _uploadedImagePath!.isNotEmpty) {
      try {
        final url = supabase.storage
            .from('renter')
            .getPublicUrl(_uploadedImagePath!);
        setState(() {
          _profileImageUrl = url;
        });
      } catch (e) {
        print('Error loading profile image URL: $e');
        setState(() {
          _profileImageUrl = null;
        });
      }
    } else {
      setState(() {
        _profileImageUrl = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _profileImageUrl = null; // แสดงรูปใหม่จาก MemoryImage
      });
    }
  }

  Future<String?> _uploadImage(Uint8List bytes, String userId) async {
    final filePath =
        'profileimage/$userId.png'; // โฟลเดอร์ profileimage ใน bucket renter

    try {
      await supabase.storage
          .from('renter') // bucket ชื่อ renter
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      // รอไฟล์พร้อมใช้งานก่อน (ถ้าจำเป็น)
      await Future.delayed(Duration(seconds: 2));
      return filePath;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    final userId = widget.profileData['user_id'];
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ไม่พบ UserID')));
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      String? imagePath = _uploadedImagePath;

      if (_selectedImageBytes != null) {
        final uploadedPath = await _uploadImage(_selectedImageBytes!, userId);
        if (uploadedPath != null) {
          imagePath = uploadedPath;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปภาพล้มเหลว')));
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      final updates = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profile_image_url': imagePath,
      };

      await supabase.from('users').update(updates).eq('user_id', userId);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกข้อมูลสำเร็จ')));

      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.profileData['user_id'] ?? 'ไม่ระบุ';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF3E6B47),
        title: Text('แก้ไขโปรไฟล์'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Image Section
            Container(
              color: Color(0xFF5A8A67),
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          _selectedImageBytes != null
                              ? MemoryImage(_selectedImageBytes!)
                              : (_profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null),
                      child:
                          (_selectedImageBytes == null &&
                                  _profileImageUrl == null)
                              ? Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: BoxDecoration(
                          color: Color(0xFFF0AD4E),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form Section (แก้ไขได้แค่ชื่อและเบอร์โทร)
            Container(
              margin: EdgeInsets.all(15),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormField('ชื่อ:', _nameController),
                  SizedBox(height: 15),
                  _buildFormField('เบอร์โทรศัพท์:', _phoneController),
                ],
              ),
            ),

            // Preview Section (แสดงข้อมูลทั้งหมดแบบอ่านอย่างเดียว)
            Container(
              margin: EdgeInsets.all(15),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.only(bottom: 8),
                    margin: EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF5A8A67), width: 2),
                      ),
                    ),
                    child: Text(
                      'พรีวิวโปรไฟล์',
                      style: TextStyle(
                        color: Color(0xFF5A8A67),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _buildPreviewItem('ชื่อ:', _nameController.text),
                  _buildPreviewItem('UserID:', userId),
                  _buildPreviewItem(
                    'อีเมล:',
                    widget.profileData['email'] ?? '',
                  ),
                  _buildPreviewItem(
                    'ที่อยู่:',
                    widget.profileData['address'] ?? '',
                  ),
                  _buildPreviewItem('เบอร์โทรศัพท์:', _phoneController.text),
                ],
              ),
            ),

            // Buttons
            Container(
              padding: EdgeInsets.fromLTRB(15, 0, 15, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      padding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3E6B47),
                      padding: EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveProfile,
                    child:
                        _isSaving
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              'บันทึก',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E6B47),
          ),
        ),
        SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF3E6B47)),
            ),
          ),
          onChanged: (value) {
            setState(() {}); // อัปเดต preview
          },
        ),
      ],
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E6B47),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
