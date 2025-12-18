/// Model for announcement media attachments
class AnnouncementMedia {
  final String type; // 'image', 'video', 'file'
  final String url;
  final String? thumbnailUrl; // For videos
  final String filename;
  final int? size; // Size in bytes
  final String? mimeType;

  AnnouncementMedia({
    required this.type,
    required this.url,
    this.thumbnailUrl,
    required this.filename,
    this.size,
    this.mimeType,
  });

  factory AnnouncementMedia.fromJson(Map<String, dynamic> json) {
    return AnnouncementMedia(
      type: json['type'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      filename: json['filename'] as String,
      size: json['size'] as int?,
      mimeType: json['mime_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      'filename': filename,
      if (size != null) 'size': size,
      if (mimeType != null) 'mime_type': mimeType,
    };
  }

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';
}
