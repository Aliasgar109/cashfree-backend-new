import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Receipt service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseReceiptService extends SupabaseService {
  
  /// Generate a unique receipt number for the given year
  Future<String> generateReceiptNumber(int year) async {
    return await executeWithErrorHandling(() async {
      // Use Supabase function to generate receipt number
      final response = await supabase.rpc('generate_receipt_number', params: {
        'receipt_year': year,
      });

      return response as String;
    });
  }

  /// Create a new receipt
  Future<String> createReceipt(ReceiptModel receipt) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from('receipts')
          .insert(receipt.toSupabase())
          .select('id')
          .single();

      return response['id'].toString();
    });
  }

  /// Get receipt by ID
  Future<ReceiptModel?> getReceiptById(String receiptId) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from('receipts')
          .select()
          .eq('id', receiptId)
          .maybeSingle();

      if (response == null) return null;

      return ReceiptModel.fromSupabase(response);
    });
  }

  /// Get receipt by payment ID
  Future<ReceiptModel?> getReceiptByPaymentId(String paymentId) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from('receipts')
          .select()
          .eq('payment_id', paymentId)
          .maybeSingle();

      if (response == null) return null;

      return ReceiptModel.fromSupabase(response);
    });
  }

  /// Get receipts for a user
  Future<List<ReceiptModel>> getReceiptsForUser({
    required String userFirebaseUid,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    return await executeWithErrorHandling(() async {
      var query = supabase
          .from('receipts')
          .select()
          .eq('user_firebase_uid', userFirebaseUid)
          .order('created_at', ascending: false);

      // TODO: Implement date filtering when PostgrestTransformBuilder supports it
      // if (startDate != null) {
      //   query = query.gte('created_at', startDate.toIso8601String());
      // }
      // if (endDate != null) {
      //   query = query.lte('created_at', endDate.toIso8601String());
      // }

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      
      return (response as List)
          .map((item) => ReceiptModel.fromSupabase(item))
          .toList();
    });
  }

  /// Generate PDF receipt
  Future<Uint8List> generateReceiptPDF({
    required ReceiptModel receipt,
    required UserModel user,
    required PaymentModel payment,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TV SUBSCRIPTION RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Receipt No: ${receipt.receiptNumber}',
                      style: pw.TextStyle(fontSize: 16),
                    ),
                    pw.Text(
                      'Date: ${_formatDate(receipt.generatedAt)}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Customer Details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Name: ${user.name}'),
                    pw.Text('Phone: ${user.phoneNumber}'),
                    pw.Text('Address: ${user.address}'),
                    pw.Text('Area: ${user.area}'),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Payment Details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Payment Details',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Service Period:'),
                        pw.Text('${_formatDate(payment.servicePeriodStart ?? payment.createdAt)} - ${_formatDate(payment.servicePeriodEnd ?? payment.createdAt)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Base Amount:'),
                        pw.Text('₹${payment.amount.toStringAsFixed(2)}'),
                      ],
                    ),
                    if ((payment.lateFees ?? 0) > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Late Fees:'),
                          pw.Text('₹${(payment.lateFees ?? 0).toStringAsFixed(2)}'),
                        ],
                      ),
                    if ((payment.extraCharges ?? 0) > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Extra Charges:'),
                          pw.Text('₹${(payment.extraCharges ?? 0).toStringAsFixed(2)}'),
                        ],
                      ),
                    if ((payment.wireCharges ?? 0) > 0)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Wire Charges:'),
                          pw.Text('₹${(payment.wireCharges ?? 0).toStringAsFixed(2)}'),
                        ],
                      ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Amount:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '₹${payment.totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Payment Method: ${payment.paymentMethod}'),
                    if (payment.upiTransactionId != null)
                      pw.Text('UPI Transaction ID: ${payment.upiTransactionId}'),
                    
                    // Cashfree-specific payment details
                    if (payment.cashfreeOrderId != null)
                      pw.Text('Cashfree Order ID: ${payment.cashfreeOrderId}'),
                    if (payment.cashfreePaymentId != null)
                      pw.Text('Cashfree Payment ID: ${payment.cashfreePaymentId}'),
                    if (payment.paymentGateway != null)
                      pw.Text('Payment Gateway: ${payment.paymentGateway}'),
                    if (payment.bankReference != null)
                      pw.Text('Bank Reference: ${payment.bankReference}'),
                    
                    pw.Text('Payment Date: ${_formatDate(payment.paidAt ?? payment.createdAt)}'),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your payment!',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'This is a computer-generated receipt.',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Share receipt PDF
  Future<void> shareReceiptPDF({
    required ReceiptModel receipt,
    required UserModel user,
    required PaymentModel payment,
  }) async {
    final pdfBytes = await generateReceiptPDF(
      receipt: receipt,
      user: user,
      payment: payment,
    );

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/receipt_${receipt.receiptNumber}.pdf');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Receipt for ${user.name} - ${receipt.receiptNumber}',
      subject: 'TV Subscription Receipt',
    );
  }

  /// Save receipt PDF to device
  Future<File> saveReceiptPDF({
    required ReceiptModel receipt,
    required UserModel user,
    required PaymentModel payment,
    String? customPath,
  }) async {
    final pdfBytes = await generateReceiptPDF(
      receipt: receipt,
      user: user,
      payment: payment,
    );

    final directory = customPath != null 
        ? Directory(customPath)
        : await getApplicationDocumentsDirectory();
    
    final file = File('${directory.path}/receipt_${receipt.receiptNumber}.pdf');
    await file.writeAsBytes(pdfBytes);

    return file;
  }

  /// Get receipts by date range
  Future<List<ReceiptModel>> getReceiptsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  }) async {
    return await executeWithErrorHandling(() async {
      var query = supabase
          .from('receipts')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      
      return (response as List)
          .map((item) => ReceiptModel.fromSupabase(item))
          .toList();
    });
  }

  /// Delete receipt
  Future<void> deleteReceipt(String receiptId) async {
    await executeWithErrorHandling(() async {
      await supabase
          .from('receipts')
          .delete()
          .eq('id', receiptId);
    });
  }

  /// Helper method to format dates
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
