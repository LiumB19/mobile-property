import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class AddPropertyScreen extends StatefulWidget {
  @override
  _AddPropertyScreenState createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _ethPriceController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImage;
  String _selectedType = 'HOUSE';

  final List<String> _propertyTypes = [
    'HOUSE',
    'APARTMENT',
    'VILLA',
    'COMMERCIAL',
    'LAND',
    'OFFICE',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _ethPriceController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show dialog to choose image source
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Pilih Sumber Gambar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar berhasil dipilih'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih gambar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gambar dihapus'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi semua field yang wajib diisi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Clean and validate input data
      String cleanPrice =
          _priceController.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
      String cleanEthPrice =
          _ethPriceController.text.trim().replaceAll(RegExp(r'[^\d.]'), '');

      // Additional validation
      if (cleanPrice.isEmpty || double.tryParse(cleanPrice) == null) {
        throw Exception('Harga tidak valid');
      }

      if (cleanEthPrice.isNotEmpty && double.tryParse(cleanEthPrice) == null) {
        throw Exception('Harga ETH tidak valid');
      }

      // Prepare property data
      final propertyData = {
        'title': _titleController.text.trim(),
        'type': _selectedType,
        'price': cleanPrice,
        'ethPrice': cleanEthPrice.isNotEmpty ? cleanEthPrice : '0',
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      print('=== SUBMIT FORM DEBUG ===');
      print('Sending property data: $propertyData');
      print('Image file: ${_selectedImage?.path}');

      // Test connection first
      final connectionTest = await ApiService.testConnection();
      print('Connection test: $connectionTest');

      if (!connectionTest['success']) {
        throw Exception(
            'Tidak dapat terhubung ke server: ${connectionTest['error']}');
      }

      // Send data to server
      final response =
          await ApiService.addPropertyWithImage(propertyData, _selectedImage);

      print('=== RESPONSE RECEIVED ===');
      print('Response: $response');

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Property berhasil ditambahkan!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          String errorMessage = response['message'] ??
              response['error'] ??
              'Gagal menambahkan property';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        print('Submit form error: $e');

        String userMessage = 'Terjadi kesalahan tidak terduga';
        if (e.toString().contains('connection') ||
            e.toString().contains('server')) {
          userMessage =
              'Gagal terhubung ke server. Periksa koneksi internet Anda.';
        } else if (e.toString().contains('timeout')) {
          userMessage = 'Koneksi timeout. Coba lagi dalam beberapa saat.';
        } else if (e.toString().contains('tidak valid')) {
          userMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(userMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Tambah Property',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Section
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.white,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tap untuk menambah gambar',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectedImage != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.white),
                                    onPressed: _removeImage,
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[600],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Overlay for tap to add image
                        if (_selectedImage == null)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _pickImage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  _buildInputField(
                    controller: _titleController,
                    label: 'Judul Property',
                    icon: Icons.title,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Judul property harus diisi';
                      }
                      if (value.trim().length < 3) {
                        return 'Judul property minimal 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildDropdownField(),
                  const SizedBox(height: 16),

                  _buildInputField(
                    controller: _priceController,
                    label: 'Harga (IDR)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Harga harus diisi';
                      }
                      final number = int.tryParse(value.trim());
                      if (number == null || number <= 0) {
                        return 'Harga harus berupa angka positif';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    controller: _ethPriceController,
                    label: 'Harga ETH (Opsional)',
                    icon: Icons.currency_bitcoin,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = double.tryParse(value.trim());
                        if (number == null || number < 0) {
                          return 'Harga ETH harus berupa angka positif';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    controller: _addressController,
                    label: 'Alamat',
                    icon: Icons.location_on,
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Alamat harus diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    controller: _descriptionController,
                    label: 'Deskripsi',
                    icon: Icons.description,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Deskripsi harus diisi';
                      }
                      if (value.trim().length < 10) {
                        return 'Deskripsi minimal 10 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Tambah Property',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Menambahkan property...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedType,
        decoration: InputDecoration(
          labelText: 'Tipe Property',
          prefixIcon: Icon(Icons.home, color: Colors.blue[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        items: _propertyTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedType = newValue;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Pilih tipe property';
          }
          return null;
        },
      ),
    );
  }
}
