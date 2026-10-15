package com.example.castlite

import java.net.URI
import java.net.URL

/** Preserva a classificação das listas aninhadas, mesmo sem extensão na URL. */
internal object HlsPlaylist {
    const val MIME = "application/vnd.apple.mpegurl"

    /** Mantém adaptação nas variantes menores, sem remover áudio, legendas ou chaves. */
    fun economical(text: String): String {
        val lines = text.lines()
        data class Variant(val tag: Int, val uri: Int, val rate: Long, val height: Int?)
        val variants = lines.mapIndexedNotNull { index, line ->
            if (!line.trim().startsWith("#EXT-X-STREAM-INF:")) return@mapIndexedNotNull null
            val attributes = parseAttributes(line.substringAfter(':'))
            val rate = attributes["BANDWIDTH"]?.toLongOrNull()?.takeIf { it > 0 }
                ?: return@mapIndexedNotNull null
            val uri = (index + 1 until lines.size).firstOrNull { lines[it].isNotBlank() }
                ?: return@mapIndexedNotNull null
            if (lines[uri].trim().startsWith("#")) return@mapIndexedNotNull null
            Variant(index, uri, rate, attributes["RESOLUTION"]?.substringAfter('x')?.toIntOrNull())
        }
        if (variants.isEmpty()) return text
        // Sem metadados de todas as variantes, preserva o manifesto original.
        if (variants.size != lines.count { it.trim().startsWith("#EXT-X-STREAM-INF:") }) return text
        val allowed = variants.filter { it.rate <= 3_000_000 && (it.height ?: 0) <= 720 }
            .ifEmpty { listOf(variants.minBy { it.rate }) }.toSet()
        val removed = variants.filterNot { it in allowed }.flatMap { listOf(it.tag, it.uri) }.toSet()
        return lines.filterIndexed { index, _ -> index !in removed }.joinToString("\n")
    }

    fun isPlaylist(url: String, responseType: String?, declaredType: String?): Boolean =
        listOf(responseType, declaredType).any { it.orEmpty().contains("mpegurl", true) } ||
            url.substringBefore('?').endsWith(".m3u8", true)

    /** Returns only numeric quality metadata; never includes variant URLs or other attributes. */
    fun qualitySummary(text: String): String? {
        val manifest = text.trimStart('\uFEFF', ' ', '\t', '\r', '\n')
        if (!manifest.startsWith("#EXTM3U")) return null
        val variants = manifest.lineSequence().mapNotNull { line ->
            val tag = line.trim()
            if (!tag.startsWith("#EXT-X-STREAM-INF:", ignoreCase = true)) return@mapNotNull null
            val attributes = parseAttributes(tag.substringAfter(':'))
            val resolution = attributes["RESOLUTION"]
                ?.takeIf { Regex("""\d{1,5}x\d{1,5}""").matches(it) }
            val bandwidth = attributes["BANDWIDTH"]?.toLongOrNull()
            val averageBandwidth = attributes["AVERAGE-BANDWIDTH"]?.toLongOrNull()
            buildString {
                append("resolution=").append(resolution ?: "unknown")
                append(" bandwidth=").append(bandwidth?.let { "${it / 1000}kbps" } ?: "unknown")
                if (averageBandwidth != null) append(" avg=").append("${averageBandwidth / 1000}kbps")
            }
        }.toList()
        if (variants.isEmpty()) return null
        val visible = variants.take(MAX_LOGGED_VARIANTS)
        val details = visible.mapIndexed { index, variant -> "#${index + 1} $variant" }.joinToString(" | ")
        val omitted = variants.size - visible.size
        return "master variants=${variants.size}: $details" + if (omitted > 0) " | $omitted variants omitted" else ""
    }

    private fun parseAttributes(input: String): Map<String, String> {
        val parts = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        input.forEach { character ->
            if (character == '"') inQuotes = !inQuotes
            if (character == ',' && !inQuotes) {
                parts += current.toString()
                current.setLength(0)
            } else {
                current.append(character)
            }
        }
        parts += current.toString()
        return parts.mapNotNull { part ->
            val separator = part.indexOf('=')
            if (separator <= 0) return@mapNotNull null
            part.substring(0, separator).trim().uppercase(java.util.Locale.ROOT) to
            part.substring(separator + 1).trim().removeSurrounding("\"")
        }.toMap()
    }

    private fun variantQualitySummary(input: String): String {
        val attributes = parseAttributes(input)
        val resolution = attributes["RESOLUTION"]
            ?.takeIf { Regex("""\d{1,5}x\d{1,5}""").matches(it) }
        val bandwidth = attributes["BANDWIDTH"]?.toLongOrNull()
        val averageBandwidth = attributes["AVERAGE-BANDWIDTH"]?.toLongOrNull()
        return buildString {
            append("resolution=").append(resolution ?: "unknown")
            append(" bandwidth=").append(bandwidth?.let { "${it / 1000}kbps" } ?: "unknown")
            if (averageBandwidth != null) append(" avg=").append("${averageBandwidth / 1000}kbps")
        }
    }

    fun rewrite(text: String, baseUrl: String, register: (String, String?) -> String): String =
        rewrite(text, baseUrl) { target, mimeType, _ -> register(target, mimeType) }

    fun rewrite(text: String, baseUrl: String, register: (String, String?, String?) -> String): String {
        require(text.trimStart('\uFEFF', ' ', '\r', '\n').startsWith("#EXTM3U"))
        fun proxied(reference: String, playlist: Boolean, variantQuality: String? = null): String {
            val target = runCatching { URL(URL(baseUrl), reference).toString() }.getOrNull() ?: return reference
            val uri = runCatching { URI(target) }.getOrNull() ?: return reference
            if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) return reference
            return register(target, if (playlist) MIME else null, variantQuality.takeIf { playlist })
        }
        val uriAttribute = Regex("(?i)(URI\\s*=\\s*\")([^\"]+)(\")")
        val lines = text.lineSequence().toList()
        val audioLines = lines.mapIndexedNotNull { index, line ->
            line.trim().takeIf { it.startsWith("#EXT-X-MEDIA:") && isAudioRendition(it) }?.let { index to it }
        }
        val preferredAudioIndex = audioLines.firstOrNull { isPortugueseRendition(it.second) }?.first
        var nextIsPlaylist = false
        var nextVariantQuality: String? = null
        val rewrittenLines = lines.mapIndexed { index, line ->
            val trimmed = line.trim()
            when {
                trimmed.isEmpty() -> line
                trimmed.startsWith("#EXT-X-STREAM-INF:") -> {
                    nextIsPlaylist = true
                    nextVariantQuality = variantQualitySummary(trimmed.substringAfter(':'))
                    line
                }
                trimmed.startsWith("#") -> {
                    val playlist = listOf("#EXT-X-MEDIA:", "#EXT-X-I-FRAME-STREAM-INF:",
                        "#EXT-X-RENDITION-REPORT:").any { trimmed.startsWith(it) }
                    val rewritten = uriAttribute.replace(line) { match ->
                        match.groupValues[1] + proxied(match.groupValues[2], playlist) + match.groupValues[3]
                    }
                    if (preferredAudioIndex != null && trimmed.startsWith("#EXT-X-MEDIA:") && isAudioRendition(trimmed)) {
                        setDefault(rewritten, index == preferredAudioIndex)
                    } else rewritten
                }
                else -> proxied(trimmed, nextIsPlaylist, nextVariantQuality).also {
                    nextIsPlaylist = false
                    nextVariantQuality = null
                }
            }
        }
        return rewrittenLines.joinToString("\n")
    }

    private val defaultAttribute = Regex("(?i)(,DEFAULT=)(YES|NO)")

    private val typeAttribute = Regex(
        """(?:^|[:,])\s*TYPE\s*=\s*"?([^",\s]+)""",
        RegexOption.IGNORE_CASE,
    )

    private fun isAudioRendition(attributes: String): Boolean =
        typeAttribute.find(attributes)?.groupValues?.getOrNull(1)
            ?.equals("AUDIO", ignoreCase = true) == true

    private fun isPortugueseRendition(attributes: String): Boolean {
        val language = Regex("(?i)LANGUAGE=\"?([^\",]+)\"?").find(attributes)?.groupValues?.get(1)
            ?.lowercase()?.replace('_', '-')
        if (language != null && (language == "pt" || language.startsWith("pt-") || language == "por")) return true
        val name = Regex("(?i)NAME=\"([^\"]+)\"").find(attributes)?.groupValues?.get(1)?.lowercase()
        return name != null && (name.contains("portugu") || name.contains("dublad"))
    }

    private fun setDefault(line: String, preferred: Boolean): String {
        val value = if (preferred) "YES" else "NO"
        return if (defaultAttribute.containsMatchIn(line)) {
            defaultAttribute.replace(line, "$1$value")
        } else if (preferred) {
            line + ",DEFAULT=YES"
        } else line
    }

    private const val MAX_LOGGED_VARIANTS = 20
}
