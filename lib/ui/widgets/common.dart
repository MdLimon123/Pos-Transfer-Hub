import 'package:flutter/material.dart';

/// Icon + accent colour for a file, derived from its extension or MIME type.
class FileKind {
  const FileKind(this.icon, this.color);
  final IconData icon;
  final Color color;
}

FileKind fileKindOf(String name, [String? mime]) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  final m = (mime ?? '').toLowerCase();
  bool inExt(List<String> l) => l.contains(ext);

  if (m.startsWith('image/') || inExt(['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'])) {
    return const FileKind(Icons.image_rounded, Color(0xFF7C5CFF));
  }
  if (m.startsWith('video/') || inExt(['mp4', 'mov', 'mkv', 'avi', 'webm', 'm4v'])) {
    return const FileKind(Icons.movie_rounded, Color(0xFFE5484D));
  }
  if (m.startsWith('audio/') || inExt(['mp3', 'wav', 'aac', 'm4a', 'flac'])) {
    return const FileKind(Icons.music_note_rounded, Color(0xFFD6409F));
  }
  if (m.contains('csv') || m.contains('sheet') || inExt(['csv', 'xls', 'xlsx', 'tsv'])) {
    return const FileKind(Icons.table_chart_rounded, Color(0xFF2E9E6B));
  }
  if (m.contains('pdf') || ext == 'pdf') {
    return const FileKind(Icons.picture_as_pdf_rounded, Color(0xFFE5603D));
  }
  if (inExt(['zip', 'rar', '7z', 'tar', 'gz'])) {
    return const FileKind(Icons.folder_zip_rounded, Color(0xFFC48A00));
  }
  if (inExt(['doc', 'docx', 'txt', 'rtf', 'md', 'json', 'xml'])) {
    return const FileKind(Icons.description_rounded, Color(0xFF3B82F6));
  }
  return const FileKind(Icons.insert_drive_file_rounded, Color(0xFF5B7C7C));
}

/// Rounded, tinted square holding a file-type icon.
class FileTypeTile extends StatelessWidget {
  const FileTypeTile({super.key, required this.kind, this.size = 46});
  final FileKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kind.color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(kind.icon, color: kind.color, size: size * 0.5),
      );
}

/// Small coloured capsule used for transfer / file status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
            Text(label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(20, 22, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
            ),
            ?trailing,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withValues(alpha: 0.6),
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline (used for the upload drop zone).
class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child, required this.color, this.radius = 20});
  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashedPainter(color, radius),
        child: child,
      );
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.radius != radius;
}
