import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import '../utils/localization_helper.dart';

/// Receipt template generator with localization support
class ReceiptTemplate {
  /// Generate PDF receipt with localization
  static Future<pw.Document> generateReceipt({
    required PaymentModel payment,
    required UserModel user,
    required String receiptNumber,
    required String languageCode,
    required BuildContext context,
  }) async {
    final pdf = pw.Document();
    
    // Choose template based on language
    if (languageCode == 'gu') {
      return _generateGujaratiReceipt(pdf, payment, user, receiptNumber, context);
    } else {
      return _generateEnglishReceipt(pdf, payment, user, receiptNumber, context);
    }
  }
  
  /// Generate English receipt
  static pw.Document _generateEnglishReceipt(
    pw.Document pdf,
    PaymentModel payment,
    UserModel user,
    String receiptNumber,
    BuildContext context,
  ) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
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
                      'TV SUBSCRIPTION PAYMENT RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Receipt No: $receiptNumber',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Date: ${_formatDateForPdf(payment.createdAt)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Customer Information
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CUSTOMER INFORMATION',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Name:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(user.name),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Phone:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatPhoneNumberForPdf(user.phoneNumber)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Address:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Expanded(
                          child: pw.Text(
                            user.address,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Area:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(user.area),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Payment Details
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PAYMENT DETAILS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                                             pw.Text('Base Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                     pw.Text(_formatCurrencyForPdf(payment.amount - payment.extraCharges)),
                      ],
                    ),
                                         if (payment.extraCharges > 0) ...[
                       pw.SizedBox(height: 5),
                       pw.Row(
                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                         children: [
                           pw.Text('Extra Charges:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                           pw.Text(_formatCurrencyForPdf(payment.extraCharges)),
                         ],
                       ),
                     ],
                    pw.Divider(thickness: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Amount:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                                                 pw.Text(
                           _formatCurrencyForPdf(payment.amount),
                           style: pw.TextStyle(
                             fontSize: 16,
                             fontWeight: pw.FontWeight.bold,
                             color: PdfColors.green800,
                           ),
                         ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                                         pw.Row(
                       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                       children: [
                         pw.Text('Payment Method:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                         pw.Text(_getPaymentMethodTextForPdf(payment.method.toString())),
                       ],
                     ),
                    if (payment.transactionId != null) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Transaction ID:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(payment.transactionId!),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 5),
                                         pw.Row(
                       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                       children: [
                         pw.Text('Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                         pw.Text(
                           _getPaymentStatusTextForPdf(payment.status.toString()),
                           style: pw.TextStyle(
                             color: payment.status.toString().toLowerCase() == 'approved' 
                                 ? PdfColors.green800 
                                 : PdfColors.orange800,
                             fontWeight: pw.FontWeight.bold,
                           ),
                         ),
                       ],
                     ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your payment!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'This is a computer-generated receipt.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                                         pw.Text(
                       'Generated on: ${_formatDateForPdf(DateTime.now())}',
                       style: const pw.TextStyle(fontSize: 10),
                     ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  /// Generate Gujarati receipt
  static pw.Document _generateGujaratiReceipt(
    pw.Document pdf,
    PaymentModel payment,
    UserModel user,
    String receiptNumber,
    BuildContext context,
  ) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
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
                      'ટીવી સબ્સ્ક્રિપ્શન ચુકવણી રસીદ',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'રસીદ નં: $receiptNumber',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                                         pw.Text(
                       'તારીખ: ${_formatDateForPdf(payment.createdAt)}',
                       style: const pw.TextStyle(fontSize: 12),
                     ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Customer Information
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ગ્રાહક માહિતી',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('નામ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(user.name),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('ફોન:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                                 pw.Text(_formatPhoneNumberForPdf(user.phoneNumber)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('સરનામું:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Expanded(
                          child: pw.Text(
                            user.address,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('વિસ્તાર:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(user.area),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Payment Details
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ચુકવણી વિગતો',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('મૂળ રકમ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                                 pw.Text(_formatCurrencyForPdf(payment.amount - payment.extraCharges)),
                      ],
                    ),
                    if (payment.extraCharges > 0) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('વધારાના શુલ્ક:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(_formatCurrencyForPdf(payment.extraCharges)),
                        ],
                      ),
                    ],
                    pw.Divider(thickness: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'કુલ રકમ:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          _formatCurrencyForPdf(payment.amount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('ચુકવણી પદ્ધતિ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                                 pw.Text(_getPaymentMethodTextForPdf(payment.method.toString())),
                      ],
                    ),
                    if (payment.transactionId != null) ...[
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('ટ્રાન્ઝેક્શન આઈડી:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(payment.transactionId!),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('સ્થિતિ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          _getPaymentStatusTextForPdf(payment.status.toString()),
                          style: pw.TextStyle(
                            color: payment.status.toString().toLowerCase() == 'approved' 
                                ? PdfColors.green800 
                                : PdfColors.orange800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'તમારી ચુકવણી બદલ આભાર!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'આ કમ્પ્યુટર દ્વારા બનાવવામાં આવેલ રસીદ છે.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'બનાવવામાં આવ્યું: ${_formatDateForPdf(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }
  
  /// Helper method to format date for PDF (without BuildContext)
  static String _formatDateForPdf(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  /// Helper method to format currency for PDF (without BuildContext)
  static String _formatCurrencyForPdf(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }
  
  /// Helper method to format phone number for PDF (without BuildContext)
  static String _formatPhoneNumberForPdf(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+91') && cleaned.length == 10) {
      cleaned = '+91$cleaned';
    }
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    }
    return phoneNumber;
  }
  
  /// Helper method to get payment method text for PDF (without BuildContext)
  static String _getPaymentMethodTextForPdf(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI Payment';
      case 'wallet':
        return 'Wallet Payment';
      case 'cash':
        return 'Cash Payment';
      case 'combined':
        return 'Combined Payment';
      default:
        return method;
    }
  }
  
  /// Helper method to get payment status text for PDF (without BuildContext)
  static String _getPaymentStatusTextForPdf(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'incomplete':
        return 'Incomplete';
      default:
        return status;
    }
  }
}