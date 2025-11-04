// lib/study_group_chat_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:cloudinary_public/cloudinary_public.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

// --- CLOUDINARY DEPENDENCY (Reused from assignment_detail_page.dart) ---
const String _CLOUD_NAME = 'dc51dx2da'; 
const String _UPLOAD_PRESET = 'CollabLearn'; 
final CloudinaryPublic cloudinary = CloudinaryPublic(_CLOUD_NAME, _UPLOAD_PRESET, cache: false);
// ----------------------------------------------


class StudyGroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserName;

  const StudyGroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserName,
  });

  @override
  State<StudyGroupChatPage> createState() => _StudyGroupChatPageState();
}

class _StudyGroupChatPageState extends State<StudyGroupChatPage> {
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser!;
  
  // New state for upload progress
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // --- Send Message Logic (UPDATED for text) ---
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isUploading) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('study_groups')
          .doc(widget.groupId)
          .collection('chat') 
          .add({
        'type': 'text', // NEW: Message type
        'text': messageText,
        'senderId': _currentUser.uid,
        'senderName': widget.currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  // --- NEW: File Picking and Sending Logic ---
  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'zip', 'png', 'jpg', 'jpeg'],
    );
    
    if (result == null || result.files.first.bytes == null) return;
    
    final pickedFile = result.files.first;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      CloudinaryResourceType resourceType = CloudinaryResourceType.Raw;
      if (['jpg', 'png', 'jpeg'].contains(pickedFile.extension)) {
          resourceType = CloudinaryResourceType.Image;
      }
      
      CloudinaryFile fileToUpload;
      if (kIsWeb) {
        fileToUpload = CloudinaryFile.fromByteData(
          pickedFile.bytes!.buffer.asByteData(), 
          resourceType: resourceType,
          folder: 'collablearn/chat/${widget.groupId}',
          publicId: '${_currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}',
          identifier: pickedFile.name, 
        );
      } else {
        fileToUpload = CloudinaryFile.fromFile(
          pickedFile.path!, 
          resourceType: resourceType,
          folder: 'collablearn/chat/${widget.groupId}',
          publicId: '${_currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}',
        );
      }
      
      final CloudinaryResponse response = await cloudinary.uploadFile(
        fileToUpload,
        onProgress: (count, total) {
          if (mounted) setState(() => _uploadProgress = count / total);
        },
      );
      
      if (response.secureUrl.isEmpty) {
          throw Exception("Cloudinary upload failed.");
      }
      
      final downloadUrl = response.secureUrl; 

      await FirebaseFirestore.instance
          .collection('study_groups')
          .doc(widget.groupId)
          .collection('chat') 
          .add({
        'type': (resourceType == CloudinaryResourceType.Image) ? 'image' : 'file', // NEW: Message type
        'url': downloadUrl,
        'fileName': pickedFile.name,
        'senderId': _currentUser.uid,
        'senderName': widget.currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      debugPrint('Error sending file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  // --- NEW: URL Launcher Helper ---
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            // --- Real-time Chat Stream ---
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_groups')
                  .doc(widget.groupId)
                  .collection('chat')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs.reversed.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == _currentUser.uid;
                    final type = message['type'] ?? 'text'; // Get message type

                    if (type == 'text') {
                      return _buildMessageBubble(message, isMe, primaryColor);
                    } else {
                      return _buildMediaMessage(message, isMe, primaryColor); // NEW: Handle media messages
                    }
                  },
                );
              },
            ),
          ),
          
          // NEW: Upload Progress Indicator
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress.clamp(0.0, 1.0), color: primaryColor),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Uploading File... (${(_uploadProgress * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: primaryColor)),
                  ),
                ],
              ),
            ),
            
          // --- Message Input Area ---
          _buildChatInput(primaryColor),
        ],
      ),
    );
  }

  // --- NEW: Media Message Bubble Widget ---
  Widget _buildMediaMessage(Map<String, dynamic> message, bool isMe, Color primaryColor) {
    final isImage = message['type'] == 'image';
    final url = message['url'] as String? ?? '';
    final fileName = message['fileName'] as String? ?? 'File';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () => _launchUrl(url),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMe ? primaryColor.withOpacity(0.9) : Colors.grey.shade300,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(15),
              topRight: const Radius.circular(15),
              bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
              bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  message['senderName'] ?? 'Anonymous',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isMe ? Colors.white : primaryColor,
                  ),
                ),
              if (isImage)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 150,
                          width: 150,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                )
              else 
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white24 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.black87),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(message['timestamp']),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, Color primaryColor) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message['senderName'] ?? 'Anonymous',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: primaryColor,
                ),
              ),
            Text(
              message['text'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message['timestamp']),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildChatInput(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // NEW: File/Image Pick Button
          IconButton(
            icon: Icon(Icons.attach_file, color: primaryColor),
            onPressed: _isUploading ? null : _pickAndSendFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isUploading, // Disable text input during file upload
              decoration: InputDecoration(
                hintText: _isUploading ? 'Uploading file...' : 'Send a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A314D) : Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: primaryColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}