import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProspectusViewPage extends StatelessWidget {
  final String url;
  final String drugName;

  // Key kullanımını modern hale getirdik (super.key)
  const ProspectusViewPage({
    super.key,
    required this.url,
    required this.drugName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$drugName Kullanma Talimatı'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent, // Projenin ana rengine (kPrimary) göre güncelleyebilirsin
      ),
      body: SfPdfViewer.network(
        url,
        // Hata durumunda kullanıcıyı bilgilendiren SnackBar
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Prospektüs yüklenemedi: ${details.description}'),
                backgroundColor: Colors.red,
              ),
            );
          });
        },
      ),
    );
  }
}