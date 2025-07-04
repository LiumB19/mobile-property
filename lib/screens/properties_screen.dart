import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  @override
  _PropertiesScreenState createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  List<dynamic> properties = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await ApiService.getProperties();

      if (result['success'] == true) {
        setState(() {
          properties = result['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          error = result['error'] ?? 'Failed to load properties';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Connection error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProperties,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProperties,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (properties.isEmpty) {
      return const Center(
        child: Text('No properties found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return PropertyCard(property: property);
        },
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;

  const PropertyCard({Key? key, required this.property}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetailScreen(property: property),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: property['image'] != null
                    ? CachedNetworkImage(
                        imageUrl: property['image'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: Icon(Icons.error)),
                        ),
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.image, size: 50)),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property['description'] ?? 'No Description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Location section - hanya tampilkan jika ada address/location
                    if (property['address'] != null &&
                        property['address'].toString().trim().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property['address'].toString().trim(),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                        ],
                      )
                    else if (property['location'] != null &&
                        property['location'].toString().trim().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property['location'].toString().trim(),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                    // Spacing hanya jika ada location
                    if ((property['address'] != null &&
                            property['address'].toString().trim().isNotEmpty) ||
                        (property['location'] != null &&
                            property['location'].toString().trim().isNotEmpty))
                      const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatter.format(property['price'] ?? 0),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        // Status section - hanya tampilkan jika ada status yang valid
                        if (property['status'] != null &&
                            property['status'].toString().trim().isNotEmpty &&
                            property['status'].toString().toLowerCase() !=
                                'unknown')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: property['status'] == 'available'
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              property['status'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
