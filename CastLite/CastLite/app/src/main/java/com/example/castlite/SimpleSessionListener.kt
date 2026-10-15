package com.example.castlite

import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener

/** Listener de sessão Cast que só avisa quando o estado de conexão muda. */
class SimpleSessionListener(
    private val onChange: () -> Unit,
    private val onError: (Int) -> Unit
) : SessionManagerListener<CastSession> {
    override fun onSessionStarted(session: CastSession, sessionId: String) = onChange()
    override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = onChange()
    override fun onSessionEnded(session: CastSession, error: Int) = onChange()
    override fun onSessionSuspended(session: CastSession, reason: Int) = onChange()
    override fun onSessionStarting(session: CastSession) {}
    override fun onSessionStartFailed(session: CastSession, error: Int) { onChange(); onError(error) }
    override fun onSessionEnding(session: CastSession) = onChange()
    override fun onSessionResuming(session: CastSession, sessionId: String) {}
    override fun onSessionResumeFailed(session: CastSession, error: Int) { onChange(); onError(error) }
}
