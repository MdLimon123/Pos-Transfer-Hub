import 'package:equatable/equatable.dart';

class RemoteFile extends Equatable {
  const RemoteFile({
    required this.name,
    required this.originalName,
    required this.size,
    required this.url,
    this.type,
    this.uploadedAt,
  });

  final String name;
  final String originalName;
  final int size;
  final String url;
  final String? type;
  final DateTime? uploadedAt;

  factory RemoteFile.fromJson(Map<String, dynamic> json) => RemoteFile(
        name: json['name'] as String,
        originalName: (json['original_name'] as String?) ?? json['name'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
        url: json['url'] as String,
        type: json['type'] as String?,
        uploadedAt: DateTime.tryParse(json['uploaded_at'] as String? ?? '')?.toLocal(),
      );

  @override
  List<Object?> get props => [name, originalName, size, url, type, uploadedAt];
}
