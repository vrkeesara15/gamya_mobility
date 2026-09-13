import 'package:flutter/material.dart';
import '../theme/colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, this.title = 'Nothing here yet', this.message, this.action});
  final IconData icon; final String title; final String? message; final Widget? action;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 44, color: GamyaColors.textMuted), const SizedBox(height: 10),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: GamyaColors.textSecondary)),
    if (message != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: GamyaColors.textMuted))),
    if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action!),
  ])));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message; final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(icon: Icons.error_outline, title: 'Something went wrong', message: message, action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')));
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.height = 160});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(height: height, child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
}
