import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus {
  queued,
  running,
  paused,
  waitingNetwork,
  completed,
  failed,
  canceled,
}

class TransferTask extends Equatable {
  const TransferTask({
    required this.id,
    required this.type,
    required this.name,
    required this.createdAt,
    this.status = TransferStatus.queued,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.sourcePath,
    this.remoteName,
    this.url,
    this.savedLocation,
    this.message,
  });

  final String id;
  final TransferType type;

  /// Name shown to the user.
  final String name;
  final DateTime createdAt;
  final TransferStatus status;
  final int totalBytes;
  final int transferredBytes;

  /// Upload: local file being sent.
  final String? sourcePath;

  /// Server-side file name. Download: file to fetch. Upload: set on completion.
  final String? remoteName;
  final String? url;

  /// Download: where the finished file was saved (content:// URI or path).
  final String? savedLocation;

  /// Error text or short status note ("Retrying 1/3…").
  final String? message;

  bool get isUpload => type == TransferType.upload;

  /// Still consuming (or about to consume) the network.
  bool get isActive =>
      status == TransferStatus.queued ||
      status == TransferStatus.running ||
      status == TransferStatus.waitingNetwork;

  bool get isFinished =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.canceled;

  /// 0..1, or null when the total size is not known yet.
  double? get progress {
    if (status == TransferStatus.completed) return 1;
    if (totalBytes <= 0) return null;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get percent => ((progress ?? 0) * 100).floor();

  TransferTask copyWith({
    TransferStatus? status,
    int? totalBytes,
    int? transferredBytes,
    String? remoteName,
    String? savedLocation,
    String? message,
    bool clearMessage = false,
  }) {
    return TransferTask(
      id: id,
      type: type,
      name: name,
      createdAt: createdAt,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      sourcePath: sourcePath,
      remoteName: remoteName ?? this.remoteName,
      url: url,
      savedLocation: savedLocation ?? this.savedLocation,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'totalBytes': totalBytes,
        'transferredBytes': transferredBytes,
        'sourcePath': sourcePath,
        'remoteName': remoteName,
        'url': url,
        'savedLocation': savedLocation,
        'message': message,
      };

  factory TransferTask.fromJson(Map<String, dynamic> json) => TransferTask(
        id: json['id'] as String,
        type: TransferType.values.byName(json['type'] as String),
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: TransferStatus.values.byName(json['status'] as String),
        totalBytes: json['totalBytes'] as int? ?? 0,
        transferredBytes: json['transferredBytes'] as int? ?? 0,
        sourcePath: json['sourcePath'] as String?,
        remoteName: json['remoteName'] as String?,
        url: json['url'] as String?,
        savedLocation: json['savedLocation'] as String?,
        message: json['message'] as String?,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        status,
        totalBytes,
        transferredBytes,
        sourcePath,
        remoteName,
        url,
        savedLocation,
        message,
      ];
}
