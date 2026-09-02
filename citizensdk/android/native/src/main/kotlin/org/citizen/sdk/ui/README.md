# SDK-owned wallet flow

The non-exported `FLAG_SECURE` Activity is the only Android surface that may
accept or display recovery material. It does not save secrets in instance
state, intents, logs, clipboard, analytics or Flutter channels, and clears its
owned buffers on every terminal path.

