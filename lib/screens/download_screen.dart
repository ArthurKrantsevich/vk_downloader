import 'package:flutter/material.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Albums'),
      ),
      body: const Center(
        child: Text('Album selection and download management UI goes here.'),
      ),
    );
  }
}
