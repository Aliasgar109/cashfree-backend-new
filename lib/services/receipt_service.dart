import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generate a unique receipt number for the given year
  Future<String> generateReceiptNumber(int year) async {
    try {
      // Query receipts for the current year to get the next sequence number
      final receiptsQuery = await _firestore
          .collection('receipts')
          .where('year', isEqualTo: year)
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();

      int sequenceNumber = 1;
      if (receiptsQuery.docs.isNotEmpty) {
        final lastReceipt = ReceiptModel.fromFirestore(
          receiptsQuery.docs.first,
        );
        sequenceNumber = lastReceipt.sequenceNumber + 1;
      }

      return ReceiptModel.generateReceiptNumber(year, sequenceNumber);
    } catch (e) {
      throw Exception('Failed to generate receipt number: $e');
    }
  }

  /// Generate PDF receipt for a payment
  Future<Uint8List> generateReceiptPDF({
    required PaymentModel payment,
    required UserModel user,
    required String receiptNumber,
    required String language,
  }) async {
    try {
      final pdf = pw.Document();

      // Create receipt content based on language
      final receiptData = _getReceiptContent(
        language,
        payment,
        user,
        receiptNumber,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildReceiptPage(receiptData, payment, user, receiptNumber);
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Build the receipt page layout
  pw.Widget _buildReceiptPage(
    Map<String, String> content,
    PaymentModel payment,
    UserModel user,
    String receiptNumber,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(content),
        pw.SizedBox(height: 20),

        // Receipt details
        _buildReceiptDetails(content, receiptNumber, payment),
        pw.SizedBox(height: 20),

        // User details
        _buildUserDetails(content, user),
        pw.SizedBox(height: 20),

        // Payment details
        _buildPaymentDetails(content, payment),
        pw.SizedBox(height: 20),

        // Amount breakdown
        _buildAmountBreakdown(content, payment),
        pw.SizedBox(height: 30),

        // Footer
        _buildFooter(content),
      ],
    );
  }

  /// Build receipt header
  pw.Widget _buildHeader(Map<String, String> content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            content['companyName']!,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            content['receiptTitle']!,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build receipt details section
  pw.Widget _buildReceiptDetails(
    Map<String, String> content,
    String receiptNumber,
    PaymentModel payment,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${content['receiptNumber']!}: $receiptNumber',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '${content['paymentDate']!}: ${_formatDate(payment.createdAt, content['locale']!)}',
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                '${content['paymentYear']!}: ${payment.year}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '${content['status']!}: ${_getStatusText(payment.status, content['locale']!)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build user details section
  pw.Widget _buildUserDetails(Map<String, String> content, UserModel user) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            content['customerDetails']!,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${content['name']!}: ${user.name}'),
                    pw.SizedBox(height: 5),
                    pw.Text('${content['phone']!}: ${user.phoneNumber}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${content['area']!}: ${user.area}'),
                    pw.SizedBox(height: 5),
                    pw.Text('${content['address']!}: ${user.address}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build payment details section
  pw.Widget _buildPaymentDetails(
    Map<String, String> content,
    PaymentModel payment,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            content['paymentDetails']!,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${content['paymentMethod']!}: ${_getPaymentMethodText(payment.method, content['locale']!)}',
          ),
          
          // Cashfree-specific payment details
          if (payment.cashfreeOrderId != null) ...[
            pw.SizedBox(height: 5),
            pw.Text('${content['cashfreeOrderId']!}: ${payment.cashfreeOrderId}'),
          ],
          if (payment.cashfreePaymentId != null) ...[
            pw.SizedBox(height: 5),
            pw.Text('${content['cashfreePaymentId']!}: ${payment.cashfreePaymentId}'),
          ],
          if (payment.paymentGateway != null) ...[
            pw.SizedBox(height: 5),
            pw.Text('${content['paymentGateway']!}: ${payment.paymentGateway}'),
          ],
          if (payment.bankReference != null) ...[
            pw.SizedBox(height: 5),
            pw.Text('${content['bankReference']!}: ${payment.bankReference}'),
          ],
          
          // Traditional payment details
          if (payment.transactionId != null) ...[
            pw.SizedBox(height: 5),
            pw.Text('${content['transactionId']!}: ${payment.transactionId}'),
          ],
          if (payment.walletAmountUsed != null &&
              payment.walletAmountUsed! > 0) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '${content['walletAmountUsed']!}: ₹${payment.walletAmountUsed!.toStringAsFixed(2)}',
            ),
          ],
          if (payment.upiAmountPaid != null && payment.upiAmountPaid! > 0) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '${content['upiAmountPaid']!}: ₹${payment.upiAmountPaid!.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }

  /// Build amount breakdown section
  pw.Widget _buildAmountBreakdown(
    Map<String, String> content,
    PaymentModel payment,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            content['amountBreakdown']!,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(content['baseAmount']!),
              pw.Text('₹${payment.amount.toStringAsFixed(2)}'),
            ],
          ),
          if (payment.extraCharges > 0) ...[
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(content['extraCharges']!),
                pw.Text('₹${payment.extraCharges.toStringAsFixed(2)}'),
              ],
            ),
          ],
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                content['totalAmount']!,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '₹${payment.totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build receipt footer
  pw.Widget _buildFooter(Map<String, String> content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            content['thankYou']!,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            content['footerNote']!,
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '${content['generatedOn']!}: ${_formatDate(DateTime.now(), content['locale']!)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  /// Get localized content for receipt
  Map<String, String> _getReceiptContent(
    String language,
    PaymentModel payment,
    UserModel user,
    String receiptNumber,
  ) {
    if (language == 'gu') {
      return {
        'locale': 'gu',
        'companyName': 'ટીવી સબ્સ્ક્રિપ્શન સેવા',
        'receiptTitle': 'ચુકવણી રસીદ',
        'receiptNumber': 'રસીદ નંબર',
        'paymentDate': 'ચુકવણી તારીખ',
        'paymentYear': 'ચુકવણી વર્ષ',
        'status': 'સ્થિતિ',
        'customerDetails': 'ગ્રાહક વિગતો',
        'name': 'નામ',
        'phone': 'ફોન',
        'area': 'વિસ્તાર',
        'address': 'સરનામું',
        'paymentDetails': 'ચુકવણી વિગતો',
        'paymentMethod': 'ચુકવણી પદ્ધતિ',
        'transactionId': 'ટ્રાન્ઝેક્શન આઈડી',
        'cashfreeOrderId': 'કેશફ્રી ઓર્ડર આઈડી',
        'cashfreePaymentId': 'કેશફ્રી પેમેન્ટ આઈડી',
        'paymentGateway': 'પેમેન્ટ ગેટવે',
        'bankReference': 'બેંક રેફરન્સ',
        'walletAmountUsed': 'વૉલેટ રકમ વપરાયેલ',
        'upiAmountPaid': 'UPI રકમ ચૂકવેલ',
        'amountBreakdown': 'રકમ વિભાજન',
        'baseAmount': 'મૂળ રકમ',
        'extraCharges': 'વધારાના શુલ્ક',
        'totalAmount': 'કુલ રકમ',
        'thankYou': 'આભાર!',
        'footerNote':
            'આ રસીદ તમારી ચુકવણીનો પુરાવો છે. કૃપા કરીને તેને સુરક્ષિત રાખો.',
        'generatedOn': 'બનાવવામાં આવ્યું',
      };
    } else {
      return {
        'locale': 'en',
        'companyName': 'TV Subscription Service',
        'receiptTitle': 'Payment Receipt',
        'receiptNumber': 'Receipt Number',
        'paymentDate': 'Payment Date',
        'paymentYear': 'Payment Year',
        'status': 'Status',
        'customerDetails': 'Customer Details',
        'name': 'Name',
        'phone': 'Phone',
        'area': 'Area',
        'address': 'Address',
        'paymentDetails': 'Payment Details',
        'paymentMethod': 'Payment Method',
        'transactionId': 'Transaction ID',
        'cashfreeOrderId': 'Cashfree Order ID',
        'cashfreePaymentId': 'Cashfree Payment ID',
        'paymentGateway': 'Payment Gateway',
        'bankReference': 'Bank Reference',
        'walletAmountUsed': 'Wallet Amount Used',
        'upiAmountPaid': 'UPI Amount Paid',
        'amountBreakdown': 'Amount Breakdown',
        'baseAmount': 'Base Amount',
        'extraCharges': 'Extra Charges',
        'totalAmount': 'Total Amount',
        'thankYou': 'Thank You!',
        'footerNote':
            'This receipt is proof of your payment. Please keep it safe for your records.',
        'generatedOn': 'Generated On',
      };
    }
  }

  /// Format date based on locale
  String _formatDate(DateTime date, String locale) {
    if (locale == 'gu') {
      // Gujarati date format
      final months = [
        'જાન્યુઆરી',
        'ફેબ્રુઆરી',
        'માર્ચ',
        'એપ્રિલ',
        'મે',
        'જૂન',
        'જુલાઈ',
        'ઓગસ્ટ',
        'સપ્ટેમ્બર',
        'ઓક્ટોબર',
        'નવેમ્બર',
        'ડિસેમ્બર',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } else {
      // English date format
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  /// Get localized status text
  String _getStatusText(PaymentStatus status, String locale) {
    if (locale == 'gu') {
      switch (status) {
        case PaymentStatus.PENDING:
          return 'બાકી';
        case PaymentStatus.APPROVED:
          return 'મંજૂર';
        case PaymentStatus.REJECTED:
          return 'નકારેલ';
        case PaymentStatus.INCOMPLETE:
          return 'અપૂર્ણ';
      }
    } else {
      switch (status) {
        case PaymentStatus.PENDING:
          return 'Pending';
        case PaymentStatus.APPROVED:
          return 'Approved';
        case PaymentStatus.REJECTED:
          return 'Rejected';
        case PaymentStatus.INCOMPLETE:
          return 'Incomplete';
      }
    }
  }

  /// Get localized payment method text
  String _getPaymentMethodText(PaymentMethod method, String locale) {
    if (locale == 'gu') {
      switch (method) {
        case PaymentMethod.UPI:
          return 'UPI ચુકવણી';
        case PaymentMethod.CASH:
          return 'રોકડ ચુકવણી';
        case PaymentMethod.WALLET:
          return 'વૉલેટ ચુકવણી';
        case PaymentMethod.COMBINED:
          return 'વૉલેટ + UPI';
        case PaymentMethod.CASHFREE_CARD:
          return 'કાર્ડ ચુકવણી (કેશફ્રી)';
        case PaymentMethod.CASHFREE_UPI:
          return 'UPI ચુકવણી (કેશફ્રી)';
        case PaymentMethod.CASHFREE_NETBANKING:
          return 'નેટ બેંકિંગ (કેશફ્રી)';
        case PaymentMethod.CASHFREE_WALLET:
          return 'વૉલેટ ચુકવણી (કેશફ્રી)';
      }
    } else {
      switch (method) {
        case PaymentMethod.UPI:
          return 'UPI Payment';
        case PaymentMethod.CASH:
          return 'Cash Payment';
        case PaymentMethod.WALLET:
          return 'Wallet Payment';
        case PaymentMethod.COMBINED:
          return 'Wallet + UPI';
        case PaymentMethod.CASHFREE_CARD:
          return 'Card Payment (Cashfree)';
        case PaymentMethod.CASHFREE_UPI:
          return 'UPI Payment (Cashfree)';
        case PaymentMethod.CASHFREE_NETBANKING:
          return 'Net Banking (Cashfree)';
        case PaymentMethod.CASHFREE_WALLET:
          return 'Wallet Payment (Cashfree)';
      }
    }
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadReceiptToStorage(
    Uint8List pdfBytes,
    String receiptNumber,
  ) async {
    try {
      final fileName = '$receiptNumber.pdf';
      final ref = _storage.ref().child('receipts').child(fileName);

      final uploadTask = ref.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'receiptNumber': receiptNumber,
            'generatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload receipt to storage: $e');
    }
  }

  /// Save receipt to Firestore
  Future<ReceiptModel> saveReceiptToFirestore({
    required String paymentId,
    required String receiptNumber,
    required String pdfUrl,
    required String language,
    required String userId,
    required double amount,
    required double extraCharges,
    required String paymentMethod,
    required int year,
    String? cashfreeOrderId,
    String? cashfreePaymentId,
    String? cashfreeSessionId,
    String? paymentGateway,
    String? bankReference,
    Map<String, dynamic>? gatewayResponse,
  }) async {
    try {
      final receiptData = {
        'paymentId': paymentId,
        'receiptNumber': receiptNumber,
        'pdfUrl': pdfUrl,
        'generatedAt': Timestamp.now(),
        'language': language,
        'userId': userId,
        'amount': amount,
        'extraCharges': extraCharges,
        'paymentMethod': paymentMethod,
        'year': year,
        'cashfreeOrderId': cashfreeOrderId,
        'cashfreePaymentId': cashfreePaymentId,
        'cashfreeSessionId': cashfreeSessionId,
        'paymentGateway': paymentGateway,
        'bankReference': bankReference,
        'gatewayResponse': gatewayResponse,
      };

      final docRef = await _firestore.collection('receipts').add(receiptData);

      return ReceiptModel(
        id: docRef.id,
        paymentId: paymentId,
        receiptNumber: receiptNumber,
        pdfUrl: pdfUrl,
        generatedAt: DateTime.now(),
        language: language,
        userId: userId,
        amount: amount,
        extraCharges: extraCharges,
        paymentMethod: paymentMethod,
        year: year,
        cashfreeOrderId: cashfreeOrderId,
        cashfreePaymentId: cashfreePaymentId,
        cashfreeSessionId: cashfreeSessionId,
        paymentGateway: paymentGateway,
        bankReference: bankReference,
        gatewayResponse: gatewayResponse,
      );
    } catch (e) {
      throw Exception('Failed to save receipt to Firestore: $e');
    }
  }

  /// Generate complete receipt (PDF + Storage + Firestore)
  Future<ReceiptModel> generateReceipt({
    required PaymentModel payment,
    required UserModel user,
  }) async {
    try {
      // Generate unique receipt number
      final receiptNumber = await generateReceiptNumber(payment.year);

      // Generate PDF
      final pdfBytes = await generateReceiptPDF(
        payment: payment,
        user: user,
        receiptNumber: receiptNumber,
        language: user.preferredLanguage,
      );

      // Upload to Firebase Storage
      final pdfUrl = await uploadReceiptToStorage(pdfBytes, receiptNumber);

      // Save to Firestore with Cashfree data
      final receipt = await saveReceiptToFirestore(
        paymentId: payment.id,
        receiptNumber: receiptNumber,
        pdfUrl: pdfUrl,
        language: user.preferredLanguage,
        userId: user.id,
        amount: payment.amount,
        extraCharges: payment.extraCharges,
        paymentMethod: payment.method.toString().split('.').last,
        year: payment.year,
        cashfreeOrderId: payment.cashfreeOrderId,
        cashfreePaymentId: payment.cashfreePaymentId,
        cashfreeSessionId: payment.cashfreeSessionId,
        paymentGateway: payment.paymentGateway,
        bankReference: payment.bankReference,
        gatewayResponse: payment.gatewayResponse,
      );

      return receipt;
    } catch (e) {
      throw Exception('Failed to generate receipt: $e');
    }
  }

  /// Download receipt PDF to device
  Future<String> downloadReceiptToDevice(
    String pdfUrl,
    String receiptNumber,
  ) async {
    try {
      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$receiptNumber.pdf';

      // Download the PDF from Firebase Storage
      final ref = _storage.refFromURL(pdfUrl);
      final file = File(filePath);

      await ref.writeToFile(file);

      return filePath;
    } catch (e) {
      throw Exception('Failed to download receipt: $e');
    }
  }

  /// Share receipt via WhatsApp or other apps
  Future<void> shareReceipt(
    String pdfUrl,
    String receiptNumber, {
    String? message,
  }) async {
    try {
      // Download the receipt to device first
      final filePath = await downloadReceiptToDevice(pdfUrl, receiptNumber);

      // Create share message
      final shareMessage = message ?? 'Payment Receipt - $receiptNumber';

      // Share the file
      await Share.shareXFiles([XFile(filePath)], text: shareMessage);
    } catch (e) {
      throw Exception('Failed to share receipt: $e');
    }
  }

  /// Get receipt by payment ID
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('receipts')
          .where('paymentId', isEqualTo: paymentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return ReceiptModel.fromFirestore(querySnapshot.docs.first);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get receipt: $e');
    }
  }

  /// Get receipt by receipt number
  Future<ReceiptModel?> getReceiptByNumber(String receiptNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('receipts')
          .where('receiptNumber', isEqualTo: receiptNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return ReceiptModel.fromFirestore(querySnapshot.docs.first);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get receipt: $e');
    }
  }

  /// Get all receipts for a user
  Future<List<ReceiptModel>> getUserReceipts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .orderBy('generatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ReceiptModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user receipts: $e');
    }
  }

  /// Delete receipt (admin only)
  Future<void> deleteReceipt(String receiptId, String pdfUrl) async {
    try {
      // Delete from Firestore
      await _firestore.collection('receipts').doc(receiptId).delete();

      // Delete from Firebase Storage
      final ref = _storage.refFromURL(pdfUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete receipt: $e');
    }
  }
}
