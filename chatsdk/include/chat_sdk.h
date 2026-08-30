#ifndef CHAT_SDK_H
#define CHAT_SDK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void chat_sdk_free_string(char *value);

char *chat_sdk_mls_create_key_package_json(const char *request_json, char **error_out);

char *chat_sdk_device_identity_json(const char *request_json, char **error_out);

char *chat_sdk_mls_two_party_smoke_json(const char *request_json, char **error_out);

char *chat_sdk_mls_encrypt_json(const char *request_json, char **error_out);

char *chat_sdk_mls_decrypt_json(const char *request_json, char **error_out);

char *chat_sdk_mls_rekey_state_json(const char *request_json,
                                        char **error_out);

char *chat_sdk_mls_group_create_json(const char *request_json, char **error_out);

char *chat_sdk_mls_group_add_members_json(const char *request_json, char **error_out);

char *chat_sdk_mls_group_remove_members_json(const char *request_json, char **error_out);

char *chat_sdk_mls_group_create_message_json(const char *request_json, char **error_out);

char *chat_sdk_mls_group_process_json(const char *request_json, char **error_out);

char *chat_sdk_mls_group_state_json(const char *request_json, char **error_out);

#ifdef __cplusplus
}
#endif

#endif
