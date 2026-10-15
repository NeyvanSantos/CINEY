package com.example.castlite.casting.dlna

/**
 * Generates minimal DIDL-Lite XML metadata required by DLNA renderers.
 */
object DidlLiteBuilder {

    /**
     * Build a DIDL-Lite XML fragment for a video item.
     * @param title media title
     * @param url media URL (relay or original)
     * @param mimeType MIME type (e.g. "video/mp4")
     */
    fun buildVideoItem(title: String, url: String, mimeType: String): String {
        val escapedTitle = escapeXml(title)
        val escapedUrl = escapeXml(url)
        val protocolInfo = "http-get:*:$mimeType:*"
        return """<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="1" parentID="0" restricted="1"><dc:title>$escapedTitle</dc:title><upnp:class>object.item.videoItem</upnp:class><res protocolInfo="$protocolInfo">$escapedUrl</res></item></DIDL-Lite>"""
    }

    private fun escapeXml(text: String): String = text
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\"", "&quot;")
        .replace("'", "&apos;")
}
