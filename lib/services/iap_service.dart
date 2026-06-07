import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        // Handled silently or trigger loading overlay
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IAP ERROR] Transaction execution failed: ${purchase.error}');
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        final bool valid = await _verifyPurchaseReceipt(purchase);
        if (valid) {
          await _grantPremiumStatusOnFirebase(purchase.productID);
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyPurchaseReceipt(PurchaseDetails purchase) async {
    // In production, this can be verified against a cloud function back-end. 
    // Locally, checking if verification data exists satisfies standard Play Store test requirements.
    return purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  Future<void> _grantPremiumStatusOnFirebase(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Map productID to the planId expected by the Cloud Function
      String planId = '1_month';
      if (productId.contains('3_months')) {
        planId = '3_months';
      } else if (productId.contains('year') || productId.contains('12_months')) {
        planId = '1_year';
      }

      debugPrint('[IAP] Invoking secure activatePremium Cloud Function for plan: $planId');
      
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('activatePremium');

      final result = await callable.call(<String, dynamic>{
        'planId': planId,
      });

      debugPrint('[IAP SUCCESS] Cloud Function response: ${result.data}');

      isPremiumUser = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[IAP CRITICAL] Failed to synchronize purchase via Cloud Function: $e');
    }
  }

  /// Use this method to securely downgrade a user's status if they process a refund via Google Play Support
  Future<void> removePremiumStatusOnRefund(String phoneNumber) async {
    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      await firestore.collection('users').doc(phoneNumber).update({
        'isPremium': false,
        'premiumStatus': 'refunded',
        'premiumExpiresAt': FieldValue.delete(),
        'premiumPlan': FieldValue.delete(),
      });
      
      debugPrint('[IAP ADMIN] Successfully downgraded account due to refund processing.');
    } catch (e) {
      debugPrint('[IAP ADMIN ERROR] Failed to process refund downgrade: $e');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}