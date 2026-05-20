import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hermes_mobile/features/studio/studio_activity_config.dart';
import 'package:hermes_mobile/features/studio/studio_activity_screen.dart';

// ---------------------------------------------------------------------------
// StudioScreen — tool grid that launches wizard screens
// ---------------------------------------------------------------------------

/// Multimedia creation studio — shows a grid of creative tools, each opening
/// a dedicated wizard ([StudioActivityScreen]) for that activity.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  void _openActivity(ActivityType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioActivityScreen(activityType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        children: [
          // ---- Header ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_mosaic,
                    size: 20, color: Color(0xFF2196F3)),
                SizedBox(width: 8),
                Text(
                  'Studio Création',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                Tooltip(
                  message: 'Sélectionne un outil pour lancer '
                      "l'assistant de création",
                  child: Icon(Icons.info_outline,
                      size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),

          // ---- Tool grid ----
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: ActivityType.values.map((type) {
                return GestureDetector(
                  onTap: () => _openActivity(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type.icon,
                            size: 28, color: type.color),
                        const SizedBox(height: 6),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: type.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.description,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
