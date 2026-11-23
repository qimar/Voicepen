import 'package:flutter/material.dart';

class TonePreset {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final bool isProOnly;

  const TonePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.isProOnly = false,
  });
}

abstract class TonePresets {
  static const List<TonePreset> all = [
    TonePreset(
      id: 'clear_concise',
      label: 'Clear & Concise',
      description: 'Simple, clean language stripping fillers and awkward pauses.',
      icon: Icons.auto_awesome,
      isProOnly: false,
    ),
    TonePreset(
      id: 'casual_email',
      label: 'Casual Email',
      description: 'Friendly, conversational tone ready to send directly to colleagues.',
      icon: Icons.mail_outline,
      isProOnly: false,
    ),
    TonePreset(
      id: 'bullet_points',
      label: 'Bullet Points',
      description: 'High-density, structured summary for fast skimming and instant recall.',
      icon: Icons.format_list_bulleted,
      isProOnly: false,
    ),
    TonePreset(
      id: 'executive_memo',
      label: 'Executive Memo',
      description: 'Concise leadership briefing with key decisions and actionable takeaways.',
      icon: Icons.business_center_outlined,
      isProOnly: true,
    ),
    TonePreset(
      id: 'brain_dump',
      label: 'Brain Dump',
      description: 'Untangles rapid rambling brainstorms and groups them into logical themes.',
      icon: Icons.lightbulb_outline,
      isProOnly: true,
    ),
    TonePreset(
      id: 'social_post',
      label: 'Twitter / X Post',
      description: 'Punchy, high-engagement thread format formatted for social publishing.',
      icon: Icons.tag,
      isProOnly: true,
    ),
    TonePreset(
      id: 'actionable_todo',
      label: 'Actionable To-Do',
      description: 'Structured task lists with checkboxes, priorities, and deadlines.',
      icon: Icons.check_circle_outline,
      isProOnly: true,
    ),
    TonePreset(
      id: 'custom_tone',
      label: 'Custom Tone',
      description: 'Your own custom AI prompt instructions & structure formatting.',
      icon: Icons.psychology,
      isProOnly: true,
    ),
  ];

  static const List<String> intensityLevels = ['Low', 'Medium', 'High'];
}
