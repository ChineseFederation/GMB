#include "citizen_sdk_public_store.hpp"

#include <limits>
#include "citizen_sdk_record_key.hpp"

namespace citizen_sdk::linux {

PublicStore::PublicStore(const std::filesystem::path &directory)
    : SQLiteStore(directory, "public-state-v1.sqlite3",
                  {"CREATE TABLE IF NOT EXISTS singleton_records ("
                   "domain INTEGER PRIMARY KEY CHECK(domain IN (1,4)), "
                   "revision INTEGER NOT NULL CHECK(typeof(revision) = 'integer' AND revision > 0), "
                   "record BLOB NOT NULL CHECK(typeof(record) = 'blob' AND "
                   "((domain = 1 AND length(record) <= 524288) OR "
                   "(domain = 4 AND length(record) <= 33554432))))",
                   "CREATE TABLE IF NOT EXISTS runtime_cache ("
                   "record_key TEXT PRIMARY KEY, record BLOB NOT NULL "
                   "CHECK(typeof(record) = 'blob' AND length(record) <= 8388608)))"},
                  false) {}

HostRecord PublicStore::chain_database_load() {
  return singleton_load(CITIZENSDK_HOST_RECORD_CHAIN_DATABASE);
}

HostRecord PublicStore::chain_database_compare_and_swap(
    uint64_t expected, const Bytes &candidate) {
  return singleton_compare_and_swap(CITIZENSDK_HOST_RECORD_CHAIN_DATABASE,
                                    expected, candidate);
}

HostRecord PublicStore::transaction_history_load() {
  return singleton_load(CITIZENSDK_HOST_RECORD_TRANSACTION_HISTORY);
}

HostRecord PublicStore::transaction_history_compare_and_swap(
    uint64_t expected, const Bytes &candidate) {
  return singleton_compare_and_swap(CITIZENSDK_HOST_RECORD_TRANSACTION_HISTORY,
                                    expected, candidate);
}

HostRecord PublicStore::runtime_cache_load(
    const std::array<uint8_t, 32> &hash) {
  const std::string key = record_key::block_hash(hash);
  return read([&](sqlite3 *database) {
    Statement statement(database,
                        "SELECT record FROM runtime_cache WHERE record_key = ?");
    statement.bind(1, key);
    if (statement.step_row_or_done()) {
      return HostRecord::value(CITIZENSDK_HOST_RECORD_RUNTIME_CACHE, 0,
                               statement.bytes(0, 8388608));
    }
    return HostRecord::absent(CITIZENSDK_HOST_RECORD_RUNTIME_CACHE);
  });
}

void PublicStore::runtime_cache_store(const std::array<uint8_t, 32> &hash,
                                      const Bytes &candidate) {
  require(candidate.size() <= 8388608, CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK runtime cache is too large");
  const std::string key = record_key::block_hash(hash);
  (void)transaction([&](sqlite3 *database) {
    Statement statement(database,
                        "INSERT OR REPLACE INTO runtime_cache(record_key, record) "
                        "VALUES(?, ?)");
    statement.bind(1, key);
    statement.bind(2, candidate);
    statement.step_done();
    return true;
  });
}

void PublicStore::runtime_cache_delete(const std::array<uint8_t, 32> &hash) {
  const std::string key = record_key::block_hash(hash);
  (void)transaction([&](sqlite3 *database) {
    Statement statement(database,
                        "DELETE FROM runtime_cache WHERE record_key = ?");
    statement.bind(1, key);
    statement.step_done();
    return true;
  });
}

HostRecord PublicStore::singleton_load(
    citizensdk_host_record_domain_t domain) {
  return read([&](sqlite3 *database) {
    Statement statement(database,
                        "SELECT revision, record FROM singleton_records "
                        "WHERE domain = ?");
    statement.bind(1, static_cast<int64_t>(domain));
    if (statement.step_row_or_done()) {
      const int64_t revision = statement.integer(
          0, 1, std::numeric_limits<int64_t>::max());
      return HostRecord::value(
          domain, static_cast<uint64_t>(revision),
          statement.bytes(1, domain == CITIZENSDK_HOST_RECORD_CHAIN_DATABASE
                                 ? 524288 : 33554432));
    }
    return HostRecord::absent(domain);
  });
}

HostRecord PublicStore::singleton_compare_and_swap(
    citizensdk_host_record_domain_t domain, uint64_t expected,
    const Bytes &candidate) {
  const std::size_t maximum =
      domain == CITIZENSDK_HOST_RECORD_CHAIN_DATABASE ? 524288U : 33554432U;
  require((domain == CITIZENSDK_HOST_RECORD_CHAIN_DATABASE ||
           domain == CITIZENSDK_HOST_RECORD_TRANSACTION_HISTORY) &&
              candidate.size() <= maximum,
          CITIZENSDK_ERROR_INVALID_ARGUMENT,
          "CitizenSDK public record domain or size is invalid");
  if (expected >= static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
    return HostRecord::failure(domain, CITIZENSDK_ERROR_CONFLICT);
  }
  return transaction([&](sqlite3 *database) {
    Statement query(database,
                    "SELECT revision FROM singleton_records WHERE domain = ?");
    query.bind(1, static_cast<int64_t>(domain));
    uint64_t actual = 0;
    if (query.step_row_or_done()) {
      const int64_t revision = query.integer(
          0, 1, std::numeric_limits<int64_t>::max());
      actual = static_cast<uint64_t>(revision);
    }
    if (actual != expected) {
      return HostRecord::failure(domain, CITIZENSDK_ERROR_CONFLICT);
    }
    const uint64_t next = expected + 1;
    Statement write(database,
                    "INSERT OR REPLACE INTO singleton_records"
                    "(domain, revision, record) VALUES(?, ?, ?)");
    write.bind(1, static_cast<int64_t>(domain));
    write.bind(2, static_cast<int64_t>(next));
    write.bind(3, candidate);
    write.step_done();
    return HostRecord::value(domain, next, candidate);
  });
}

}  // namespace citizen_sdk::linux
