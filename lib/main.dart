import 'package:flutter/material.dart';
// Make sure you have the correct telephony package reference
import 'package:another_telephony/telephony.dart';
import 'dart:async';

import 'package:messages/widgets/pages/conversation_page.dart'; // Required for Future

void main() {
  runApp(const SmsApp());
}

@immutable
class Conversation {
  final String address;
  final String? body; // Latest message body
  final int? date; // Timestamp of the latest message
  // Removed threadId as it wasn't used in the previous grouping logic
  // Add it back if needed for navigation or more complex grouping

  const Conversation({required this.address, this.body, this.date});
}

class SmsApp extends StatelessWidget {
  const SmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Messages",
      initialRoute: '/',
      routes: {
        '/': (context) => const MessagesHome(),
        '/conversation': (context) {
          // Extract the address argument
          final address = ModalRoute.of(context)!.settings.arguments as String;
          return ConversationPage(address: address);
        },
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, // Or your preferred theme color
        useMaterial3: true, // Recommended for modern Flutter UI
      ),
    );
  }
}

class MessagesHome extends StatefulWidget {
  const MessagesHome({super.key});

  @override
  State<StatefulWidget> createState() => _MessagesHomeState();
}

class _MessagesHomeState extends State<MessagesHome> {
  final Telephony telephony = Telephony.instance;
  // Future to be used by FutureBuilder
  late Future<List<Conversation>> _loadConversationsFuture = _loadData();

  // Function that handles permissions and loading, returning the data or throwing an error
  Future<List<Conversation>> _loadData() async {
    // 1. Check and Request Permissions
    final bool? permissionsResult = await telephony.requestSmsPermissions;

    if (permissionsResult == null || !permissionsResult) {
      // Throw an error if permissions are not granted
      throw Exception("SMS permissions are required to load messages.");
    }

    // 2. Load Conversations if permissions granted
    try {
      List<SmsMessage> messages = [...(await telephony.getInboxSms()), ...(await telephony.getSentSms())];

      messages.sort((a, b) => b.date!.compareTo(a.date!));

      // 3. Process messages into conversations (Group by address)
      Map<String, Conversation> conversationMap = {};
      for (var message in messages) {
        // Use address as the key for grouping
        final key = message.address;
        if (key != null && !conversationMap.containsKey(key)) {
          conversationMap[key] = Conversation(
            address: key,
            body: message.body,
            date: message.date,
          );
        }
      }
      return conversationMap.values.toList();
    } catch (e) {
      // Rethrow any other errors during fetching/processing
      throw Exception("Failed to load conversations: $e");
    }
  }

  // Function to be called by RefreshIndicator
  Future<void> _handleRefresh() async {
    // Create a new Future instance to trigger FutureBuilder rebuild
    setState(() {
      _loadConversationsFuture = _loadData();
    });
    // Although FutureBuilder rebuilds, await the new future here
    // to ensure the refresh indicator shows until loading is complete.
    try {
      await _loadConversationsFuture;
    } catch (_) {
      // Error is handled by the FutureBuilder, but catch it here
      // to prevent unhandled exceptions from the await.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        // No need for manual refresh button if using pull-to-refresh
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _handleRefresh, // Trigger refresh manually if needed
        //     tooltip: 'Refresh Conversations',
        //   ),
        // ],
      ),
      body: FutureBuilder<List<Conversation>>(
        future: _loadConversationsFuture,
        builder: (context, snapshot) {
          // --- Loading State ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- Error State ---
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          // --- Data State (Success) ---
          if (snapshot.hasData) {
            final conversations = snapshot.data!;
            if (conversations.isEmpty) {
              // Show empty state message, still allow refresh
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: LayoutBuilder(
                  // Use LayoutBuilder to allow scrolling for RefreshIndicator
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: const Center(
                          child: Text("No conversations found."),
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            // Display list with Pull-to-Refresh
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                // Ensure list is always scrollable for RefreshIndicator
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final dateTime =
                      conversation.date != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                            conversation.date!,
                          )
                          : null;
                  final formattedDate =
                      dateTime != null
                          ? "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}" // Example format
                          : "";

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        conversation.address.isNotEmpty
                            ? conversation.address[0]
                            : '?',
                      ),
                    ),
                    title: Text(
                      conversation.address,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      conversation.body ?? "[No Content]",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(formattedDate),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/conversation',
                        arguments:
                            conversation
                                .address, // Pass the address as an argument
                      );
                    },
                  );
                },
              ),
            );
          }

          // --- Initial/Default State (should not usually be reached) ---
          return const Center(child: Text("Loading messages..."));
        },
      ),
    );
  }

  // Helper widget to display errors consistently
  Widget _buildErrorWidget(String errorMessage) {
    // Extract a cleaner message if it's the permission error
    final displayMessage =
        errorMessage.contains("SMS permissions")
            ? "SMS permissions are required to load messages."
            : errorMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Retry by triggering a reload
                setState(() {
                  _loadConversationsFuture = _loadData();
                });
              },
              child: const Text('Retry'),
            ),
            // Optionally add a button to open app settings
            // ElevatedButton(
            //   onPressed: () => openAppSettings(), // Requires permission_handler
            //   child: const Text('Open Settings'),
            // ),
          ],
        ),
      ),
    );
  }
}
