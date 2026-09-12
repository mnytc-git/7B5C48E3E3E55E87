package eu.mnytc.app

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val DOWNLOAD_CHANNEL =
            "eu.mnytc.app/downloads"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "download") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val url = call.argument<String>("url")

                val fileName =
                    call.argument<String>("fileName")

                val folderName =
                    call.argument<String>("folderName")
                        ?: "MNYTC"

                val headers =
                    call.argument<Map<String, String>>(
                        "headers"
                    ) ?: emptyMap()

                if (url.isNullOrBlank()) {
                    result.error(
                        "INVALID_URL",
                        "Download URL is empty.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (fileName.isNullOrBlank()) {
                    result.error(
                        "INVALID_FILE_NAME",
                        "Download file name is empty.",
                        null
                    )

                    return@setMethodCallHandler
                }

                val destination =
                    "$folderName/$fileName"

                val request =
                    DownloadManager.Request(
                        Uri.parse(url)
                    )
                        .setTitle(fileName)
                        .setDescription(
                            "Downloading from MNYTC"
                        )
                        .setAllowedOverMetered(true)
                        .setAllowedOverRoaming(true)
                        .setNotificationVisibility(
                            DownloadManager.Request
                                .VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                        )
                        .setDestinationInExternalPublicDir(
                            Environment.DIRECTORY_DOWNLOADS,
                            destination
                        )

                headers.forEach { entry ->
                    val key = entry.key
                    val value = entry.value

                    if (
                        key.isNotBlank() &&
                        value.isNotBlank()
                    ) {
                        request.addRequestHeader(
                            key,
                            value
                        )
                    }
                }

                val downloadManager =
                    getSystemService(
                        Context.DOWNLOAD_SERVICE
                    ) as DownloadManager

                val downloadId =
                    downloadManager.enqueue(request)

                result.success(
                    "Download/$destination"
                )
            } catch (exception: Exception) {
                result.error(
                    "DOWNLOAD_FAILED",
                    exception.message,
                    null
                )
            }
        }
    }
}