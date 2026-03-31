class FirebaseStorageService {
  Future<String> uploadDishImage({
    required String chefId,
    required Object imageFile,
  }) async {
    return '';
  }

  Future<String> uploadProfileImage({
    required String userId,
    required Object imageFile,
  }) async {
    return '';
  }

  Future<String> uploadChefDocument({
    required String chefId,
    required String type,
    required Object file,
  }) async {
    return '';
  }

  Future<String> uploadReelVideo({
    required String chefId,
    required Object videoFile,
  }) async {
    return '';
  }

  Future<String> uploadReelThumbnail({
    required String chefId,
    required Object thumbnailFile,
  }) async {
    return '';
  }

  Future<void> deleteFile(String downloadUrl) async {
    return;
  }
}
