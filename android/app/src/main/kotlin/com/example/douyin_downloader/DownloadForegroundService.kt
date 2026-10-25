/**
 * @file: DownloadForegroundService.kt
 * @description: Android 官方标准前台服务实时活动 (Foreground Service Live Activity)
 *               对接各品牌安卓系统 (ColorOS 流体云、HyperOS 焦点通知、OriginOS 原子岛等)
 * @author: Antigravity
 * @version: 2.0.0
 */

package com.example.douyin_downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class DownloadForegroundService : Service() {

    companion object {
        private const val LEGACY_CHANNEL_ID = "download_live_activity"
        const val CHANNEL_ID = "kabu_live_activity_v2"
        const val CHANNEL_NAME = "下载实时活动"
        const val NOTIFICATION_ID = 1001

        private const val ACTION_START = "ACTION_START"
        private const val ACTION_UPDATE = "ACTION_UPDATE"
        private const val ACTION_STOP = "ACTION_STOP"

        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_PROGRESS = "extra_progress"
        private const val EXTRA_SPEED = "extra_speed"
        private const val EXTRA_SUCCESS = "extra_success"

        @Volatile
        private var isRunning = false

        @Volatile
        private var lastNotifyTimeMs = 0L

        @Volatile
        private var lastNotifiedProgress = -1

        /**
         * 应用冷启动时预初始化通知渠道，并清理旧版静默渠道
         */
        fun initChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                try {
                    manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
                } catch (_: Exception) {
                }
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "媒体下载实时活动与流体云进度"
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                    enableLights(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            }
        }

        /**
         * 启动前台下载服务（触发系统流体云 / 实时活动）
         */
        fun start(context: Context, title: String, progress: Int = 0, speed: String = "") {
            lastNotifyTimeMs = SystemClock.elapsedRealtime()
            lastNotifiedProgress = progress
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_SPEED, speed)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
            }
        }

        /**
         * 实时更新进度与网速（内置节流保护，防止高频 IPC 导致主线程卡死或通知被系统丢弃）
         */
        fun update(context: Context, progress: Int, speed: String) {
            if (!isRunning) return
            val now = SystemClock.elapsedRealtime()
            val clamped = progress.coerceIn(0, 100)
            // 节流：距离上次通知不足 300ms 且未到达 100% 时直接跳过
            if (now - lastNotifyTimeMs < 300 && clamped < 100) {
                return
            }
            if (clamped == lastNotifiedProgress && now - lastNotifyTimeMs < 800) {
                return
            }
            lastNotifyTimeMs = now
            lastNotifiedProgress = clamped

            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_PROGRESS, clamped)
                putExtra(EXTRA_SPEED, speed)
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
            }
        }

        /**
         * 下载结束或取消，收起流体云并销毁前台服务
         */
        fun stop(context: Context, isSuccess: Boolean = true, title: String = "") {
            lastNotifyTimeMs = 0L
            lastNotifiedProgress = -1
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_SUCCESS, isSuccess)
                putExtra(EXTRA_TITLE, title)
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
            }
        }
    }

    private var currentTitle: String = "正在高速下载媒体"
    private var isChannelCreated = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureNotificationChannel()
        when (intent?.action) {
            ACTION_START -> {
                isRunning = true
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: "正在高速下载媒体"
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val speed = intent.getStringExtra(EXTRA_SPEED) ?: ""
                val notification = buildLiveActivityNotification(currentTitle, progress, speed)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } catch (_: Exception) {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, notification)
                }
            }
            ACTION_UPDATE -> {
                if (!isRunning) return START_NOT_STICKY
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val speed = intent.getStringExtra(EXTRA_SPEED) ?: ""
                val notification = buildLiveActivityNotification(currentTitle, progress, speed)
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, notification)
            }
            ACTION_STOP -> {
                isRunning = false
                val isSuccess = intent.getBooleanExtra(EXTRA_SUCCESS, true)
                val finishTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                stopForegroundAndFinish(isSuccess, finishTitle)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun ensureNotificationChannel() {
        if (isChannelCreated) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // 清理旧版被归入“静默通知”的低优先级渠道
            try {
                manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
            } catch (_: Exception) {
            }

            // 流体云 / 实时活动要求渠道重要性至少为 DEFAULT 或 HIGH，绝不能为 LOW（否则会被归为静默通知无法上云）
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "媒体下载实时活动与流体云进度"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
        isChannelCreated = true
    }

    private fun createContentPendingIntent(): PendingIntent {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)
    }

    /**
     * 生成视觉等宽的流体云胶囊百分比文本，解决比例字体与位数变化导致的胶囊宽度抖动：
     * 1. 下载进行中锁定为 2 位数字槽位 (01% ~ 99%)，使用 Unicode 数字等宽空格 (\u2007) 补齐个位数；
     * 2. 针对比例字体中数字 '1' 偏窄 (约窄 1/6 em) 的特性，按 '1' 出现的次数补偿 \u2006 (Six-Per-Em Space)，
     *    使所有百分比在系统胶囊 TextView 中的渲染像素宽度保持恒定。
     */
    private fun formatFixedWidthCapsulePercent(progress: Int): String {
        val activePct = progress.coerceIn(1, 99)
        val rawDigits = activePct.toString()
        val oneCount = rawDigits.count { it == '1' }
        val widthCompensate = "\u2006".repeat(oneCount)
        val paddedDigits = if (activePct < 10) "\u2007$rawDigits" else rawDigits
        return "$widthCompensate$paddedDigits%"
    }

    /**
     * 构造支持 Android 16 Promoted Ongoing / ColorOS 流体云的标准实时活动通知
     */
    private fun buildLiveActivityNotification(title: String, progress: Int, speed: String): Notification {
        val clampedProgress = progress.coerceIn(0, 100)
        val cleanTitle = if (title.length > 22) title.substring(0, 22) + "..." else title
        val subText = if (speed.isNotEmpty()) "$clampedProgress% · $speed" else "$clampedProgress%"
        val shortStatusText = formatFixedWidthCapsulePercent(clampedProgress)

        val liveExtras = Bundle().apply {
            // Android 16 / ColorOS 15+ 实时活动流体云提升标记 (EXTRA_REQUEST_PROMOTED_ONGOING)
            putBoolean("android.requestPromotedOngoing", true)
            putString("android.shortCriticalText", shortStatusText)
            putBoolean("oplus.ongoing.promoted", true)
        }

        val largeIcon = try {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        } catch (_: Exception) {
            null
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setLargeIcon(largeIcon)
            .setContentTitle(cleanTitle)
            .setContentText(subText)
            .setSubText("咔捕")
            .setProgress(100, clampedProgress, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(createContentPendingIntent())
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addExtras(liveExtras)

        val notification = builder.build()
        // 确保底层 Notification.extras 同样写入流体云与胶囊关键字段
        notification.extras?.apply {
            putBoolean("android.requestPromotedOngoing", true)
            putString("android.shortCriticalText", shortStatusText)
        }
        return notification
    }

    private fun stopForegroundAndFinish(isSuccess: Boolean, title: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        // 下载结束时展示一条普通可划走的完成通知
        if (title.isNotEmpty()) {
            val cleanTitle = if (title.length > 22) title.substring(0, 22) + "..." else title
            val largeIcon = try {
                BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
            } catch (_: Exception) {
                null
            }
            val doneNotification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(if (isSuccess) android.R.drawable.stat_sys_download_done else android.R.drawable.stat_notify_error)
                .setLargeIcon(largeIcon)
                .setContentTitle(if (isSuccess) "咔捕 · 已保存至系统相册" else "咔捕 · 下载未完成")
                .setContentText(cleanTitle)
                .setAutoCancel(true)
                .setOngoing(false)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(createContentPendingIntent())
                .build()
            manager.notify(NOTIFICATION_ID + 1, doneNotification)
        }

        stopSelf()
    }
}
