import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugOverlay extends StatefulWidget {
  final List<String> logs;
  final VoidCallback onClear;
  final bool isDarkTheme;

  const DebugOverlay({
    super.key,
    required this.logs,
    required this.onClear,
    this.isDarkTheme = false,
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void didUpdateWidget(DebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to bottom when new logs arrive
    if (widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Debug Console',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: widget.logs.join('\n'),
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copied to clipboard')),
                  );
                },
                tooltip: 'Copy logs',
              ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: widget.onClear,
                tooltip: 'Clear logs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDarkTheme ? Colors.grey[900] : Colors.grey[100],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: widget.logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        widget.logs[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: widget.isDarkTheme ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 