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


  final String name;
  final DateTime createdAt;
  final TransferStatus status;
  final int totalBytes;
  final int transferredBytes;

 
  final String? sourcePath;


  final String? remoteName;
  final String? url;


  final String? savedLocation;

  
  final String? message;

  bool get isUpload => type == TransferType.upload;

 
  bool get isActive =>
      status == TransferStatus.queued ||
      status == TransferStatus.running ||
      status == TransferStatus.waitingNetwork;

  bool get isFinished =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.canceled;


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
