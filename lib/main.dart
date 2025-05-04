import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';

void main() {
  runApp(SmsApp());
}

class SmsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SmsHomePage(),
    );
  }
}

class SmsHomePage extends StatefulWidget {
  @override
  _SmsHomePageState createState() => _SmsHomePageState();
}

class _SmsHomePageState extends State<SmsHomePage> {
  final Telephony telephony = Telephony.instance;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  String smsStatus = "";

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  void requestPermissions() async {
    bool? granted = await telephony.requestPhoneAndSmsPermissions;
    if (granted != true) {
      setState(() {
        smsStatus = "Izin tidak diberikan.";
      });
    }
  }

  void sendSMS() async {
    final phone = phoneController.text.trim();
    final message = messageController.text.trim();

    if (phone.isEmpty || message.isEmpty) {
      setState(() {
        smsStatus = "Nomor dan pesan tidak boleh kosong.";
      });
      return;
    }

    await telephony.sendSms(
      to: phone,
      message: message,
    );
    setState(() {
      smsStatus = "SMS berhasil dikirim ke $phone!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Aplikasi SMS")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Nomor Telepon",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Isi Pesan",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendSMS,
              child: Text("Kirim SMS"),
            ),
            SizedBox(height: 20),
            Text(
              smsStatus,
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
