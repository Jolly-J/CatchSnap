/**
 * @file: MainActivity.kt
 * @description: Android 主 Activity 与 Flutter 核心 MethodChannel 调度中心
 * @author: Antigravity
 * @version: 2.0.0
 */

package com.example.douyin_downloader

import android.content.ContentValues
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.douyin_downloader/floating"
    private val ioExecutor = Executors.newCachedThreadPool()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 原生级全屏 Edge-to-Edge 沉浸式适配（兼容 Android 10~15+ 挖孔屏与手势导航条）
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 启动时即注册高优实时活动渠道并移除旧版静默渠道
        DownloadForegroundService.initChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Android 系统原生实时活动 / 流体云调度 (Foreground Service) ──
                "startLiveActivity" -> {
                    val title = call.argument<String>("title") ?: "正在下载媒体"
                    val progress = call.argument<Int>("progress") ?: 0
                    val speed = call.argument<String>("speed") ?: ""
                    DownloadForegroundService.start(this, title, progress, speed)
                    result.success(null)
                }
                "updateLiveActivity" -> {
                    val progress = call.argument<Int>("progress") ?: 0
                    val speed = call.argument<String>("speed") ?: ""
                    DownloadForegroundService.update(this, progress, speed)
                    result.success(null)
                }
                "stopLiveActivity" -> {
                    val isSuccess = call.argument<Boolean>("isSuccess") ?: true
                    val title = call.argument<String>("title") ?: ""
                    DownloadForegroundService.stop(this, isSuccess, title)
                    result.success(null)
                }

                // ── 提取与管理 Web 登录 Cookie（包含 HttpOnly 核心会话凭据） ──
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: ""
                    android.webkit.CookieManager.getInstance().flush()
                    val cookie = android.webkit.CookieManager.getInstance().getCookie(url) ?: ""
                    result.success(cookie)
                }
                "clearCookies" -> {
                    val cm = android.webkit.CookieManager.getInstance()
                    cm.removeAllCookies {
                        cm.flush()
                        result.success(true)
                    }
                }

                // ── 相册与媒体库安全归档 (后台 IO 线程异步写入，彻底杜绝主线程卡死) ──
                "saveFileToGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    val albumName = call.argument<String>("albumName") ?: "咔捕"
                    val fileName = call.argument<String>("fileName")

                    if (filePath == null || fileName == null) {
                        result.error("INVALID_ARGS", "文件路径或文件名为空", null)
                        return@setMethodCallHandler
                    }

                    ioExecutor.execute {
                        try {
                            saveToGallery(filePath, albumName, fileName)
                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
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
     * 将临时文件安全写入 Android 系统 MediaStore 相册库
     */
    private fun saveToGallery(filePath: String, albumName: String, fileName: String) {
        val file = File(filePath)
        val isVideo = fileName.endsWith(".mp4", ignoreCase = true)
        val mimeType = if (isVideo) "video/mp4" else "image/jpeg"
        val safeAlbum = albumName.replace(Regex("[*?\"<>|]"), "_")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ Scoped Storage 方式
            val collection = if (isVideo)
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

            val baseDir = if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
            val relativePath = "$baseDir/$safeAlbum"

            val values = ContentValues().apply {
                put(if (isVideo) MediaStore.Video.Media.DISPLAY_NAME else MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(if (isVideo) MediaStore.Video.Media.MIME_TYPE else MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(if (isVideo) MediaStore.Video.Media.RELATIVE_PATH else MediaStore.Images.Media.RELATIVE_PATH, relativePath)
                put(if (isVideo) MediaStore.Video.Media.IS_PENDING else MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = contentResolver.insert(collection, values)
                ?: throw Exception("MediaStore 插入记录失败: $relativePath")

            contentResolver.openOutputStream(uri)?.use { output ->
                FileInputStream(file).use { input -> input.copyTo(output) }
            }

            values.clear()
            values.put(if (isVideo) MediaStore.Video.Media.IS_PENDING else MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)

            // 触发系统媒体库扫描，通知相册服务解析并索引 Motion Photo XMP
            try {
                android.media.MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(file.absolutePath),
                    arrayOf(mimeType),
                    null
                )
            } catch (_: Exception) {}
        } else {
            // Android 9 及以下方式
            val baseDir = Environment.getExternalStoragePublicDirectory(
                if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
            )
            val dir = File(baseDir, safeAlbum)
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, fileName)
            file.copyTo(dest, overwrite = true)
            sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(dest)))
        }
    }
}
