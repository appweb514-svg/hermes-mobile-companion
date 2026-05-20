import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ActivityType enum — config for each creative studio activity
// ---------------------------------------------------------------------------

/// Defines the available creative activities in the Studio.
enum ActivityType {
  music,
  voice,
  video,
  image,
  audio,
  lyrics,
  podcast,
  mashup;

  /// Human-readable display name (French).
  String get displayName {
    switch (this) {
      case ActivityType.music:
        return 'Musique';
      case ActivityType.voice:
        return 'Voix';
      case ActivityType.video:
        return 'Vidéo';
      case ActivityType.image:
        return 'Image';
      case ActivityType.audio:
        return 'Audio';
      case ActivityType.lyrics:
        return 'Paroles';
      case ActivityType.podcast:
        return 'Podcast';
      case ActivityType.mashup:
        return 'Mashup';
    }
  }

  /// Material icon associated with this activity.
  IconData get icon {
    switch (this) {
      case ActivityType.music:
        return Icons.music_note_rounded;
      case ActivityType.voice:
        return Icons.record_voice_over_rounded;
      case ActivityType.video:
        return Icons.videocam_rounded;
      case ActivityType.image:
        return Icons.image_rounded;
      case ActivityType.audio:
        return Icons.graphic_eq_rounded;
      case ActivityType.lyrics:
        return Icons.auto_stories_rounded;
      case ActivityType.podcast:
        return Icons.podcasts_rounded;
      case ActivityType.mashup:
        return Icons.layers_rounded;
    }
  }

  /// Accent color for UI elements.
  Color get color {
    switch (this) {
      case ActivityType.music:
        return const Color(0xFF9C27B0);
      case ActivityType.voice:
        return const Color(0xFF2196F3);
      case ActivityType.video:
        return const Color(0xFF4CAF50);
      case ActivityType.image:
        return const Color(0xFFFF9800);
      case ActivityType.audio:
        return const Color(0xFFE91E63);
      case ActivityType.lyrics:
        return const Color(0xFF00BCD4);
      case ActivityType.podcast:
        return const Color(0xFFFF5722);
      case ActivityType.mashup:
        return const Color(0xFF673AB7);
    }
  }

  /// Short description shown in the tool grid.
  String get description {
    switch (this) {
      case ActivityType.music:
        return 'Générer une chanson avec HeartMuLa';
      case ActivityType.voice:
        return 'Cloner ou générer une voix';
      case ActivityType.video:
        return 'Générer une vidéo';
      case ActivityType.image:
        return 'Générer une image';
      case ActivityType.audio:
        return 'Générer un son / effet';
      case ActivityType.lyrics:
        return 'Écrire des paroles de chanson';
      case ActivityType.podcast:
        return 'Générer un script podcast';
      case ActivityType.mashup:
        return 'Mixer plusieurs sources';
    }
  }

  /// Command prefix sent to the chat session.
  String get commandPrefix {
    switch (this) {
      case ActivityType.music:
        return '/music ';
      case ActivityType.voice:
        return '/voice clone ';
      case ActivityType.video:
        return '/video ';
      case ActivityType.image:
        return '/image ';
      case ActivityType.audio:
        return '/audio ';
      case ActivityType.lyrics:
        return '/lyrics ';
      case ActivityType.podcast:
        return '/podcast ';
      case ActivityType.mashup:
        return '/mashup ';
    }
  }

  /// List of generative model names available for this activity.
  List<String> get availableModels {
    switch (this) {
      case ActivityType.music:
        return ['HeartMuLa v2', 'HeartMuLa v1', 'MuLa-Pro'];
      case ActivityType.voice:
        return ['VoiceClone Pro', 'VoiceGen Lite', 'ElevenLabs'];
      case ActivityType.video:
        return ['VideoGen Pro', 'VideoGen Lite', 'Sora Style'];
      case ActivityType.image:
        return ['ImageGen Pro', 'ImageGen Lite', 'DALL-E Style'];
      case ActivityType.audio:
        return ['AudioGen Pro', 'AudioGen Lite', 'SoundFX'];
      case ActivityType.lyrics:
        return ['LyricsMaster', 'LyricsGen Pro', 'PoetAI'];
      case ActivityType.podcast:
        return ['PodcastPro', 'PodcastScript', 'DialogueGen'];
      case ActivityType.mashup:
        return ['MashupMix v2', 'MashupMix v1', 'FusionPro'];
    }
  }

  /// Activity-specific parameter options.
  /// Each entry maps a parameter name (e.g. "style", "genre", "duration")
  /// to a list of possible choices.
  Map<String, List<String>> get parameters {
    switch (this) {
      case ActivityType.music:
        return {
          'style': [
            'Pop',
            'Rock',
            'Hip-Hop',
            'Jazz',
            'Classique',
            'Électronique',
            'R&B',
            'Country',
          ],
          'duration': ['30s', '60s', '90s', '120s', '180s'],
        };
      case ActivityType.voice:
        return {
          'voice': ['Masculine', 'Féminine', 'Neutre', 'Enfant', 'Robot'],
          'style': ['Naturel', 'Dramatique', 'Chant', 'Narratif'],
        };
      case ActivityType.video:
        return {
          'resolution': ['720p', '1080p', '4K'],
          'style': ['Cinématique', 'Animation', 'Réaliste', 'Artistique'],
          'duration': ['15s', '30s', '60s'],
        };
      case ActivityType.image:
        return {
          'resolution': ['512x512', '1024x1024', '1920x1080'],
          'style': [
            'Photorealistic',
            'Anime',
            'Artistic',
            '3D Render',
            'Pixel Art',
          ],
        };
      case ActivityType.audio:
        return {
          'type': ['Bruitage', 'Ambiance', 'Effet spécial', 'Instrument'],
          'duration': ['5s', '10s', '15s', '30s'],
        };
      case ActivityType.lyrics:
        return {
          'genre': ['Pop', 'Rock', 'Hip-Hop', 'R&B', 'Country', 'Jazz'],
          'style': ['Narratif', 'Poétique', 'Émotionnel', 'Engagé'],
        };
      case ActivityType.podcast:
        return {
          'genre': [
            'Technologie',
            'Science',
            'Histoire',
            'Divertissement',
            'Actualités',
          ],
          'duration': ['5min', '10min', '20min', '30min'],
        };
      case ActivityType.mashup:
        return {
          'type': ['Musique', 'Audio', 'Vidéo'],
          'style': ['Transition douce', 'Coupe franche', 'Fondu', 'Beatmatch'],
        };
    }
  }

  /// Hint text shown in the theme/subject text field.
  String get hint {
    switch (this) {
      case ActivityType.music:
        return 'Décris la chanson que tu veux créer…';
      case ActivityType.voice:
        return 'Décris la voix à générer…';
      case ActivityType.video:
        return 'Décris la vidéo que tu veux…';
      case ActivityType.image:
        return "Décris l'image que tu veux…";
      case ActivityType.audio:
        return 'Décris le son ou effet…';
      case ActivityType.lyrics:
        return 'Sujet des paroles…';
      case ActivityType.podcast:
        return 'Sujet du podcast…';
      case ActivityType.mashup:
        return 'Décris le mashup…';
    }
  }
}
