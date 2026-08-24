import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum LocationCategory {
  academic,
  library,
  residence,
  sports,
  admin,
  dining,
  worship,
  services,
}

extension LocationCategoryX on LocationCategory {
  String get label {
    switch (this) {
      case LocationCategory.academic:
        return 'Academic';
      case LocationCategory.library:
        return 'Library';
      case LocationCategory.residence:
        return 'Residence';
      case LocationCategory.sports:
        return 'Sports';
      case LocationCategory.admin:
        return 'Admin';
      case LocationCategory.dining:
        return 'Dining';
      case LocationCategory.worship:
        return 'Worship';
      case LocationCategory.services:
        return 'Services';
    }
  }

  IconData get icon {
    switch (this) {
      case LocationCategory.academic:
        return Icons.school_outlined;
      case LocationCategory.library:
        return Icons.local_library_outlined;
      case LocationCategory.residence:
        return Icons.home_outlined;
      case LocationCategory.sports:
        return Icons.sports_soccer_outlined;
      case LocationCategory.admin:
        return Icons.account_balance_outlined;
      case LocationCategory.dining:
        return Icons.restaurant_outlined;
      case LocationCategory.worship:
        return Icons.mosque_outlined;
      case LocationCategory.services:
        return Icons.store_outlined;
    }
  }

  Color get markerColor {
    switch (this) {
      case LocationCategory.academic:
        return const Color(0xFF1565C0);
      case LocationCategory.library:
        return const Color(0xFF8E24AA);
      case LocationCategory.residence:
        return const Color(0xFF2E7D32);
      case LocationCategory.sports:
        return const Color(0xFFEF6C00);
      case LocationCategory.admin:
        return const Color(0xFFC62828);
      case LocationCategory.dining:
        return const Color(0xFFF9A825);
      case LocationCategory.worship:
        return const Color(0xFF00796B);
      case LocationCategory.services:
        return const Color(0xFF6D4C41);
    }
  }
}

class CampusLocation {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final LocationCategory category;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.category,
  });
}
