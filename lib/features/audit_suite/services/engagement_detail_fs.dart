// Web-safe facade for file system operations used by Engagement Detail, Export History, etc.
export 'engagement_detail_fs_stub.dart'
    if (dart.library.io) 'engagement_detail_fs_io.dart';