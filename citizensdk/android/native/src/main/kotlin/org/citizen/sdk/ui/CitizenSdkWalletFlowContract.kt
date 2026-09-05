package org.citizen.sdk.ui

import org.citizen.sdk.CitizenSdkException
import org.citizen.sdk.CitizenSdkInputLimits
import org.citizen.sdk.CitizenWalletProfile

/** Public, secret-free contract for the SDK-owned Android wallet flow. */
object CitizenSdkWalletFlowContract {
    sealed class Request {
        class Create(val wordCount: Int = 12) : Request() {
            init { require(wordCount in listOf(12, 18, 24)) { "wordCount must be 12, 18 or 24" } }
        }

        class Import : Request()

        class AddAccounts(indices: List<Int>) : Request() {
            val indices: List<Int>

            init {
                require(indices.size in 1..CitizenSdkInputLimits.MAX_ADD_ACCOUNT_INDICES) {
                    "indices must contain 1..${CitizenSdkInputLimits.MAX_ADD_ACCOUNT_INDICES} items"
                }
                this.indices = indices.toList()
                require(this.indices.size == this.indices.toSet().size) { "indices must be unique" }
                require(this.indices.all { it in 1..1989 }) { "account index must be in 1..1989" }
            }
        }
    }

    sealed class Result {
        class Completed(val profile: CitizenWalletProfile) : Result()
        data object Cancelled : Result()
        class Failed(val error: CitizenSdkException) : Result()
    }

    fun interface Callback {
        fun onResult(result: Result)
    }
}
