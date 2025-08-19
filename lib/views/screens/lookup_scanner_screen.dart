import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LookupScannerScreen extends StatefulWidget {
  const LookupScannerScreen({super.key});

  @override
  State<LookupScannerScreen> createState() => _LookupScannerScreenState();
}

class _LookupScannerScreenState extends State<LookupScannerScreen> {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    // torchEnabled: false, // You can add a button to control this if needed
  );
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    // Optional: Start the camera as soon as the widget is initialized.
    // controller.start(); // controller often starts automatically with MobileScanner widget
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isProcessingScan) return; // Prevent multiple rapid detections

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? scannedValue = barcodes.first.rawValue;
                if (scannedValue != null && scannedValue.isNotEmpty) {
                  setState(() {
                    _isProcessingScan = true;
                  });
                  // Return the scanned value
                  Navigator.pop(context, scannedValue);
                }
              }
            },
          ),
          // Optional: Add a viewfinder overlay
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2.0),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Optional: Add a message
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.black.withOpacity(0.5),
              child: const Text(
                'Point the camera at a barcode',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
