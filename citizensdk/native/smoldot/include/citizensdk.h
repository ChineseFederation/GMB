#ifndef CITIZENSDK_H
#define CITIZENSDK_H

#include <stddef.h>
#include <stdint.h>

#include "smoldot.h"

#define CITIZENSDK_ABI_VERSION 1

#define CITIZEN_SIGNER_OK 0
#define CITIZEN_SIGNER_ERR_NULL_ARG -1
#define CITIZEN_SIGNER_ERR_BAD_KEY -2
#define CITIZEN_SIGNER_ERR_BAD_SIGNATURE -3
#define CITIZEN_SIGNER_ERR_VERIFY_FAILED -4
#define CITIZEN_SIGNER_ERR_PANIC -5

#ifdef __cplusplus
extern "C" {
#endif

/** 从 32 字节 mini-secret 按 32 字节 chain code 硬派生一层。 */
int32_t citizen_sr25519_derive_hard(const uint8_t *seed,
                                    const uint8_t *chain_code,
                                    uint8_t *out_child);

/** 从 32 字节 child mini-secret 计算 32 字节 AccountId。 */
int32_t citizen_sr25519_public_key(const uint8_t *child,
                                  uint8_t *out_public);

/** 使用 sr25519/substrate context 签名，输出 64 字节签名。 */
int32_t citizen_sr25519_sign(const uint8_t *child,
                            const uint8_t *message,
                            size_t message_len,
                            uint8_t *out_signature);

/** 验证 32 字节公钥、64 字节签名和任意长度消息。 */
int32_t citizen_sr25519_verify(const uint8_t *public_key,
                              const uint8_t *signature,
                              const uint8_t *message,
                              size_t message_len);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // CITIZENSDK_H
