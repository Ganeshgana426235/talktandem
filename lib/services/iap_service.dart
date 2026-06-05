import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InAppPurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  List<ProductDetails> products = [];
  bool isPremiumUser = false;

  // Master product container configuration registered on Google Play
  final String _premiumSubscriptionId = 'talktandem_premium_monthly';

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('[IAP ERROR] Stream issue: $error'),
    );
    
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[IAP WARNING] Google Play Billing system unavailable.');
      return;
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails({_premiumSubscriptionId});
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IAP WARNING] Products not found on Google Play Console: ${response.notFoundIDs}');
    }

    products = response.productDetails;
    notifyListeners();
  }

  Future<void> buyPremium() async {
    if (products.isEmpty) {
      debugPrint('[IAP ERROR] Cannot initiate buy: Product list empty.');
      return;
    }

    final ProductDetails premiumProduct = products.firstWhere((prod) => prod.id == _premiumSubscriptionId);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: premiumProduct);
    
    // Request purchase stream initiation directly targeting standard Google Play subscription billing sheets
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        // Handle loading/spinning steps if required
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IAP ERROR] Transaction execution failed: ${purchase.error}');
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final bool valid = await _verifyPurchaseReceipt(purchase);
        if (valid) {
          await _grantPremiumStatusOnFirebase();
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyPurchaseReceipt(PurchaseDetails purchase) async {
    return purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  Future<void> _grantPremiumStatusOnFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      final phone = user.phoneNumber;
      if (phone != null) {
        await firestore.collection('users').doc(phone).update({
          'isPremium': true,
          'premiumPurchasedAt': FieldValue.serverTimestamp(),
        });
        
        isPremiumUser = true;
        notifyListeners();
        debugPrint('[IAP SUCCESS] Firebase user entry granted premium entitlement records successfully.');
      }
    } catch (e) {
      debugPrint('[IAP CRITICAL] Failed to synchronize cleared purchase details to user doc: $e');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}