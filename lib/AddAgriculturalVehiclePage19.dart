import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddAgriculturalVehiclePage extends StatefulWidget {
  const AddAgriculturalVehiclePage({Key? key}) : super(key: key);

  @override
  State<AddAgriculturalVehiclePage> createState() =>
      _AddAgriculturalVehiclePageState();
}

class _AddAgriculturalVehiclePageState
    extends State<AddAgriculturalVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  String? _vehicleName;
  String? _vehicleType;
  String _status = 'active';
  String? _description;
  double? _price;
  int _quantity = 1;
  String? _location;
  List<String> _features = [];
  String? _additionalInfo;
  bool _isPublished = false;

  // ตัวแปรสถานะอนุญาตจอง
  String _bookingAllowed = 'yes';

  // province_id ของผู้ใช้ที่ล็อกอิน
  String? _provinceId;

  // สำหรับเก็บภาพหลัก
  Uint8List? _mainImageBytes;
  File? _mainImageFile;

  // สำหรับเก็บภาพเพิ่มเติม
  List<Uint8List> _additionalImageBytes = [];
  List<File> _additionalImageFiles = [];

  final ImagePicker _picker = ImagePicker();

  // ตัวเลือกประเภทพาหนะ
  final List<String> vehicleTypes = [
    'รถแทรกเตอร์',
    'รถเกี่ยวข้าว',
    'โดรนพ่นยา',
    'รถไถนา',
    'รถกรองข้าว',
    'รถดำนา',
    'คนรับจ้างทำนา',
  ];

  final List<String> featureOptions = [
    'เครื่องยนต์ดีเซล',
    'ประหยัดน้ำมัน',
    'รับประกันคุณภาพ',
    'พร้อมใช้งานตลอดปี',
    'มีคนขับให้',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProvinceId();
  }

  Future<void> _loadUserProvinceId() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response =
          await supabase
              .from('users')
              .select('province_id')
              .eq('user_id', user.id)
              .single();

      setState(() {
        _provinceId = response['province_id'] as String?;
      });
    } catch (e) {
      print('Error loading user province_id: $e');
    }
  }

  void _toggleFeature(String feature, bool selected) {
    setState(() {
      if (selected) {
        _features.add(feature);
      } else {
        _features.remove(feature);
      }
    });
  }

  Future<void> _pickMainImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _mainImageBytes = result.files.first.bytes;
          _mainImageFile = null;
        });
      }
    } else {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
      );
      if (pickedFile != null) {
        setState(() {
          _mainImageFile = File(pickedFile.path);
          _mainImageBytes = null;
        });
      }
    }
  }

  Future<void> _pickAdditionalImages() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          final newBytes =
              result.files
                  .where((f) => f.bytes != null)
                  .map((f) => f.bytes!)
                  .toList();
          _additionalImageBytes.addAll(newBytes);
          _additionalImageFiles.clear();
          if (_additionalImageBytes.length > 5) {
            _additionalImageBytes = _additionalImageBytes.take(5).toList();
          }
        });
      }
    } else {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 600,
      );
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          final newFiles =
              pickedFiles.map((xfile) => File(xfile.path)).toList();
          _additionalImageFiles.addAll(newFiles);
          _additionalImageBytes.clear();
          if (_additionalImageFiles.length > 5) {
            _additionalImageFiles = _additionalImageFiles.take(5).toList();
          }
        });
      }
    }
  }

  void _removeAdditionalImage(int index) {
    setState(() {
      if (kIsWeb) {
        _additionalImageBytes.removeAt(index);
      } else {
        _additionalImageFiles.removeAt(index);
      }
    });
  }

  Widget _buildMainImagePreview() {
    if (kIsWeb) {
      if (_mainImageBytes != null) {
        return Image.memory(_mainImageBytes!, height: 180, fit: BoxFit.cover);
      }
    } else {
      if (_mainImageFile != null && _mainImageFile!.existsSync()) {
        return Image.file(_mainImageFile!, height: 180, fit: BoxFit.cover);
      }
    }
    return Container(
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'คลิกเพื่ออัปโหลดรูปภาพหลัก',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              'รองรับไฟล์ JPG, PNG ขนาดไม่เกิน 5MB',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalImagesPreview() {
    List<Widget> images = [];
    if (kIsWeb) {
      for (int i = 0; i < _additionalImageBytes.length; i++) {
        images.add(
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _additionalImageBytes[i],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeAdditionalImage(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      for (int i = 0; i < _additionalImageFiles.length; i++) {
        if (!_additionalImageFiles[i].existsSync()) continue;
        images.add(
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _additionalImageFiles[i],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeAdditionalImage(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => images[index],
      ),
    );
  }

  Future<String?> _uploadImage(Uint8List bytes, String path) async {
    try {
      await supabase.storage
          .from('vehicle-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      final publicUrl = supabase.storage
          .from('vehicle-images')
          .getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Upload exception: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')));
      return;
    }

    if (_mainImageBytes == null && _mainImageFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาอัปโหลดรูปภาพหลัก')));
      return;
    }

    if (_provinceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังโหลดข้อมูลจังหวัด กรุณารอสักครู่')),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      try {
        Uint8List mainBytes;
        if (kIsWeb) {
          mainBytes = _mainImageBytes!;
        } else {
          mainBytes = await _mainImageFile!.readAsBytes();
        }
        final mainImagePath =
            'main_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final mainImageUrl = await _uploadImage(mainBytes, mainImagePath);
        if (mainImageUrl == null)
          throw Exception('ไม่สามารถอัปโหลดรูปภาพหลักได้');

        List<String> additionalImageUrls = [];
        if (kIsWeb) {
          for (int i = 0; i < _additionalImageBytes.length; i++) {
            final path =
                'additional_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            final url = await _uploadImage(_additionalImageBytes[i], path);
            if (url != null) additionalImageUrls.add(url);
          }
        } else {
          for (int i = 0; i < _additionalImageFiles.length; i++) {
            final bytes = await _additionalImageFiles[i].readAsBytes();
            final path =
                'additional_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            final url = await _uploadImage(bytes, path);
            if (url != null) additionalImageUrls.add(url);
          }
        }

        final insertResponse =
            await supabase
                .from('vehicles')
                .insert({
                  'renter_id': user.id,
                  'vehicle_name': _vehicleName,
                  'vehicle_type': _vehicleType,
                  'description': _description,
                  'price_per_day': _price,
                  'status': _status,
                  'service_capacity': _quantity,
                  'location': _location,
                  'province_id': _provinceId,
                  'is_available': true,
                  'booking_allowed': _bookingAllowed == 'yes',
                  'is_published': _isPublished,
                })
                .select()
                .maybeSingle();

        if (insertResponse == null) {
          throw Exception('ไม่สามารถบันทึกข้อมูลพาหนะได้');
        }

        final vehicleId = insertResponse['vehicle_id'] as String;

        // บันทึกรูปภาพหลัก
        await supabase.from('vehicleimages').insert({
          'vehicle_id': vehicleId,
          'image_url': mainImageUrl,
          'is_main_image': true,
        });

        // บันทึกรูปภาพเพิ่มเติม
        for (var url in additionalImageUrls) {
          await supabase.from('vehicleimages').insert({
            'vehicle_id': vehicleId,
            'image_url': url,
            'is_main_image': false,
          });
        }

        // บันทึกคุณสมบัติพิเศษ (features) ถ้ามีตาราง features และ vehiclefeatures
        for (var featureName in _features) {
          final featureResponse =
              await supabase
                  .from('features')
                  .select('feature_id')
                  .eq('feature_name', featureName)
                  .maybeSingle();

          String featureId;
          if (featureResponse == null) {
            final insertFeature =
                await supabase
                    .from('features')
                    .insert({'feature_name': featureName})
                    .select()
                    .maybeSingle();
            featureId = insertFeature!['feature_id'] as String;
          } else {
            featureId = featureResponse['feature_id'] as String;
          }

          await supabase.from('vehiclefeatures').insert({
            'vehicle_id': vehicleId,
            'feature_id': featureId,
          });
        }

        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('บันทึกพาหนะเกษตรใหม่เรียบร้อย'),
                content: const Text('ข้อมูลพาหนะถูกบันทึกเรียบร้อยแล้ว'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // ปิด dialog
                      Navigator.of(
                        context,
                      ).pop(true); // ปิดหน้าและส่ง true กลับ
                    },
                    child: const Text('ตกลง'),
                  ),
                ],
              ),
        );
      } catch (e, st) {
        print('Submit form error: $e');
        print(st);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.green[600];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text('เพิ่มพาหนะเกษตรใหม่'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // รูปภาพหลักและเพิ่มเติม
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'รูปภาพ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'รูปภาพหลัก *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickMainImage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildMainImagePreview(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'รูปภาพเพิ่มเติม (สูงสุด 5 รูป)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickAdditionalImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('อัปโหลดรูปภาพเพิ่มเติม'),
                      ),
                      const SizedBox(height: 12),
                      if ((kIsWeb && _additionalImageBytes.isNotEmpty) ||
                          (!kIsWeb && _additionalImageFiles.isNotEmpty))
                        _buildAdditionalImagesPreview(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ข้อมูลทั่วไป
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'ข้อมูลทั่วไป',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ชื่อพาหนะ *',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'กรุณาระบุชื่อพาหนะ'
                                    : null,
                        onSaved: (value) => _vehicleName = value,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'ประเภทพาหนะ *',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            vehicleTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'กรุณาเลือกประเภทพาหนะ'
                                    : null,
                        onChanged:
                            (value) => setState(() => _vehicleType = value),
                        onSaved: (value) => _vehicleType = value,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'สถานะ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'active',
                            groupValue: _status,
                            activeColor: primaryColor,
                            onChanged:
                                (value) => setState(() => _status = value!),
                          ),
                          const Text('ใช้งาน'),
                          const SizedBox(width: 20),
                          Radio<String>(
                            value: 'inactive',
                            groupValue: _status,
                            activeColor: primaryColor,
                            onChanged:
                                (value) => setState(() => _status = value!),
                          ),
                          const Text('ไม่ใช้งาน'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'คำอธิบาย',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                        onSaved: (value) => _description = value,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // รายละเอียดพาหนะ
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list_alt, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'รายละเอียดพาหนะ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ราคาเช่า (บาท/ชั่วโมง) *',
                          prefixText: '฿ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาระบุราคา';
                          }
                          final n = double.tryParse(value);
                          if (n == null || n < 0) {
                            return 'กรุณาระบุราคาที่ถูกต้อง';
                          }
                          return null;
                        },
                        onSaved:
                            (value) => _price = double.tryParse(value ?? ''),
                      ),
                      /* const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'จำนวนที่มีให้บริการ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: '1',
                        onSaved:
                            (value) =>
                                _quantity = int.tryParse(value ?? '1') ?? 1,
                      ), */
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ที่ตั้ง',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (value) => _location = value,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // คุณสมบัติพิเศษ
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'คุณสมบัติพิเศษ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            featureOptions.map((feature) {
                              final selected = _features.contains(feature);
                              return FilterChip(
                                label: Text(feature),
                                selected: selected,
                                selectedColor: primaryColor?.withOpacity(0.2),
                                checkmarkColor: primaryColor,
                                onSelected: (bool value) {
                                  _toggleFeature(feature, value);
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ข้อมูลเพิ่มเติม',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onSaved: (value) => _additionalInfo = value,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // การตั้งค่าการจอง และ เผยแพร่
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'การตั้งค่าการจอง',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'อนุญาตให้จอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'yes',
                            groupValue: _bookingAllowed,
                            activeColor: primaryColor,
                            onChanged:
                                (value) =>
                                    setState(() => _bookingAllowed = value!),
                          ),
                          const Text('อนุญาต'),
                          const SizedBox(width: 20),
                          Radio<String>(
                            value: 'no',
                            groupValue: _bookingAllowed,
                            activeColor: primaryColor,
                            onChanged:
                                (value) =>
                                    setState(() => _bookingAllowed = value!),
                          ),
                          const Text('ไม่อนุญาต'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('เผยแพร่พาหนะ'),
                        value: _isPublished,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setState(() {
                            _isPublished = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ปุ่มดำเนินการ
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.save),
                    label: const Text('บันทึกพาหนะ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
