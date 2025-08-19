import 'dart:convert'; // For utf8.decode
import 'dart:io'; // For File and Platform
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class BulkUploadForm extends StatefulWidget {
  const BulkUploadForm({super.key});

  @override
  State<BulkUploadForm> createState() => _BulkUploadFormState();
}

class _BulkUploadFormState extends State<BulkUploadForm> {
  String? _fileName;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.bytes != null || file.path != null) {
          setState(() {
            _selectedFile = file;
            _fileName = file.name;
          });
          Fluttertoast.showToast(msg: "File selected: $_fileName");
        } else {
           Fluttertoast.showToast(msg: "Selected file has no data or path.");
        }
      } else {
        Fluttertoast.showToast(msg: "No file selected.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error picking file: $e");
      setState(() {
        _fileName = null;
        _selectedFile = null;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      Fluttertoast.showToast(msg: "Please select a file first.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Uint8List? fileBytes = _selectedFile!.bytes;
      String fileContent;

      // If bytes are null, and not on web, try to read from path (for mobile)
      if (fileBytes == null && !kIsWeb && _selectedFile!.path != null) {
        try {
          fileBytes = await File(_selectedFile!.path!).readAsBytes();
        } catch (e) {
          Fluttertoast.showToast(msg: "Error reading file from path: $e", toastLength: Toast.LENGTH_LONG);
          setState(() { _isLoading = false; });
          return;
        }
      }

      if (fileBytes == null) {
        Fluttertoast.showToast(msg: "File content (bytes) is not available. Cannot process.", toastLength: Toast.LENGTH_LONG);
        setState(() { _isLoading = false; });
        return;
      }

      fileContent = utf8.decode(fileBytes);

      final List<String> lines = fileContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.length < 2) {
        Fluttertoast.showToast(msg: "CSV file is empty or has no data rows.");
        setState(() { _isLoading = false; });
        return;
      }

      final header = lines.first.split(',').map((h) => h.trim()).toList();
      final int nameIndex = header.indexOf('Product Name');
      final int unitsIndex = header.indexOf('Units');
      final int priceIndex = header.indexOf('Price');
      final int skuIndex = header.indexOf('SKU');

      if ([nameIndex, unitsIndex, priceIndex, skuIndex].any((index) => index == -1)) {
          Fluttertoast.showToast(msg: "CSV header is missing required columns: Product Name, Units, Price, SKU", toastLength: Toast.LENGTH_LONG);
          setState(() { _isLoading = false; });
          return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      CollectionReference masterProducts = FirebaseFirestore.instance.collection('master_products');
      int productsProcessed = 0;
      List<String> errors = [];

      for (int i = 1; i < lines.length; i++) {
        final values = lines[i].split(',').map((v) => v.trim()).toList();
        if (values.length == header.length) {
          try {
            String productName = values[nameIndex];
            String units = values[unitsIndex];
            double price = double.parse(values[priceIndex]);
            String sku = values[skuIndex];

            if (productName.isEmpty || units.isEmpty || sku.isEmpty) {
              errors.add("Row ${i+1}: Skipped due to missing data.");
              continue;
            }
            if (!['KGS', 'Litre', 'ML', 'Pcs'].contains(units)) {
              errors.add("Row ${i+1}: Invalid unit '$units'. Must be KGS, Litre, ML, or Pcs.");
              continue;
            }

            DocumentReference productDoc = masterProducts.doc();
            batch.set(productDoc, {
              'productName': productName,
              'units': units,
              'price': price,
              'sku': sku,
              'barcode': sku,
              'isManuallyAddedSku': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            productsProcessed++;
          } catch (e) {
            errors.add("Row ${i + 1}: Error processing - ${e.toString()}");
          }
        } else {
            errors.add("Row ${i+1}: Skipped due to incorrect number of columns.");
        }
      }

      if (productsProcessed > 0) {
        await batch.commit();
        String successMessage = "$productsProcessed products uploaded successfully!";
        if (errors.isNotEmpty) {
          successMessage += "\nEncountered ${errors.length} issues:\n${errors.take(5).join('\n')}";
           if(errors.length > 5) successMessage += "\n...and more.";
        }
        Fluttertoast.showToast(msg: successMessage, toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.CENTER);
      } else {
        String errorMessage = "No valid products found to upload.";
        if (errors.isNotEmpty) {
           errorMessage += "\nEncountered ${errors.length} issues:\n${errors.take(5).join('\n')}";
            if(errors.length > 5) errorMessage += "\n...and more.";
        }
        Fluttertoast.showToast(msg: errorMessage, toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.CENTER);
      }

    } catch (e) {
      Fluttertoast.showToast(msg: "Error uploading file: ${e.toString()}", toastLength: Toast.LENGTH_LONG);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ElevatedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Pick CSV File'),
            onPressed: _isLoading ? null : _pickFile,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
          ),
          const SizedBox(height: 20),
          if (_fileName != null)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected File:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fileName!,
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_fileName == null && !_isLoading)
             const Center(child: Text('No file selected.', style: TextStyle(fontSize: 16))),
          const SizedBox(height: 30),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Uploading, please wait...")
                ],
              ),
            ))
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Selected File'),
              onPressed: (_selectedFile != null && !_isLoading) ? _uploadFile : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
