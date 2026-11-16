import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/check_in_model.dart';
import '../../../data/models/interaction_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/geotrace_repository.dart';

/// Bottom sheet ringan untuk obrolan/komentar teman pada check-in
class CommentBottomSheet extends StatefulWidget {
  final CheckInModel checkIn;
  final VoidCallback onCommentAdded;

  const CommentBottomSheet({
    super.key,
    required this.checkIn,
    required this.onCommentAdded,
  });

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _repository = GeoTraceRepository();
  final _commentController = TextEditingController();
  final List<InteractionModel> _comments = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments.addAll(
      widget.checkIn.interactions.where((i) => i.reactionType == 'comment'),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _repository.addInteraction(
        checkInId: widget.checkIn.id,
        reactionType: 'comment',
        content: text,
      );

      final user = _repository.currentUser;
      final myProfile = await _repository.getCurrentProfile();
      final newInteraction = InteractionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        checkInId: widget.checkIn.id,
        userId: user?.id ?? '',
        reactionType: 'comment',
        content: text,
        createdAt: DateTime.now(),
        profile: myProfile ??
            (user != null
                ? ProfileModel(
                    id: user.id,
                    username: user.email?.split('@').first ?? 'Me',
                    displayName: user.email?.split('@').first ?? 'Me',
                    createdAt: DateTime.now(),
                  )
                : null),
      );

      setState(() {
        _comments.add(newInteraction);
        _commentController.clear();
      });

      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM • HH:mm');

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header Sheet
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Comments (${_comments.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(height: 24),

          // Daftar Komentar
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No comments from friends yet.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _comments[index];
                      final name = item.profile?.displayName ?? 'Friend';
                      final timeStr = dateFormat.format(item.createdAt.toLocal());

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.teal.shade50,
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        timeStr,
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.content ?? '',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Input Komentar Modern
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  onPressed: _isSending ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
