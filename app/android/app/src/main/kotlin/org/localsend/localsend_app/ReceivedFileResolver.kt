package org.localsend.localsend_app

import android.content.ContentUris
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

private const val TAG = "TapShare"

/**
 * Finds a viewable content URI for a received file, so the "Received" notification
 * can open the file itself. Blocking: call off the main thread.
 */
object ReceivedFileResolver {
    fun resolve(context: Context, path: String?, name: String?, gallery: Boolean): Uri? = try {
        when {
            path?.startsWith("content://") == true -> Uri.parse(path) // SAF destination
            path != null -> scan(context, path)
            gallery && name != null -> findInGallery(context, name)
            else -> null
        }
    } catch (e: Exception) {
        Log.w(TAG, "Cannot resolve received file", e)
        null
    }

    /// A plain file path: the media scanner indexes it and hands back a content URI.
    private fun scan(context: Context, path: String): Uri? {
        var result: Uri? = null
        val done = CountDownLatch(1)
        MediaScannerConnection.scanFile(context, arrayOf(path), null) { _, uri ->
            result = uri
            done.countDown()
        }
        done.await(3, TimeUnit.SECONDS)
        return result
    }

    /// Saved to the gallery (path is null then): the newest image or video with that name,
    /// else the newest one this app saved (the name gets a suffix like " (1)" on conflicts).
    private fun findInGallery(context: Context, name: String): Uri? =
        newest(context, "${MediaStore.MediaColumns.DISPLAY_NAME} = ?", arrayOf(name))
            ?: newest(context, "${MediaStore.MediaColumns.OWNER_PACKAGE_NAME} = ?", arrayOf(context.packageName))

    private fun newest(context: Context, selection: String, args: Array<String>): Uri? {
        var best: Pair<Uri, Long>? = null
        for (collection in listOf(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, MediaStore.Video.Media.EXTERNAL_CONTENT_URI)) {
            context.contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DATE_ADDED),
                selection,
                args,
                "${MediaStore.MediaColumns.DATE_ADDED} DESC",
            )?.use { cursor ->
                if (cursor.moveToFirst() && cursor.getLong(1) > (best?.second ?: -1)) {
                    best = ContentUris.withAppendedId(collection, cursor.getLong(0)) to cursor.getLong(1)
                }
            }
        }
        return best?.first
    }
}
