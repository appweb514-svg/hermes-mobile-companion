import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/settings_section.dart';

/// Known MCP skills available on the Hermes server.
const _kKnownSkills = [
  _McpSkill(id: 'native-mcp', name: 'Native MCP', description: 'MCP client: connect servers, register tools (stdio/HTTP)'),
  _McpSkill(id: 'playwright-mcp-stealth', name: 'Playwright MCP Stealth', description: 'Configure Playwright MCP with anti-detection stealth'),
  _McpSkill(id: 'llama-cpp', name: 'llama.cpp', description: 'Local GGUF inference + HF Hub model discovery'),
  _McpSkill(id: 'outlines', name: 'Outlines', description: 'Structured JSON/regex/Pydantic LLM generation'),
  _McpSkill(id: 'huggingface-hub', name: 'HuggingFace Hub', description: 'Search/download/upload models, datasets'),
  _McpSkill(id: 'arxiv', name: 'arXiv', description: 'Search arXiv papers by keyword, author, category'),
  _McpSkill(id: 'dspy', name: 'DSPy', description: 'Declarative LM programs, auto-optimize prompts, RAG'),
  _McpSkill(id: 'notion', name: 'Notion', description: 'Notion API: pages, databases, markdown'),
  _McpSkill(id: 'airtable', name: 'Airtable', description: 'Airtable REST API: records CRUD, filters, upserts'),
  _McpSkill(id: 'spotify', name: 'Spotify', description: 'Play, search, queue, manage playlists and devices'),
];

class _McpSkill {
  final String id;
  final String name;
  final String description;
  const _McpSkill({required this.id, required this.name, required this.description});
}

/// Provider that loads enabled MCP skill IDs from SharedPreferences.
final mcpEnabledSkillsProvider =
    StateNotifierProvider<McpSkillsNotifier, Set<String>>((ref) {
  return McpSkillsNotifier();
});

class McpSkillsNotifier extends StateNotifier<Set<String>> {
  McpSkillsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList('mcp_enabled_skills') ?? [];
    state = enabled.toSet();
  }

  Future<void> toggle(String skillId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled) {
      state = {...state, skillId};
    } else {
      state = {...state}..remove(skillId);
    }
    await prefs.setStringList('mcp_enabled_skills', state.toList());
  }
}

/// Settings section showing MCP skills with enable/disable toggles.
class McpSkillsSection extends ConsumerWidget {
  const McpSkillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(mcpEnabledSkillsProvider);
    final theme = Theme.of(context);

    return SettingsSection(
      title: '🧩 Skills MCP',
      icon: Icons.extension,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Activer ou désactiver les skills MCP chargés par Hermes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(height: 1),
        ...List.generate(_kKnownSkills.length, (i) {
          final skill = _kKnownSkills[i];
          final isEnabled = enabled.contains(skill.id);
          return Column(
            children: [
              if (i > 0) const Divider(height: 1),
              SwitchListTile(
                dense: true,
                title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  skill.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: isEnabled,
                onChanged: (v) {
                  ref.read(mcpEnabledSkillsProvider.notifier).toggle(skill.id, v);
                },
                secondary: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEnabled ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: isEnabled
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        }),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    for (final skill in _kKnownSkills) {
                      ref.read(mcpEnabledSkillsProvider.notifier).toggle(skill.id, true);
                    }
                  },
                  icon: const Icon(Icons.checklist, size: 16),
                  label: const Text('Tout activer', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    for (final skill in _kKnownSkills) {
                      ref.read(mcpEnabledSkillsProvider.notifier).toggle(skill.id, false);
                    }
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Tout désactiver', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
