import 'package:flutter/material.dart';
// Ensure you are using the same telephony package as in the home screen
import 'package:another_telephony/telephony.dart';
import 'dart:async'; // Required for Future

// Data model for SMS messages (from telephony package)
// We'll use SmsMessage directly

class ConversationPage extends StatefulWidget {
  // The address (phone number) of the conversation partner
  final String address;

  const ConversationPage({
    super.key,
    required this.address,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final Telephony telephony = Telephony.instance;
  late Future<List<SmsMessage>> _loadMessagesFuture;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // To scroll to bottom
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState, passing the address
    _loadMessagesFuture = _loadMessages(widget.address);
    // Optional: Scroll to bottom after messages load for the first time
    _loadMessagesFuture.then((_) => _scrollToBottom(initial: true));
  }

  @override
  void dispose() {
    _messageController.dispose(); // Dispose the controller
    _scrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  // Function to load messages for a specific address (including sent)
  Future<List<SmsMessage>> _loadMessages(String address) async {
    // Permissions check (optional, but good practice)
    final bool? permissionsResult = await telephony.requestSmsPermissions;
    if (permissionsResult == null || !permissionsResult) {
      // Consider how to handle this - maybe pop the screen or show persistent error
      throw Exception("SMS permissions are required.");
    }

    try {
      // Fetch both inbox and sent messages filtering by the specific address
      List<SmsMessage> inboxMessages = await telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
        // No sort needed here, will sort combined list
      );
      List<SmsMessage> sentMessages = await telephony.getSentSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
        // No sort needed here, will sort combined list
      );

      for (var i = 0; i < sentMessages.length; i++) {
        sentMessages[i].type = SmsType.MESSAGE_TYPE_SENT;
      }

      // Combine the lists
      List<SmsMessage> allMessages = [...inboxMessages, ...sentMessages];

      // Sort the combined list by date ascending
      allMessages.sort((a, b) {
        final dateA = a.date ?? 0;
        final dateB = b.date ?? 0;
        return dateA.compareTo(dateB);
      });

      return allMessages;

    } catch (e) {
      // Rethrow errors
      print("Error loading messages: $e"); // Log error
      throw Exception("Failed to load messages for $address."); // User-friendly message
    }
  }

  // Function to handle pull-to-refresh
  Future<void> _handleRefresh() async {
    setState(() {
      // Trigger a reload by creating a new future
      _loadMessagesFuture = _loadMessages(widget.address);
    });
    try {
      // Await the new future to keep the indicator spinning
      await _loadMessagesFuture;
      _scrollToBottom(); // Scroll to bottom after refresh if desired
    } catch (_) {
      // Error is handled by FutureBuilder
    }
  }

  // Function to send SMS
  Future<void> _sendMessage() async {
    final messageBody = _messageController.text.trim();
    if (messageBody.isEmpty) {
      return; // Don't send empty messages
    }

    setState(() {
      _isSending = true; // Disable send button
    });

    try {
      await telephony.sendSms(
        to: widget.address,
        message: messageBody
      );

      // Clear the input field on success
      _messageController.clear();

      // Show feedback (optional)
      if (mounted) { // Check if the widget is still in the tree
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Message sent!"), duration: Duration(seconds: 2)),
         );
      }

      // Refresh the message list to show the newly sent message
      // Add a small delay to allow the system time to process the sent SMS
      await Future.delayed(const Duration(milliseconds: 500));
      _handleRefresh();


    } catch (e) {
      print("Error sending SMS: $e"); // Log error
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to send message: $e"), backgroundColor: Colors.red),
          );
       }
    } finally {
       if (mounted) {
         setState(() {
           _isSending = false; // Re-enable send button
         });
       }
    }
  }

  // Function to scroll the list to the bottom
  void _scrollToBottom({bool initial = false}) {
     // Use WidgetsBinding to schedule scroll after build phase
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
           // Add a small delay on initial load to ensure layout is complete
           Future.delayed(Duration(milliseconds: initial ? 100 : 0), () {
              if (_scrollController.hasClients) { // Check again after delay
                 _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                 );
              }
           });
        }
     });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address), // Show the contact address in the AppBar
      ),
      body: Column( // Use Column to include the input field
        children: [
          Expanded( // Make the message list take available space
            child: FutureBuilder<List<SmsMessage>>(
              future: _loadMessagesFuture,
              builder: (context, snapshot) {
                // --- Loading State ---
                if (snapshot.connectionState == ConnectionState.waiting && !_isSending) {
                    // Only show main loader if not triggered by sending a message
                    return const Center(child: CircularProgressIndicator());
                }


                // --- Error State ---
                // Use previous data if available during refresh error, otherwise show error widget
                if (snapshot.hasError && snapshot.connectionState != ConnectionState.waiting) {
                   if (snapshot.data != null && snapshot.data!.isNotEmpty) {
                      // Show stale data + error SnackBar (handled elsewhere or could add here)
                      print("Error during refresh, showing stale data: ${snapshot.error}");
                   } else {
                      // No previous data, show full error widget
                      return _buildErrorWidget(snapshot.error.toString());
                   }
                }

                // --- Data State (Success or Stale during refresh error) ---
                final messages = snapshot.data ?? []; // Use empty list if data is null

                if (messages.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                  // Handle empty state (even if there was a refresh error but no prior data)
                  return RefreshIndicator(
                     onRefresh: _handleRefresh,
                     child: LayoutBuilder( // Ensure scroll works for refresh
                        builder: (context, constraints) => SingleChildScrollView(
                           physics: const AlwaysScrollableScrollPhysics(),
                           child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: const Center(child: Text("No messages in this conversation yet.")),
                           ),
                        ),
                     ),
                  );
                }

                // Display list of messages
                // Add RefreshIndicator for pull-to-refresh
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    controller: _scrollController, // Attach scroll controller
                    // reverse: true, // Often used in chat UIs, but requires reversing data source
                    physics: const AlwaysScrollableScrollPhysics(), // Ensure scroll for refresh
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      print("Message type:" + message.type.toString());
                      return _buildMessageItem(message);
                    },
                  ),
                );
              },
            ),
          ),
          // Message Input Field Area
          _buildMessageInputField(),
        ],
      ),
    );
  }

  // Helper widget to build individual message bubbles
  Widget _buildMessageItem(SmsMessage message) {
    // Determine if the message is incoming or outgoing
    final bool isMe = message.type == SmsType.MESSAGE_TYPE_SENT;

    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    // Use theme colors for better adaptability
    final bubbleColor = isMe
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    final textColor = isMe
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    final dateTime = message.date != null
        ? DateTime.fromMillisecondsSinceEpoch(message.date!)
        : null;
    // Format time more clearly
    final formattedTime = dateTime != null
        ? TimeOfDay.fromDateTime(dateTime).format(context) // Localized time format
        : "";

    return Container(
      alignment: alignment,
      // Add more vertical margin for spacing
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          // Slightly more rounded corners
          borderRadius: BorderRadius.circular(18.0),
          boxShadow: [ // Subtle shadow for depth
             BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
             )
          ]
        ),
        constraints: BoxConstraints(
           // Allow slightly wider bubbles
           maxWidth: MediaQuery.of(context).size.width * 0.78
        ),
        child: Column(
          // Align text within the bubble
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body ?? "[Empty Message]",
              style: TextStyle(color: textColor, fontSize: 15), // Slightly larger text
            ),
            const SizedBox(height: 5.0), // More space before timestamp
            Text(
              formattedTime,
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11.0), // Slightly larger timestamp
            ),
          ],
        ),
      ),
    );
  }

   // Helper widget to display errors
  Widget _buildErrorWidget(String errorMessage) {
    // Clean up common error messages
    String displayMessage = errorMessage;
    if (errorMessage.contains("Exception:")) {
       displayMessage = errorMessage.split("Exception:")[1].trim();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0), // More padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 60),
            const SizedBox(height: 20),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                 color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Loading'),
              onPressed: _handleRefresh, // Use the refresh handler
              style: ElevatedButton.styleFrom(
                 backgroundColor: Theme.of(context).colorScheme.errorContainer,
                 foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for the message text input field and send button
  Widget _buildMessageInputField() {
    return Container(
      // Add some elevation and decoration
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Send a message...",
                border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(25.0),
                   borderSide: BorderSide.none, // Hide default border
                ),
                filled: true, // Add background color
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              minLines: 1,
              maxLines: 5, // Allow multi-line input
              enabled: !_isSending, // Disable input while sending
              onSubmitted: (_) => _isSending ? null : _sendMessage(), // Send on keyboard submit
            ),
          ),
          const SizedBox(width: 8.0),
          // Send Button
          // Use IconButton for better semantics, wrap in CircleAvatar for background
          CircleAvatar(
             backgroundColor: _isSending || _messageController.text.trim().isEmpty
                 ? Colors.grey // Disabled color
                 : Theme.of(context).colorScheme.primary,
             child: IconButton(
                icon: _isSending
                    ? const SizedBox( // Show progress indicator when sending
                       width: 20,
                       height: 20,
                       child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                     )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending || _messageController.text.trim().isEmpty
                    ? null // Disable if sending or text is empty
                    : _sendMessage,
                tooltip: 'Send Message',
             ),
          ),
        ],
      ),
    );
  }
}


// --- How to Use ---
// 1. Add the route in your MaterialApp (e.g., in main.dart or SmsApp widget)
/*
MaterialApp(
  title: "Messages",
  theme: ThemeData( // Example Theme
     useMaterial3: true,
     colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  ),
  initialRoute: '/',
  routes: {
    '/': (context) => const MessagesHome(), // Assuming MessagesHome exists
    '/conversation': (context) {
       // Extract the address argument safely
       final arguments = ModalRoute.of(context)?.settings.arguments;
       final String address = arguments is String ? arguments : 'Unknown'; // Provide default
       if (address == 'Unknown' && arguments != null) {
          print("Warning: Invalid argument type for /conversation route: ${arguments.runtimeType}");
       }
       return ConversationPage(address: address);
    }
  },
  debugShowCheckedModeBanner: false,
);
*/

// 2. Navigate from MessagesHome ListTile onTap:
/*
onTap: () {
  final String conversationAddress = conversation.address; // Ensure address is not null
  if (conversationAddress.isNotEmpty) {
     print("Navigating to conversation with $conversationAddress");
     Navigator.pushNamed(
       context,
       '/conversation',
       arguments: conversationAddress, // Pass the address as an argument
     );
  } else {
     print("Cannot navigate: Conversation address is empty.");
     // Optionally show a SnackBar to the user
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open conversation: Invalid address.")),
     );
  }
},
*/
