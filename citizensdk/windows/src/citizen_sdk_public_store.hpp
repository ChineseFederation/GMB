#ifndef CITIZENSDK_WINDOWS_PUBLIC_STORE_HPP
#define CITIZENSDK_WINDOWS_PUBLIC_STORE_HPP

#include <array>
#include <filesystem>
#include "citizen_sdk_sqlite.hpp"

namespace citizen_sdk::windows {

class PublicStore final : public SQLiteStore {
 public:
  explicit PublicStore(const std::filesystem::path &directory);

  HostRecord chain_database_load();
  HostRecord chain_database_compare_and_swap(uint64_t expected,
                                             const Bytes &candidate);
  HostRecord transaction_history_load();
  HostRecord transaction_history_compare_and_swap(uint64_t expected,
                                                   const Bytes &candidate);
  HostRecord runtime_cache_load(const std::array<uint8_t, 32> &hash);
  void runtime_cache_store(const std::array<uint8_t, 32> &hash,
                           const Bytes &candidate);
  void runtime_cache_delete(const std::array<uint8_t, 32> &hash);

 private:
  HostRecord singleton_load(citizensdk_host_record_domain_t domain);
  HostRecord singleton_compare_and_swap(citizensdk_host_record_domain_t domain,
                                        uint64_t expected,
                                        const Bytes &candidate);
};

}  // namespace citizen_sdk::windows

#endif
