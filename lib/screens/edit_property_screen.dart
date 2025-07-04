// edit_property_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_testing/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class EditPropertyScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final VoidCallback? onPropertyUpdated;

  const EditPropertyScreen({
    Key? key,
    required this.property,
    this.onPropertyUpdated,
  }) : super(key: key);

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _ethPriceController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'HOUSE';
  File? _selectedImage;
  bool _isLoading = false;
  bool _imageChanged = false;

  final List<String> _propertyTypes = [
    'HOUSE',
    'APARTMENT',
    'VILLA',
    'COMMERCIAL',
    'LAND',
    'OFFICE',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _titleController.text = widget.property['title'] ?? '';
    _priceController.text = widget.property['price']?.toString() ?? '';
    _ethPriceController.text = widget.property['ethPrice']?.toString() ?? '';
    _addressController.text = widget.property['address'] ?? '';
    _descriptionController.text = widget.property['description'] ?? '';

    if (widget.property['type'] != null) {
      _selectedType = widget.property['type'].toString().toUpperCase();
    }
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
            _imageChanged = true;
          });
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
      _imageChanged = true;
    });
  }

  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare property data
      Map<String, dynamic> propertyData = {
        'title': _titleController.text.trim(),
        'type': _selectedType,
        'price': _priceController.text.trim(),
        'ethPrice': _ethPriceController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      // Call API to update property
      final result = await ApiService.updatePropertyWithImage(
        widget.property['id_property'],
        propertyData,
        _imageChanged ? _selectedImage : null,
      );

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Property berhasil diperbarui'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          if (widget.onPropertyUpdated != null) {
            widget.onPropertyUpdated!();
          }

          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        Text(result['error'] ?? 'Gagal memperbarui property'),
                  ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Terjadi kesalahan: ${e.toString()}'),
                ),
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
          'Edit Property',
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
                                : widget.property['image'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.property['image'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 64,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.add_photo_alternate,
                                            size: 64,
                                            color: Colors.grey,
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
                              if (_selectedImage != null ||
                                  widget.property['image'] != null)
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
                        return 'Judul tidak boleh kosong';
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
                        return 'Harga tidak boleh kosong';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Harga harus berupa angka';
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
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (double.tryParse(value) == null) {
                          return 'Harga ETH harus berupa angka';
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
                        return 'Alamat tidak boleh kosong';
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
                        return 'Deskripsi tidak boleh kosong';
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
                          onPressed: () => Navigator.of(context).pop(),
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
                          onPressed: _updateProperty,
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
                            'Simpan Perubahan',
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
                      'Memperbarui property...',
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

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _ethPriceController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
