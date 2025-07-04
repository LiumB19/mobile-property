import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_testing/services/api_service.dart';
import 'package:intl/intl.dart';
import 'edit_property_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final VoidCallback? onPropertyUpdated;

  const PropertyDetailScreen({
    Key? key,
    required this.property,
    this.onPropertyUpdated,
  }) : super(key: key);

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  bool _isLoading = false;

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Hero(
                        tag: 'fullscreen_${widget.property['id_property']}',
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white70,
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Gagal memuat gambar',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Konfirmasi Hapus'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apakah Anda yakin ingin menghapus property ini?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${widget.property['title'] ?? 'No Title'}"',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProperty();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProperty() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final propertyId = widget.property['id_property'];
      final result = await ApiService.deleteProperty(propertyId);

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Property berhasil dihapus'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
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
                    child: Text(result['error'] ?? 'Gagal menghapus property'),
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

  void _editProperty() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPropertyScreen(
          property: widget.property,
          onPropertyUpdated: () {
            if (widget.onPropertyUpdated != null) {
              widget.onPropertyUpdated!();
            }
            setState(() {}); // Refresh current screen
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final ethFormatter = NumberFormat('#,##0.00###');

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (String value) {
                        if (value == 'edit') {
                          _editProperty();
                        } else if (value == 'delete') {
                          _showDeleteConfirmation();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 12),
                              Text('Edit Property'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Hapus Property'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.property['image'] != null) {
                            _showFullScreenImage(
                                context, widget.property['image']);
                          }
                        },
                        child: widget.property['image'] != null
                            ? Hero(
                                tag:
                                    'property_image_${widget.property['id_property']}',
                                child: CachedNetworkImage(
                                  imageUrl: widget.property['image'],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.grey[300]!,
                                          Colors.grey[400]!,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.grey[300]!,
                                          Colors.grey[500]!,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported,
                                          size: 80, color: Colors.white70),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.purple[400]!,
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(Icons.home,
                                      size: 120, color: Colors.white70),
                                ),
                              ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.property['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (widget.property['type'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[600]!
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.property['type']
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[300]!,
                                Colors.grey[400]!,
                                Colors.grey[300]!,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 0.8,
                            ),
                            color: Colors.transparent,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Harga (IDR)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  formatter
                                      .format(widget.property['price'] ?? 0),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                if (widget.property['ethPrice'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '≈ ${ethFormatter.format(widget.property['ethPrice'])} ETH',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if ((widget.property['address'] != null &&
                                widget.property['address']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ||
                            (widget.property['description'] != null &&
                                widget.property['description']
                                    .toString()
                                    .trim()
                                    .isNotEmpty))
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 0.8,
                              ),
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.property['address'] != null &&
                                      widget.property['address']
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                    Text(
                                      'Lokasi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.property['address'].toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  if ((widget.property['address'] != null &&
                                          widget.property['address']
                                              .toString()
                                              .trim()
                                              .isNotEmpty) &&
                                      (widget.property['description'] != null &&
                                          widget.property['description']
                                              .toString()
                                              .trim()
                                              .isNotEmpty))
                                    const SizedBox(height: 20),
                                  if (widget.property['description'] != null &&
                                      widget.property['description']
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                    Text(
                                      'Deskripsi',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.property['description'].toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _editProperty,
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Property'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showDeleteConfirmation,
                                icon: const Icon(Icons.delete),
                                label: const Text('Hapus Property'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
              ),
            ],
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
                      'Menghapus property...',
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
}
