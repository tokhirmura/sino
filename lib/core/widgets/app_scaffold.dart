import 'package:flutter/material.dart';

/// Base screen layout for every feature screen.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: Padding(padding: padding, child: body),
      ),
    );
  }
}
