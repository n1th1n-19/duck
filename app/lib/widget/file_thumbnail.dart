import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/file_type_ext.dart';
import 'package:localsend_app/util/native/channel/android_channel.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:uri_content/uri_content.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

const double defaultThumbnailSize = 50;

class SmartFileThumbnail extends StatelessWidget {
  final Uint8List? bytes;
  final AssetEntity? asset;
  final String? path;
  final FileType fileType;

  const SmartFileThumbnail({
    required this.bytes,
    required this.asset,
    required this.path,
    required this.fileType,
  });

  factory SmartFileThumbnail.fromCrossFile(CrossFile file) {
    return SmartFileThumbnail(
      bytes: file.thumbnail,
      asset: file.asset,
      path: file.path,
      fileType: file.fileType,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return MemoryThumbnail(
        bytes: bytes,
        fileType: fileType,
      );
    } else if (asset != null) {
      return AssetThumbnail(
        asset: asset!,
        fileType: fileType,
      );
    } else {
      return FilePathThumbnail(
        path: path,
        fileType: fileType,
      );
    }
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final FileType fileType;

  const AssetThumbnail({
    required this.asset,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    return _Thumbnail(
      thumbnail: AssetEntityImage(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(64),
        thumbnailFormat: ThumbnailFormat.jpeg,
      ),
      icon: fileType.icon,
    );
  }
}

class FilePathThumbnail extends StatelessWidget {
  final String? path;
  final FileType fileType;

  const FilePathThumbnail({
    required this.path,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? thumbnail;
    final isVideo = fileType == FileType.video;
    Widget fallback(BuildContext _, Object _, StackTrace? _) => Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(fileType.icon, size: 32),
    );
    if (path != null && Platform.isAndroid && (path!.startsWith('content://') || isVideo) && (fileType == FileType.image || isVideo)) {
      // Android renders the preview (also for videos) without reading the whole file.
      thumbnail = Image(
        image: _AndroidThumbnailImage(path!, video: isVideo),
        errorBuilder: fallback,
      );
    } else if (path != null && fileType == FileType.image) {
      thumbnail = Image.file(
        File(path!),
        cacheWidth: 64, // reduce memory with low cached size; do not set cacheHeight because the image must keep its ratio
        errorBuilder: fallback,
      );
    } else {
      thumbnail = null;
    }

    return _Thumbnail(
      thumbnail: thumbnail,
      icon: fileType.icon,
    );
  }
}

class MemoryThumbnail extends StatelessWidget {
  final Uint8List? bytes;
  final FileType fileType;
  final double size;

  const MemoryThumbnail({
    required this.bytes,
    required this.fileType,
    this.size = defaultThumbnailSize,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? thumbnail;
    if (bytes != null) {
      thumbnail = Padding(
        padding: fileType == FileType.apk ? const EdgeInsets.all(50) : EdgeInsets.zero,
        child: Image.memory(
          bytes!,
          errorBuilder: (_, _, _) => Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(fileType.icon, size: 32),
          ),
        ),
      );
    } else {
      thumbnail = null;
    }

    return _Thumbnail(
      thumbnail: thumbnail,
      icon: fileType.icon,
      size: size,
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Widget? thumbnail;
  final IconData? icon;
  final double size;

  const _Thumbnail({
    required this.thumbnail,
    required this.icon,
    this.size = defaultThumbnailSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: Theme.of(context).inputDecorationTheme.fillColor!,
          child: thumbnail == null
              ? Icon(icon!, size: 32)
              : FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: thumbnail,
                ),
        ),
      ),
    );
  }
}

/// Preview from Android's thumbnail API; content URI images fall back to decoding the file.
class _AndroidThumbnailImage extends ImageProvider<_AndroidThumbnailImage> {
  final String source;
  final bool video;

  const _AndroidThumbnailImage(this.source, {required this.video});

  @override
  Future<_AndroidThumbnailImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(_AndroidThumbnailImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      // ignore: discarded_futures
      codec: _loadAsync(decode),
      scale: 1,
      informationCollector: () sync* {
        yield ErrorDescription('AndroidThumbnailImage: $source');
      },
    );
  }

  Future<Codec> _loadAsync(ImageDecoderCallback decode) async {
    final bytes = await loadThumbnailAndroid(source: source, video: video);
    if (bytes != null) {
      return decode(await ImmutableBuffer.fromUint8List(bytes));
    }
    if (!video && source.startsWith('content://')) {
      final full = await UriContent().from(Uri.parse(source));
      return decode(await ImmutableBuffer.fromUint8List(full), getTargetSize: (_, _) => const TargetImageSize(width: 128));
    }
    throw StateError('No thumbnail for $source');
  }

  @override
  bool operator ==(Object other) => other is _AndroidThumbnailImage && other.source == source && other.video == video;

  @override
  int get hashCode => Object.hash(source, video);
}
