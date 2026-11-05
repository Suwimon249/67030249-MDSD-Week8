import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'my_drafts_page.dart';
import '../database/app_database.dart';
import '../models/listing_draft.dart';
import '../repositories/listing_draft_repository.dart';
import '../services/gemini_vision_service.dart';

class SellItemPage extends StatefulWidget {
  final ListingDraftRepository draftRepository;
  final void Function(ListingDraft draft, File? imageFile, double price)? onListingConfirmed;

  const SellItemPage({
    super.key,
    required this.draftRepository,
    this.onListingConfirmed,
  });

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // --- ค่าคงที่ Prompt สำหรับวิเคราะห์สินค้าตามส่วนที่ 4 (ใช้งานจริง) ---
  static const String _prompt = '''
คุณคือผู้เชี่ยวชาญด้านสินค้ามือสอง ช่วยวิเคราะห์ภาพนี้และตอบเป็น JSON ตามโครงสร้างนี้เท่านั้น:
{
  "title": "ชื่อสินค้าภาษาไทยสั้นกระชับ",
  "category": "หมวดหมู่สินค้า เช่น เครื่องประดับ แฟชั่น",
  "description": "คำอธิบายรายละเอียด จุดเด่น และสภาพสินค้า 2-3 ประโยค"
}
''';

  // --- State ของรูปภาพ ---
  File? _selectedImage;

  // --- TextEditingController สำหรับฟอร์มตรวจทานและแก้ไข (ขั้นตอนที่ 5.1) ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(text: '990');

  // --- 3 สถานะของการวิเคราะห์ AI ---
  bool _isAnalyzing = false;       // กำลังวิเคราะห์อยู่
  bool _isSaving = false;          // กำลังบันทึกร่างประกาศลงฐานข้อมูล
  int? _editingDraftId;            // รหัสของร่างที่กำลังเปิดแก้ไข (หากมี)
  ListingDraft? _draft;            // ผลลัพธ์จาก AI (หากมี)
  String? _errorMessage;           // ข้อความ error

  // เก็บประวัติร่างประกาศที่ยืนยันแล้วใน State ของแอป (ขั้นตอนที่ 5.2)
  final List<ListingDraft> _savedDrafts = [];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ฟังก์ชันเลือกรูปภาพจาก Gallery
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _draft = null;
      _errorMessage = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
      _priceController.text = '990';
    });
  }

  // ฟังก์ชันส่งรูปให้ Gemini Vision วิเคราะห์ (พร้อมส่ง _prompt เข้าไป)
  Future<void> _analyzeWithAI() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปภาพสินค้าก่อน')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _draft = null;
    });

    try {
      final result = await GeminiVisionService().analyzeProductImage(
        _selectedImage!,
        prompt: _prompt,
      );

      setState(() {
        _isAnalyzing = false;
        _draft = result;

        _titleController.text = result.title;
        _categoryController.text = result.category;
        _descriptionController.text = result.description;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _draft = null;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ฟังก์ชันยืนยันร่างประกาศและบันทึกถาวรลง Drift (ขั้นตอนที่ 5.2)
  Future<void> _confirmListing() async {
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อประกาศสินค้า')),
      );
      return;
    }

    final finalDraft = ListingDraft(
      title: title,
      category: category.isNotEmpty ? category : 'สินค้าทั่วไป',
      description: description,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      final imagePath = _selectedImage?.path ?? '';
      // หากกำลังแก้ไขร่างเดิมอยู่ ให้ลบร่างเดิมออกก่อนเพื่ออัปเดตข้อมูลล่าสุด
      if (_editingDraftId != null) {
        await widget.draftRepository.deleteDraft(_editingDraftId!);
        _editingDraftId = null;
      }
      // บันทึกร่างประกาศลงฐานข้อมูล Drift (SQLite) อย่างถาวร
      await widget.draftRepository.saveDraft(finalDraft, imagePath);

      _savedDrafts.add(finalDraft);
      widget.onListingConfirmed?.call(finalDraft, _selectedImage, price);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกร่างประกาศ "$title" สำเร็จแล้ว!'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _selectedImage = null;
          _draft = null;
          _errorMessage = null;
          _editingDraftId = null;
          _titleController.clear();
          _categoryController.clear();
          _descriptionController.clear();
          _priceController.text = '990';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการบันทึกร่าง: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // แสดงฟอร์มเฉพาะเมื่อ AI วิเคราะห์สำเร็จเรียบร้อยแล้ว
    final showForm = _draft != null && !_isAnalyzing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงประกาศขายสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ร่างประกาศของฉัน',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final selectedDraft = await Navigator.push<ListingDraftRow>(
                context,
                MaterialPageRoute(
                  builder: (_) => MyDraftsPage(repository: widget.draftRepository),
                ),
              );
              if (!mounted) return;
              if (selectedDraft != null) {
                setState(() {
                  _editingDraftId = selectedDraft.id;
                  _titleController.text = selectedDraft.title;
                  _categoryController.text = selectedDraft.category;
                  _descriptionController.text = selectedDraft.description;
                  if (selectedDraft.imagePath.isNotEmpty) {
                    try {
                      final f = File(selectedDraft.imagePath);
                      if (f.existsSync()) {
                        _selectedImage = f;
                      }
                    } catch (_) {}
                  }
                  _draft = ListingDraft(
                    title: selectedDraft.title,
                    category: selectedDraft.category,
                    description: selectedDraft.description,
                  );
                  _errorMessage = null;
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('เปิดร่าง "${selectedDraft.title}" เพื่อแก้ไขแล้ว'),
                    backgroundColor: Colors.purple[700],
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. แสดงรูปภาพสินค้าหรือ Placeholder ---
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image, size: 100, color: Colors.grey),
              ),

            const SizedBox(height: 16),

            // --- 2. ปุ่มเลือกรูปภาพ ---
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('เลือกรูปภาพสินค้า'),
            ),

            const SizedBox(height: 10),

            // --- 3. ปุ่ม AI ช่วยแนะนำ ---
            ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeWithAI,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[100],
              ),
            ),

            const SizedBox(height: 20),

            // --- 4. สถานะ: กำลังวิเคราะห์ ---
            if (_isAnalyzing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'AI กำลังวิเคราะห์ภาพสินค้า...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),

            // --- 5. สถานะ: เกิดข้อผิดพลาด (แสดงข้อความ Error จาก AI Safety) ---
            if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เกิดข้อผิดพลาด',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // --- 6. ฟอร์มตรวจทานและแก้ไขก่อนลงประกาศขาย (แสดงเฉพาะเมื่อวิเคราะห์สำเร็จ) ---
            if (showForm)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.purple.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'ข้อมูลจาก AI (ตรวจทานและแก้ไขได้)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.purple[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AI ได้กรอกข้อมูลเริ่มต้นให้แล้ว คุณสามารถแก้ไขได้ก่อนลงประกาศ:',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const Divider(height: 24),

                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อประกาศ',
                          hintText: 'เช่น สร้อยคอ Pandora พร้อมจี้หัวใจ',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่สินค้า',
                          hintText: 'เช่น เครื่องประดับ, แฟชั่น',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'ราคาขาย (บาท)',
                          hintText: 'เช่น 990',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'คำบรรยายสินค้า',
                          hintText: 'รายละเอียด สภาพสินค้า จุดเด่น',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _confirmListing,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSaving ? 'กำลังบันทึกร่าง...' : 'ยืนยันร่างประกาศ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
