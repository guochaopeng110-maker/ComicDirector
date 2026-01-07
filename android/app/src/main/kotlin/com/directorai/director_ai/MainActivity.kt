package com.directorai.director_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import android.util.Log
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Build
import android.content.Context
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.directorai.director_ai/video_merge"
    private val TAG = "VideoMerge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "mergeVideosLossless" -> {
                    @Suppress("UNCHECKED_CAST")
                    val inputPaths = call.argument<List<String>>("inputPaths")
                    val outputPath = call.argument<String>("outputPath")

                    if (inputPaths == null || outputPath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing inputPaths or outputPath", null)
                        return@setMethodCallHandler
                    }

                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            val mergedPath = mergeVideosLossless(inputPaths, outputPath)
                            withContext(Dispatchers.Main) {
                                result.success(mergedPath)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Video merge failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("MERGE_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "saveVideoToGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }

                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            val savedPath = saveVideoToGallery(filePath)
                            withContext(Dispatchers.Main) {
                                result.success(savedPath)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to save video to gallery", e)
                            withContext(Dispatchers.Main) {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "saveImageToGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "Missing filePath", null)
                        return@setMethodCallHandler
                    }

                    GlobalScope.launch(Dispatchers.IO) {
                        try {
                            val savedPath = saveImageToGallery(filePath)
                            withContext(Dispatchers.Main) {
                                result.success(savedPath)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to save image to gallery", e)
                            withContext(Dispatchers.Main) {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 使用 Android MediaMuxer API 合并多个视频文件
     * 这是最可靠的无损视频合并方案
     *
     * @param inputPaths 输入视频文件路径列表
     * @param outputPath 输出视频文件路径
     * @return 合并后的视频文件路径
     */
    private suspend fun mergeVideosLossless(inputPaths: List<String>, outputPath: String): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Starting video merge of ${inputPaths.size} videos")

                // 验证输入文件存在
                for (path in inputPaths) {
                    val file = File(path)
                    if (!file.exists()) {
                        throw IllegalArgumentException("Input file does not exist: $path")
                    }
                }

                // 合并视频
                mergeWithMediaMuxer(inputPaths, outputPath)

                Log.d(TAG, "Video merge completed: $outputPath")
                outputPath

            } catch (e: Exception) {
                Log.e(TAG, "Error during video merge", e)
                throw e
            }
        }
    }

    /**
     * 使用 MediaMuxer 合并视频
     * 这是 Android 原生的无损视频合并方案
     */
    private fun mergeWithMediaMuxer(inputPaths: List<String>, outputPath: String) {
        Log.d(TAG, "Using MediaMuxer for video merging")

        var muxer: MediaMuxer? = null
        try {
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            var videoTrackIndex = -1
            var audioTrackIndex = -1
            var videoFormat: MediaFormat? = null
            var audioFormat: MediaFormat? = null

            // 从第一个视频获取格式信息
            val firstExtractor = MediaExtractor()
            firstExtractor.setDataSource(inputPaths[0])

            for (i in 0 until firstExtractor.trackCount) {
                val format = firstExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)

                if (mime?.startsWith("video/") == true && videoFormat == null) {
                    videoFormat = format
                    Log.d(TAG, "Found video track: $mime")
                } else if (mime?.startsWith("audio/") == true && audioFormat == null) {
                    audioFormat = format
                    Log.d(TAG, "Found audio track: $mime")
                }
            }
            firstExtractor.release()

            // 添加轨道到 muxer
            if (videoFormat != null) {
                videoTrackIndex = muxer.addTrack(videoFormat)
                Log.d(TAG, "Added video track at index: $videoTrackIndex")
            }
            if (audioFormat != null) {
                audioTrackIndex = muxer.addTrack(audioFormat)
                Log.d(TAG, "Added audio track at index: $audioTrackIndex")
            }

            muxer.start()

            // 合并所有视频
            val buffer = java.nio.ByteBuffer.allocate(1024 * 1024)
            val info = android.media.MediaCodec.BufferInfo()

            var videoTimeOffset = 0L
            var audioTimeOffset = 0L

            for ((index, inputPath) in inputPaths.withIndex()) {
                Log.d(TAG, "Processing video ${index + 1}/${inputPaths.size}: $inputPath")

                val extractor = MediaExtractor()
                extractor.setDataSource(inputPath)

                // 首先获取当前文件的视频和音频轨道索引
                var currentVideoTrackIndex = -1
                var currentAudioTrackIndex = -1

                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME)

                    if (mime?.startsWith("video/") == true && videoTrackIndex >= 0) {
                        currentVideoTrackIndex = i
                    } else if (mime?.startsWith("audio/") == true && audioTrackIndex >= 0) {
                        currentAudioTrackIndex = i
                    }
                }

                // 处理视频轨道
                if (currentVideoTrackIndex >= 0) {
                    extractor.selectTrack(currentVideoTrackIndex)
                    // 读取并丢弃样本数据到第一个样本，以获取正确的时间戳
                    extractor.readSampleData(buffer, 0)
                    val firstVideoTime = extractor.sampleTime
                    extractor.unselectTrack(currentVideoTrackIndex)
                    extractor.selectTrack(currentVideoTrackIndex)

                    val (samplesWritten, endTime) = copyTrack(
                        extractor,
                        muxer,
                        videoTrackIndex,
                        buffer,
                        info,
                        videoTimeOffset,
                        firstVideoTime,
                        true
                    )
                    videoTimeOffset = endTime
                    Log.d(TAG, "Wrote $samplesWritten video samples from file ${index + 1}, new offset: $videoTimeOffset")
                }

                // 处理音频轨道
                if (currentAudioTrackIndex >= 0) {
                    extractor.selectTrack(currentAudioTrackIndex)
                    // 读取并丢弃样本数据到第一个样本，以获取正确的时间戳
                    extractor.readSampleData(buffer, 0)
                    val firstAudioTime = extractor.sampleTime
                    extractor.unselectTrack(currentAudioTrackIndex)
                    extractor.selectTrack(currentAudioTrackIndex)

                    val (samplesWritten, endTime) = copyTrack(
                        extractor,
                        muxer,
                        audioTrackIndex,
                        buffer,
                        info,
                        audioTimeOffset,
                        firstAudioTime,
                        false
                    )
                    audioTimeOffset = endTime
                    Log.d(TAG, "Wrote $samplesWritten audio samples from file ${index + 1}, new offset: $audioTimeOffset")
                }

                extractor.release()
            }

            muxer.stop()
            Log.d(TAG, "MediaMuxer merge completed successfully")

        } finally {
            muxer?.release()
        }
    }

    /**
     * 复制轨道数据
     * @param firstSampleTime 第一个样本的时间戳（需要在调用前获取）
     * @return Pair<样本数量, 结束时间戳>
     */
    private fun copyTrack(
        extractor: MediaExtractor,
        muxer: MediaMuxer,
        trackIndex: Int,
        buffer: java.nio.ByteBuffer,
        info: android.media.MediaCodec.BufferInfo,
        timeOffset: Long,
        firstSampleTime: Long,
        isVideo: Boolean
    ): Pair<Int, Long> {
        var sampleCount = 0
        var endTime = timeOffset
        var sawInputEOS = false

        // 计算实际偏移量，使得第一个样本被映射到 timeOffset 位置
        val actualOffset = timeOffset - firstSampleTime

        Log.d(TAG, "  copyTrack: firstSampleTime=$firstSampleTime, timeOffset=$timeOffset, actualOffset=$actualOffset")

        while (!sawInputEOS) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) {
                sawInputEOS = true
                info.size = 0
            } else {
                info.size = sampleSize
                info.offset = 0

                val originalTime = extractor.sampleTime
                info.presentationTimeUs = originalTime + actualOffset

                // 更新结束时间（最后一个样本的时间）
                if (originalTime >= 0) {
                    endTime = originalTime + actualOffset
                }

                info.flags = extractor.sampleFlags

                muxer.writeSampleData(trackIndex, buffer, info)
                extractor.advance()
                sampleCount++
            }
        }

        Log.d(TAG, "  copyTrack: wrote $sampleCount samples, endTime=$endTime")
        return Pair(sampleCount, endTime)
    }

    /**
     * 保存视频到相册
     */
    private fun saveVideoToGallery(filePath: String): String {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Source file does not exist: $filePath")
        }

        val contentResolver = applicationContext.contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "Video_${System.currentTimeMillis()}.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Movies")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, contentValues)

        uri?.let {
            contentResolver.openOutputStream(it)?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            }

            contentValues.clear()
            contentValues.put(MediaStore.Video.Media.IS_PENDING, 0)
            contentResolver.update(it, contentValues, null, null)

            Log.d(TAG, "Video saved to gallery: $it")
            return it.toString()
        } ?: throw IllegalStateException("Failed to create MediaStore entry")

    }

    /**
     * 保存图片到相册
     */
    private fun saveImageToGallery(filePath: String): String {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Source file does not exist: $filePath")
        }

        val contentResolver = applicationContext.contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "Image_${System.currentTimeMillis()}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Movies")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

        uri?.let {
            contentResolver.openOutputStream(it)?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            }

            contentValues.clear()
            contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(it, contentValues, null, null)

            Log.d(TAG, "Image saved to gallery: $it")
            return it.toString()
        } ?: throw IllegalStateException("Failed to create MediaStore entry")

    }
}

