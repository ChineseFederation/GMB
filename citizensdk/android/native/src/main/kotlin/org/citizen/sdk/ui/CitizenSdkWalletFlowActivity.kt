package org.citizen.sdk.ui

import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.fragment.app.FragmentActivity
import org.citizen.sdk.*
import org.citizen.sdk.internal.CitizenSdkSensitiveBytes
import java.nio.CharBuffer
import java.util.concurrent.CompletionException

/** Non-exported secure recovery-phrase creation/import/account-expansion UI. */
internal class CitizenSdkWalletFlowActivity : FragmentActivity() {
    @get:JvmSynthetic
    internal var flowId: Long = 0
        private set
    private var coordinator: CitizenSdkWalletFlowCoordinator? = null
    private var prepared: CitizenSdkPreparedWallet? = null
    private var phrase: CitizenSdkRecoveryPhrase? = null
    private var recoveryContent: CitizenSdkRecoveryContent? = null
    private var terminalResult: CitizenSdkWalletFlowContract.Result? = null
    private val secretInputs = LinkedHashSet<EditText>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = finishCancelled()
            },
        )
        flowId = intent.getLongExtra(EXTRA_FLOW_ID, 0)
        coordinator = CitizenSdkWalletFlowCoordinator.consume(flowId)
        val owner = coordinator
        if (flowId == 0L || owner == null) {
            finish()
            return
        }
        owner.attach(this)
        if (isFinishing) return
        owner.sdk.attachActivity(this)
        if (savedInstanceState != null) {
            // Recover the existing coordinator before cancelling. Secrets are
            // never saved, but the original caller must still receive exactly
            // one terminal result after its parent Activity resumes.
            if (owner.requestCancellationSettlement()) showMutationInProgress()
            else finishCancelled()
            return
        }
        when (val request = owner.request) {
            is CitizenSdkWalletFlowContract.Request.Create -> showCreate(request.wordCount)
            is CitizenSdkWalletFlowContract.Request.Import -> showRecoveryInput(null)
            is CitizenSdkWalletFlowContract.Request.AddAccounts -> showRecoveryInput(request.indices.toIntArray())
        }
    }

    override fun onDestroy() {
        val owner = coordinator
        var cleanupFailure: Throwable? = null
        // EditText owns a mutable Editable that otherwise survives with the
        // destroyed View until GC. Wipe every registered secret input on Back,
        // cancellation, configuration change and external Activity teardown.
        val inputs = secretInputs.toList()
        secretInputs.clear()
        inputs.forEach { input ->
            runCatching { CitizenSdkSecretEditablePolicy.clear(input.text) }
                .onFailure { cleanupFailure = cleanupFailure ?: it }
        }
        runCatching { recoveryContent?.close() }
            .onFailure { cleanupFailure = cleanupFailure ?: it }
        runCatching { phrase?.close() }.onFailure { cleanupFailure = cleanupFailure ?: it }
        runCatching { owner?.retryPreparedRelease() ?: true }.onFailure {
            cleanupFailure = cleanupFailure ?: it
        }.onSuccess { terminal -> if (terminal) prepared = null }
        runCatching { owner?.sdk?.detachActivity(this) }.onFailure { cleanupFailure = cleanupFailure ?: it }
        owner?.activityDestroyed(this, isChangingConfigurations)
        val result = if (owner?.settlementInFlight() == true) {
            null
        } else if (cleanupFailure != null) {
            CitizenSdkWalletFlowContract.Result.Failed(
                cleanupFailure as? CitizenSdkException ?: CitizenSdkException(
                    CitizenSdkErrorCode.INTERNAL,
                    "CitizenSDK wallet flow cleanup failed",
                    cleanupFailure,
                ),
            )
        } else if (isChangingConfigurations) {
            null
        } else {
            terminalResult ?: if (isFinishing) CitizenSdkWalletFlowContract.Result.Cancelled else null
        }
        super.onDestroy()
        if (result != null) owner?.completeAfterTeardown(result)
    }

    private fun showCreate(wordCount: Int) {
        val password = secretInput("可选钱包密码")
        val action = Button(this).apply { text = "生成恢复词" }
        val cancel = Button(this).apply { text = "取消"; setOnClickListener { finishCancelled() } }
        setContentView(layout(title("创建公民钱包"), password, action, cancel))
        action.setOnClickListener {
            action.isEnabled = false
            val future = try {
                CitizenSdkSensitiveBytes.utf8(password.text).use { secret ->
                    CitizenSdkSecretEditablePolicy.clear(password.text)
                    coordinator!!.sdk.prepareWalletCreation(wordCount, secret)
                }
            } catch (error: Throwable) {
                finishFailed(error)
                return@setOnClickListener
            }
            coordinator!!.acceptPreparation(future)
        }
    }

    @JvmSynthetic
    internal fun showBackupFromCoordinator(value: CitizenSdkPreparedWallet) {
        prepared = value
        phrase = value.openRecoveryPhrase()
        val content = CitizenSdkRecoveryContent(this)
        recoveryContent = content
        phrase!!.useCharacters(content::replace)
        val warning = TextView(this).apply {
            text = "请离线抄写恢复词。CitizenSDK 不会再次导出，禁止截图或复制。"
            setTextColor(Color.RED)
        }
        val confirm = Button(this).apply { text = "我已完成离线备份" }
        val cancel = Button(this).apply { text = "取消并清除"; setOnClickListener { finishCancelled() } }
        setContentView(layout(title("备份恢复词"), warning, content, confirm, cancel))
        confirm.setOnClickListener {
            confirm.isEnabled = false
            content.close()
            phrase?.close()
            phrase = null
            val future = try {
                coordinator!!.sdk.commitPreparedWallet(value)
            } catch (error: Throwable) {
                finishFailed(error)
                return@setOnClickListener
            }
            coordinator!!.acceptIrreversible(future)
        }
    }

    private fun showRecoveryInput(indices: IntArray?) {
        val mnemonic = secretInput("恢复词（仅本页内存）", multiline = true)
        val password = secretInput("可选钱包密码")
        val action = Button(this).apply { text = if (indices == null) "恢复钱包" else "添加账户" }
        val cancel = Button(this).apply { text = "取消"; setOnClickListener { finishCancelled() } }
        setContentView(layout(title(action.text.toString()), mnemonic, password, action, cancel))
        action.setOnClickListener {
            action.isEnabled = false
            var mnemonicBytes: CitizenSdkSensitiveBytes? = null
            var passwordBytes: CitizenSdkSensitiveBytes? = null
            val future = try {
                val mnemonicValue = CitizenSdkSensitiveBytes.utf8(mnemonic.text).also {
                    mnemonicBytes = it
                }
                val passwordValue = CitizenSdkSensitiveBytes.utf8(password.text).also {
                    passwordBytes = it
                }
                CitizenSdkSecretEditablePolicy.clear(mnemonic.text)
                CitizenSdkSecretEditablePolicy.clear(password.text)
                mnemonicValue.use { phraseBytes ->
                    passwordValue.use { passwordBytesValue ->
                        if (indices == null) {
                            coordinator!!.sdk.importWallet(phraseBytes, passwordBytesValue)
                        } else {
                            coordinator!!.sdk.addWalletAccounts(
                                phraseBytes, passwordBytesValue, indices.clone(),
                            )
                        }
                    }
                }
            } catch (error: Throwable) {
                CitizenSdkSecretEditablePolicy.clear(mnemonic.text)
                CitizenSdkSecretEditablePolicy.clear(password.text)
                finishFailed(error)
                return@setOnClickListener
            } finally {
                mnemonicBytes?.close()
                passwordBytes?.close()
            }
            coordinator!!.acceptIrreversible(future)
        }
    }

    @JvmSynthetic
    internal fun finishWithTerminal(result: CitizenSdkWalletFlowContract.Result) = runOnUiThread {
        val cleanupFailure = coordinator?.settlePreparedForTerminal(result)
        if (cleanupFailure == null) prepared = null
        // Keep the original terminal result while onDestroy performs a second
        // release attempt. Only a repeated failure is reported as cleanup error.
        terminalResult = result
        finish()
    }

    private fun finishCancelled() {
        if (coordinator?.requestCancellationSettlement() == true) {
            showMutationInProgress()
            return
        }
        if (terminalResult == null) terminalResult = CitizenSdkWalletFlowContract.Result.Cancelled
        finish()
    }

    private fun finishFailed(failure: Throwable) {
        val cause = (failure as? CompletionException)?.cause ?: failure
        val error = cause as? CitizenSdkException ?: CitizenSdkException(
            CitizenSdkErrorCode.INTERNAL,
            "CitizenSDK wallet flow failed",
            cause,
        )
        terminalResult = CitizenSdkWalletFlowContract.Result.Failed(error)
        finish()
    }

    @JvmSynthetic
    internal fun requestCancellation(force: Boolean = false) = runOnUiThread {
        if (force && coordinator?.requiresTruthfulTerminal() != true) {
            terminalResult = CitizenSdkWalletFlowContract.Result.Cancelled
        }
        finishCancelled()
    }

    private fun showMutationInProgress() {
        val status = TextView(this).apply {
            text = "钱包操作已提交，正在等待安全存储完成。完成前不能取消。"
            setTextColor(Color.BLACK)
        }
        setContentView(layout(title("正在完成公民钱包操作"), status))
    }

    private fun title(value: String) = TextView(this).apply {
        text = value
        textSize = 24f
        setTextColor(Color.BLACK)
    }

    private fun secretInput(hintValue: String, multiline: Boolean = false) =
        EditText(this).apply {
            hint = hintValue
            importantForAutofill = android.view.View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
            setAutofillHints(*emptyArray())
            // Core accepts at most 1024 UTF-8 bytes. floor(1024 / 3) UTF-16
            // code units is deliberately stricter, so even all three-byte BMP
            // input stays inside that bound without affecting 24-word phrases.
            filters = arrayOf(
                InputFilter.LengthFilter(
                    CitizenSdkSecretEditablePolicy.MAX_INPUT_UTF16_CODE_UNITS,
                ),
            )
            inputType = if (multiline) {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                    InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
            } else {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            }
            if (multiline) minLines = 4
        }.also { secretInputs.add(it) }

    private fun layout(vararg children: android.view.View) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        setPadding(48, 64, 48, 48)
        children.forEach { child ->
            addView(
                child,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { bottomMargin = 24 },
            )
        }
    }

    companion object {
        internal const val EXTRA_FLOW_ID = "org.citizen.sdk.wallet.FLOW_ID"
    }
}

/** Overwrites and clears the mutable UI buffer without constructing a secret String. */
internal object CitizenSdkSecretEditablePolicy {
    const val MAX_INPUT_UTF16_CODE_UNITS = CitizenSdkInputLimits.MAX_WALLET_SECRET_BYTES / 3
    private const val WIPE_CHUNK_CODE_UNITS = 64

    @JvmSynthetic
    fun clear(editable: Editable) {
        // Never allocate in proportion to attacker-controlled pasted input.
        // This also handles legacy Editable values that bypassed the filter.
        val zeros = CharArray(WIPE_CHUNK_CODE_UNITS)
        try {
            var offset = 0
            while (offset < editable.length) {
                val count = minOf(WIPE_CHUNK_CODE_UNITS, editable.length - offset)
                editable.replace(
                    offset,
                    offset + count,
                    CharBuffer.wrap(zeros, 0, count),
                )
                offset += count
            }
        } finally {
            zeros.fill('\u0000')
            editable.clear()
        }
    }
}
