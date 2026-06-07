import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/auth_provider.dart';
import '../../theme/app_theme.dart';

class AiChatScreen extends StatefulWidget {
  final String topic;

  const AiChatScreen({super.key, required this.topic});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isAiTyping = false;
  late final String _aiName;
  late final String _aiRole;

  // Smart Pre-programmed Dialog Trees for High Fidelity Interactive Practice
  final Map<String, List<String>> _dialogTrees = {
    'Job Interview Prep': [
      "Tell me about a time when you had a conflict at work and how you resolved it.",
      "What is your greatest professional achievement so far, and how did you accomplish it?",
      "Why do you want to join our organization, and what values can you bring?",
      "Excellent. Do you have any questions for me regarding the job role or team culture?",
      "Thank you for your time today! You did an amazing job articulating your thoughts. We will contact you soon."
    ],
    'Daily Talk': [
      "That sounds interesting! What do you like to do in your free time when you're not working?",
      "Nice! I enjoy reading and learning new things. What's the weather like where you are today?",
      "Got it. What are your plans for the upcoming weekend? Doing anything special?",
      "That sounds wonderful. Hope you have a fantastic time!",
      "It was great chatting about your day! Let's practice again tomorrow!"
    ],
    'Favorite Food': [
      "Yum! Food is indeed the best topic. Do you prefer eating out at restaurants or cooking at home?",
      "Ah, nice. If you had to choose one dish to eat for the rest of your life, what would it be?",
      "Oh, that is a delicious choice! What's the most unusual or unique food you've ever tried?",
      "Wow! I should try that sometime. Sharing food stories is so fun.",
      "Thanks for sharing your culinary tastes. Let's talk recipes again soon!"
    ],
    'Travel Plans': [
      "Traveling is so exciting! Do you prefer relaxing beach vacations or exploring historic cities?",
      "Sounds like a plan! Who is your favorite travel companion, or do you prefer solo trips?",
      "Traveling alone or with loved ones always brings great memories. What is the most scenic place you have visited?",
      "Incredible. That place sounds beautiful. I am adding it to my list!",
      "I hope you get to travel to your dream destination soon! Have a safe journey."
    ]
  };

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _setAiPersona();
    _sendInitialMessage();
  }

  void _setAiPersona() {
    switch (widget.topic) {
      case 'Job Interview Prep':
        _aiName = "Sophia H. (HR)";
        _aiRole = "Mock Interviewer";
        break;
      case 'Daily Talk':
        _aiName = "Chloe (Peer)";
        _aiRole = "Conversation Partner";
        break;
      case 'Favorite Food':
        _aiName = "Marco (Chef)";
        _aiRole = "Food Specialist";
        break;
      case 'Travel Plans':
        _aiName = "Leo (Explorer)";
        _aiRole = "Travel Guide";
        break;
      default:
        _aiName = "Tandem AI";
        _aiRole = "Learning Coach";
    }
  }

  void _sendInitialMessage() {
    String message = "";
    switch (widget.topic) {
      case 'Job Interview Prep':
        message = "Welcome to your mock interview session! I am your interviewer Sophia. Let's begin: Can you introduce yourself and state the position you are applying for?";
        break;
      case 'Daily Talk':
        message = "Hey! It is Chloe here. How has your day been going? Did you do anything fun or productive today?";
        break;
      case 'Favorite Food':
        message = "Hello! I am Chef Marco. I love exploring foods. What is your absolute favorite cuisine or dish?";
        break;
      case 'Travel Plans':
        message = "Hi there! Leo here. If you could fly anywhere in the world right now, where would you go and why?";
        break;
      default:
        message = "Hello! Let's practice speaking English together. What topic would you like to talk about today?";
    }

    setState(() {
      _messages.add({
        'sender': 'ai',
        'text': message,
        'time': DateTime.now(),
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': DateTime.now(),
      });
      _isAiTyping = true;
    });
    _scrollToBottom();

    // Simulate AI response delay
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      
      String aiResponse = "";
      final steps = _dialogTrees[widget.topic];
      if (steps != null && _currentStep < steps.length) {
        aiResponse = steps[_currentStep];
        _currentStep++;
      } else {
        aiResponse = "That's wonderful! You're expressing yourself very well. Keep sharing!";
      }

      setState(() {
        _isAiTyping = false;
        _messages.add({
          'sender': 'ai',
          'text': aiResponse,
          'time': DateTime.now(),
        });
      });
      _scrollToBottom();

      // Award small participation Coins
      final auth = context.read<AuthProvider>();
      auth.firestore.awardCoins(auth.uid ?? '', 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.sparkles, color: AppTheme.tealAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aiName,
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  _aiRole,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isAiTyping) {
                  return _buildTypingIndicator(surfaceColor, borderColor);
                }

                final msg = _messages[index];
                final isMe = msg['sender'] == 'user';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? AppTheme.tealAccent 
                          : surfaceColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                      ),
                      border: isMe 
                          ? null 
                          : Border.all(color: borderColor),
                    ),
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        color: isMe ? Colors.white : textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: AppTheme.tealAccent,
                  mini: true,
                  elevation: 0,
                  child: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Color surfaceColor, Color borderColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: borderColor),
        ),
        child: const SizedBox(
          width: 32,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DotPulse(delay: 0),
              _DotPulse(delay: 200),
              _DotPulse(delay: 400),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotPulse extends StatefulWidget {
  final int delay;

  const _DotPulse({required this.delay});

  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.2, end: 1.0).animate(_controller);

    Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
