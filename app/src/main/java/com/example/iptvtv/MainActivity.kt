package com.example.iptvtv

import android.content.Context
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

data class Channel(val name: String, val logo: String?, val group: String, val url: String) {
    val id: String get() = "$name|$url"
}

object M3U {
    fun parse(text: String): List<Channel> {
        val out = mutableListOf<Channel>()
        var name: String? = null
        var logo: String? = null
        var group = "Diğer"
        for (raw in text.lineSequence()) {
            val line = raw.trim()
            if (line.startsWith("#EXTINF")) {
                val comma = line.lastIndexOf(',')
                name = if (comma >= 0) line.substring(comma + 1).trim().ifEmpty { "Kanal" } else "Kanal"
                logo = attr("tvg-logo", line)
                group = attr("group-title", line) ?: "Diğer"
            } else if (line.isNotEmpty() && !line.startsWith("#") && name != null) {
                out.add(Channel(name, logo, group, line))
                name = null
            }
        }
        return out
    }

    private fun attr(key: String, line: String): String? {
        val start = line.indexOf("$key=\"")
        if (start < 0) return null
        val from = start + key.length + 2
        val end = line.indexOf('"', from)
        if (end < 0) return null
        return line.substring(from, end).ifEmpty { null }
    }
}

fun fetch(url: String): String {
    val conn = URL(url).openConnection().apply {
        connectTimeout = 15000
        readTimeout = 30000
        setRequestProperty("User-Agent", "Mozilla/5.0")
    }
    return conn.getInputStream().bufferedReader().use { it.readText() }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(Modifier.fillMaxSize()) { App() }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FocusRow(
    text: String,
    sub: String? = null,
    selected: Boolean = false,
    onLongClick: (() -> Unit)? = null,
    onClick: () -> Unit
) {
    var focused by remember { mutableStateOf(false) }
    Column(
        Modifier
            .fillMaxWidth()
            .onFocusChanged { focused = it.hasFocus }
            .background(
                when {
                    focused -> Color(0xFF3D5AFE)
                    selected -> Color(0xFF2A2A2A)
                    else -> Color.Transparent
                }
            )
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Text(text, fontSize = 18.sp)
        if (sub != null) Text(sub, fontSize = 13.sp, color = Color.Gray)
    }
}

@Composable
fun App() {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("iptv", Context.MODE_PRIVATE) }
    val scope = rememberCoroutineScope()

    var playlist by remember { mutableStateOf(prefs.getString("playlist", "") ?: "") }
    var channels by remember { mutableStateOf(emptyList<Channel>()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var group by remember { mutableStateOf("Tümü") }
    var favs by remember { mutableStateOf(prefs.getStringSet("fav", emptySet())?.toSet() ?: emptySet()) }
    var showSettings by remember { mutableStateOf(playlist.isBlank()) }
    var playing by remember { mutableStateOf<Pair<List<Channel>, Int>?>(null) }

    fun load() {
        scope.launch {
            loading = true
            error = null
            try {
                val text = withContext(Dispatchers.IO) { fetch(playlist.trim()) }
                channels = M3U.parse(text)
                if (channels.isEmpty()) error = "Listede kanal bulunamadı."
            } catch (e: Exception) {
                error = "Liste yüklenemedi: ${e.message}"
            }
            loading = false
        }
    }

    LaunchedEffect(Unit) { if (playlist.isNotBlank()) load() }

    val p = playing
    if (p != null) {
        PlayerScreen(p.first, p.second) { playing = null }
        return
    }

    val groups = remember(channels) { listOf("Tümü", "Favoriler") + channels.map { it.group }.distinct().sorted() }
    val filtered = remember(channels, group, favs) {
        when (group) {
            "Tümü" -> channels
            "Favoriler" -> channels.filter { it.id in favs }
            else -> channels.filter { it.group == group }
        }
    }

    Row(Modifier.fillMaxSize()) {
        LazyColumn(Modifier.width(260.dp).fillMaxHeight().padding(8.dp)) {
            item { FocusRow("⚙  Ayarlar") { showSettings = true } }
            item { FocusRow("⟳  Yenile") { if (playlist.isNotBlank()) load() } }
            items(groups) { g -> FocusRow(g, selected = g == group) { group = g } }
        }
        Box(Modifier.weight(1f).fillMaxHeight()) {
            when {
                loading -> CircularProgressIndicator(Modifier.align(Alignment.Center))
                filtered.isEmpty() -> Text(
                    error ?: "Kanal yok. Ayarlar'dan M3U bağlantısı ekleyin.",
                    Modifier.align(Alignment.Center).padding(24.dp)
                )
                else -> LazyColumn(Modifier.fillMaxSize().padding(8.dp)) {
                    itemsIndexed(filtered) { i, c ->
                        FocusRow(
                            text = c.name,
                            sub = c.group + if (c.id in favs) "  ★" else "",
                            onLongClick = {
                                val n = if (c.id in favs) favs - c.id else favs + c.id
                                favs = n
                                prefs.edit().putStringSet("fav", n).apply()
                            }
                        ) { playing = filtered to i }
                    }
                }
            }
        }
    }

    if (showSettings) {
        var text by remember { mutableStateOf(playlist) }
        AlertDialog(
            onDismissRequest = { if (playlist.isNotBlank()) showSettings = false },
            title = { Text("M3U Bağlantısı") },
            text = {
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    singleLine = true,
                    placeholder = { Text("http://...") }
                )
            },
            confirmButton = {
                Button(onClick = {
                    playlist = text.trim()
                    prefs.edit().putString("playlist", playlist).apply()
                    showSettings = false
                    load()
                }) { Text("Kaydet ve Yükle") }
            },
            dismissButton = { TextButton(onClick = { showSettings = false }) { Text("İptal") } }
        )
    }
}

@Composable
fun PlayerScreen(list: List<Channel>, start: Int, onExit: () -> Unit) {
    val ctx = LocalContext.current
    var index by remember { mutableIntStateOf(start) }
    var showInfo by remember { mutableStateOf(true) }
    val player = remember { ExoPlayer.Builder(ctx).build() }
    val focus = remember { FocusRequester() }

    DisposableEffect(Unit) { onDispose { player.release() } }
    LaunchedEffect(index) {
        player.setMediaItem(MediaItem.fromUri(list[index].url))
        player.prepare()
        player.playWhenReady = true
        showInfo = true
        delay(3000)
        showInfo = false
    }
    LaunchedEffect(Unit) { focus.requestFocus() }
    BackHandler(onBack = onExit)

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .onKeyEvent { e ->
                if (e.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (e.key) {
                    Key.DirectionUp, Key.ChannelUp -> { index = (index + 1) % list.size; true }
                    Key.DirectionDown, Key.ChannelDown -> { index = (index - 1 + list.size) % list.size; true }
                    Key.DirectionCenter, Key.Enter, Key.MediaPlayPause -> {
                        player.playWhenReady = !player.playWhenReady
                        true
                    }
                    else -> false
                }
            }
            .focusRequester(focus)
            .focusable()
    ) {
        AndroidView(
            factory = { PlayerView(it).apply { this.player = player; useController = false } },
            modifier = Modifier.fillMaxSize()
        )
        if (showInfo) {
            Text(
                "${index + 1}. ${list[index].name}",
                Modifier
                    .align(Alignment.BottomStart)
                    .padding(24.dp)
                    .background(Color(0x99000000))
                    .padding(12.dp),
                fontSize = 22.sp
            )
        }
    }
}
