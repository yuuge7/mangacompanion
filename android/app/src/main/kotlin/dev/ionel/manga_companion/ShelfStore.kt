package dev.ionel.manga_companion

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * The shelf as the Flutter app saves it: one JSON array string in the
 * plugin's SharedPreferences file. The widget reads and edits it in place,
 * mirroring the app's own rules in lib/models/manga_entry.dart.
 */
object ShelfStore {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.manga-entries-v1"

    /** Same as MangaEntry._foldWindow: steps this close fold into one event. */
    private const val FOLD_MS = 30L * 60 * 1000

    /** Called on the main thread after the widget changes the shelf. */
    @Volatile
    var onChanged: (() -> Unit)? = null

    fun load(context: Context): JSONArray? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            null // damaged; never overwrite it from here
        }
    }

    private fun save(context: Context, shelf: JSONArray) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, shelf.toString()).commit()
    }

    /** Titles on the reading shelf, most recently touched first. */
    fun reading(shelf: JSONArray): List<JSONObject> =
        (0 until shelf.length())
            .mapNotNull { shelf.optJSONObject(it) }
            .filter { it.optString("status", "reading") == "reading" }
            .sortedByDescending { it.optLong("lastUpdated") }

    fun total(e: JSONObject): Int? =
        if (e.isNull("totalChapters")) null else e.optInt("totalChapters").takeIf { it > 0 }

    fun isDone(e: JSONObject): Boolean {
        val total = total(e) ?: return false
        return e.optInt("currentChapter") >= total
    }

    private fun find(shelf: JSONArray, id: String): JSONObject? =
        (0 until shelf.length())
            .mapNotNull { shelf.optJSONObject(it) }
            .firstOrNull { it.optString("id") == id }

    /** One chapter forward, logged in the title's history. */
    fun bump(context: Context, id: String): Boolean {
        val shelf = load(context) ?: return false
        val e = find(shelf, id) ?: return false
        if (isDone(e)) return false
        val now = System.currentTimeMillis()
        val from = e.optInt("currentChapter")
        e.put("currentChapter", from + 1)
        e.put("lastUpdated", now)
        if (e.isNull("startedAt")) e.put("startedAt", now)
        val status = e.optString("status")
        if (status == "planned" || status == "on-hold") e.put("status", "reading")
        appendEvent(e, now, from, from + 1)
        save(context, shelf)
        return true
    }

    fun markRead(context: Context, id: String): Boolean {
        val shelf = load(context) ?: return false
        val e = find(shelf, id) ?: return false
        val now = System.currentTimeMillis()
        e.put("status", "read")
        e.put("lastUpdated", now)
        e.put("finishedAt", now)
        save(context, shelf)
        return true
    }

    /** Mirrors MangaEntry.appendEvent. */
    private fun appendEvent(e: JSONObject, now: Long, from: Int, to: Int) {
        val history = e.optJSONArray("history") ?: JSONArray().also { e.put("history", it) }
        val last = if (history.length() > 0) history.optJSONArray(history.length() - 1) else null
        if (last != null && last.length() >= 3) {
            val lastAt = last.optLong(0)
            val lastFrom = last.optInt(1)
            val lastTo = last.optInt(2)
            if (lastTo == from && now - lastAt < FOLD_MS && sameDay(lastAt, now)) {
                history.remove(history.length() - 1)
                if (lastFrom != to) history.put(JSONArray().put(now).put(lastFrom).put(to))
                return
            }
        }
        history.put(JSONArray().put(now).put(from).put(to))
    }

    private fun sameDay(a: Long, b: Long): Boolean {
        val x = Calendar.getInstance().apply { timeInMillis = a }
        val y = Calendar.getInstance().apply { timeInMillis = b }
        return x.get(Calendar.YEAR) == y.get(Calendar.YEAR) &&
            x.get(Calendar.DAY_OF_YEAR) == y.get(Calendar.DAY_OF_YEAR)
    }
}
