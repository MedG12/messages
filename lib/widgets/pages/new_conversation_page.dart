import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final Telephony telephony = Telephony.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _contactsPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _checkContactsPermission();
  }

  Future<void> _checkContactsPermission() async {
    final status = await Permission.contacts.status;
    setState(() {
      _contactsPermissionGranted = status.isGranted;
    });
  }

  Future<void> _requestContactsPermission() async {
    final status = await Permission.contacts.request();
    setState(() {
      _contactsPermissionGranted = status.isGranted;
    });

    if (!_contactsPermissionGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission is required to pick contacts'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickContact() async {
    if (!_contactsPermissionGranted) {
      await _requestContactsPermission();
      if (!_contactsPermissionGranted) return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      if (contact.phones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected contact has no phone number'),
            ),
          );
        }
        return;
      }

      // Use first phone number or let user choose if multiple exist
      if (contact.phones.length == 1) {
        setState(() {
          _phoneController.text = contact.phones.first.number;
        });
      } else {
        final phoneNumber = await _showPhoneNumberPicker(contact);
        if (phoneNumber != null) {
          setState(() {
            _phoneController.text = phoneNumber;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking contact: $e')));
      }
    }
  }

  Future<String?> _showPhoneNumberPicker(Contact contact) async {
    return await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select number for ${contact.displayName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contact.phones.length,
                itemBuilder: (context, index) {
                  final phone = contact.phones[index];
                  return ListTile(
                    title: Text(phone.number),
                    subtitle: Text(phone.label.toString()),
                    onTap: () => Navigator.pop(context, phone.number),
                  );
                },
              ),
            ),
          ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final phone = _phoneController.text.trim();

    if (message.isEmpty || phone.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await telephony.sendSms(to: phone, message: message);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message sent!')));
        Navigator.pushNamed(
          context,
          '/conversation',
          arguments: phone, // Pass the address as an argument
        );
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !_isSending &&
        _messageController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('New Conversation')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.contacts),
                  onPressed: _pickContact,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none, // Hide default border
                      ),
                      filled: true, // Add background color
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8.0),
                CircleAvatar(
                  backgroundColor:
                      _isSending || _messageController.text.trim().isEmpty
                          ? Colors
                              .grey // Disabled color
                          : Theme.of(context).colorScheme.primary,
                  child: IconButton(
                    onPressed: canSend ? _sendMessage : null,
                    icon:
                        _isSending
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.send, color: Colors.white),
                    tooltip: 'Send Message',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
