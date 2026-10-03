import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vendor_model.dart';
import '../../services/firestore/vendor_repository.dart';

class VendorSession extends InheritedWidget {
  final VendorModel vendor;

  const VendorSession({
    super.key,
    required this.vendor,
    required super.child,
  });

  static VendorModel of(BuildContext context) {
    final session = context.dependOnInheritedWidgetOfExactType<VendorSession>();
    if (session == null) {
      throw Exception('VendorSession not found in context');
    }
    return session.vendor;
  }

  @override
  bool updateShouldNotify(VendorSession oldWidget) {
    return oldWidget.vendor != vendor;
  }
}

class VendorAuthWrapper extends StatefulWidget {
  final Widget child;

  const VendorAuthWrapper({super.key, required this.child});

  @override
  State<VendorAuthWrapper> createState() => _VendorAuthWrapperState();
}

class _VendorAuthWrapperState extends State<VendorAuthWrapper> {
  Future<VendorModel?>? _vendorFuture;

  @override
  void initState() {
    super.initState();
    _loadVendor();
  }

  void _loadVendor() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _vendorFuture = VendorRepository.getVendorByUserId(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vendorFuture == null) {
      return const Scaffold(
        body: Center(child: Text("Authentication required.")),
      );
    }

    return FutureBuilder<VendorModel?>(
      future: _vendorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Error loading vendor profile: ${snapshot.error}")),
          );
        }

        final vendor = snapshot.data;
        if (vendor == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                "Vendor profile not found.\nPlease contact Eventology support.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return VendorSession(
          vendor: vendor,
          child: widget.child,
        );
      },
    );
  }
}
