// 验证 Linux public store 忠实实现根 ABI 的 revision CAS 与 domain 隔离。
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <sys/stat.h>
#include <sqlite3.h>

#include "citizen_sdk_public_store.hpp"
#include "citizen_sdk_test_support.hpp"

#ifndef CITIZENSDK_LINUX_TEST_SOURCE_DIR
#error "CITIZENSDK_LINUX_TEST_SOURCE_DIR must point at the Linux source root"
#endif
#ifdef NDEBUG
#error "CitizenSDK Linux contract assertions must remain enabled"
#endif

namespace {

mode_t permissions(const std::filesystem::path &path) {
  struct stat value {};
  assert(::stat(path.c_str(), &value) == 0);
  return value.st_mode & 0777;
}

void touch(const std::filesystem::path &path) {
  std::ofstream stream(path, std::ios::binary | std::ios::trunc);
  assert(stream.good());
}

void expect_permission_denied(const std::filesystem::path &directory) {
  bool rejected = false;
  try {
    citizen_sdk::linux::PublicStore store(directory);
  } catch (const citizen_sdk::linux::HostError &error) {
    rejected = error.code() == CITIZENSDK_ERROR_PERMISSION_DENIED;
  }
  assert(rejected);
}

void execute_sql(const std::filesystem::path &database, const char *sql) {
  sqlite3 *handle = nullptr;
  assert(sqlite3_open_v2(database.c_str(), &handle,
                         SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE |
                             SQLITE_OPEN_FULLMUTEX |
                             SQLITE_OPEN_PRIVATECACHE,
                         nullptr) == SQLITE_OK);
  assert(handle != nullptr);
  char *message = nullptr;
  const int code = sqlite3_exec(handle, sql, nullptr, nullptr, &message);
  if (message != nullptr) sqlite3_free(message);
  assert(code == SQLITE_OK);
  assert(sqlite3_close_v2(handle) == SQLITE_OK);
}

std::string read_text_pragma(const std::filesystem::path &database,
                             const char *sql) {
  sqlite3 *handle = nullptr;
  assert(sqlite3_open_v2(database.c_str(), &handle,
                         SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX |
                             SQLITE_OPEN_PRIVATECACHE,
                         nullptr) == SQLITE_OK);
  assert(handle != nullptr);
  sqlite3_stmt *statement = nullptr;
  assert(sqlite3_prepare_v2(handle, sql, -1, &statement, nullptr) ==
         SQLITE_OK);
  assert(statement != nullptr && sqlite3_step(statement) == SQLITE_ROW);
  const auto *value = sqlite3_column_text(statement, 0);
  assert(value != nullptr);
  const std::string result(reinterpret_cast<const char *>(value));
  assert(sqlite3_step(statement) == SQLITE_DONE);
  assert(sqlite3_finalize(statement) == SQLITE_OK);
  assert(sqlite3_close_v2(handle) == SQLITE_OK);
  return result;
}

void expect_corrupt_singleton(const std::filesystem::path &directory) {
  bool rejected = false;
  try {
    citizen_sdk::linux::PublicStore store(directory);
    (void)store.chain_database_load();
  } catch (const citizen_sdk::linux::HostError &error) {
    rejected = error.code() == CITIZENSDK_ERROR_INTEGRITY;
  }
  assert(rejected);
}

void expect_integrity_on_open(const std::filesystem::path &directory) {
  bool rejected = false;
  try {
    citizen_sdk::linux::PublicStore store(directory);
  } catch (const citizen_sdk::linux::HostError &error) {
    rejected = error.code() == CITIZENSDK_ERROR_INTEGRITY;
  }
  assert(rejected);
}

class InspectableSQLiteStore final : public citizen_sdk::linux::SQLiteStore {
 public:
  InspectableSQLiteStore(const std::filesystem::path &directory, bool secure)
      : SQLiteStore(
            directory,
            secure ? "secure-contract.sqlite3" : "public-contract.sqlite3",
            {"CREATE TABLE IF NOT EXISTS contract_record ("
             "identity INTEGER PRIMARY KEY CHECK(identity = 1), "
             "value BLOB NOT NULL CHECK(typeof(value) = 'blob'))"},
            secure) {}

  int64_t integer_pragma(const char *sql) {
    return read([&](sqlite3 *database) {
      Statement statement(database, sql);
      assert(statement.step_row_or_done());
      const int64_t value = statement.integer(0, 0, 1000000);
      assert(!statement.step_row_or_done());
      return value;
    });
  }

  std::string text_pragma(const char *sql) {
    return read([&](sqlite3 *database) {
      Statement statement(database, sql);
      assert(statement.step_row_or_done());
      const std::string value = statement.text(0, 64);
      assert(!statement.step_row_or_done());
      return value;
    });
  }
};

void verify_pragmas(const std::filesystem::path &directory, bool secure) {
  InspectableSQLiteStore store(directory, secure);
  assert(store.text_pragma("PRAGMA journal_mode") == "wal");
  assert(store.integer_pragma("PRAGMA synchronous") == 2);
  assert(store.integer_pragma("PRAGMA foreign_keys") == 1);
  assert(store.integer_pragma("PRAGMA busy_timeout") == 5000);
  assert(store.integer_pragma("PRAGMA temp_store") == 2);
  assert(store.integer_pragma("PRAGMA trusted_schema") == 0);
  assert(store.integer_pragma("PRAGMA wal_autocheckpoint") == 1000);
  assert(store.integer_pragma("PRAGMA user_version") == 1);
  assert(store.integer_pragma("PRAGMA secure_delete") == (secure ? 1 : 0));
}

}  // namespace

int main() {
  using citizen_sdk::linux::Bytes;
  using citizen_sdk::linux::HostError;
  using citizen_sdk::linux::PublicStore;

  citizen_sdk::linux::test::TempDirectory temporary("public-store");
  const auto directory = temporary.path() / "state";
  {
    PublicStore store(directory);
    const auto absent = store.chain_database_load();
    assert(!absent.present);
    assert(absent.error_code == CITIZENSDK_OK);
    assert(absent.domain == CITIZENSDK_HOST_RECORD_CHAIN_DATABASE);

    const auto first = store.chain_database_compare_and_swap(0, Bytes{1, 2});
    assert(first.present && first.revision == 1);
    assert((first.record == Bytes{1, 2}));
    const auto conflict = store.chain_database_compare_and_swap(0, Bytes{3});
    assert(conflict.error_code == CITIZENSDK_ERROR_CONFLICT);
    assert((store.chain_database_load().record == Bytes{1, 2}));

    const auto history =
        store.transaction_history_compare_and_swap(0, Bytes{4, 5});
    assert(history.revision == 1);
    assert((store.transaction_history_load().record == Bytes{4, 5}));
    assert((store.chain_database_load().record == Bytes{1, 2}));

    std::array<uint8_t, 32> hash{};
    hash[31] = 9;
    assert(!store.runtime_cache_load(hash).present);
    store.runtime_cache_store(hash, Bytes{6, 7});
    const auto cached = store.runtime_cache_load(hash);
    assert(cached.present && cached.revision == 0);
    assert((cached.record == Bytes{6, 7}));
    store.runtime_cache_delete(hash);
    assert(!store.runtime_cache_load(hash).present);

    assert(permissions(directory) == 0700);
    assert(permissions(directory / "public-state-v1.sqlite3") == 0600);
    assert(permissions(directory / "public-state-v1.sqlite3-wal") == 0600);
    assert(permissions(directory / "public-state-v1.sqlite3-shm") == 0600);
    store.close();
    bool closed_failed = false;
    try {
      (void)store.chain_database_load();
    } catch (const HostError &error) {
      closed_failed = error.code() == CITIZENSDK_ERROR_STORAGE;
    }
    assert(closed_failed);
  }

  const auto symlink_target = temporary.path() / "symlink-target";
  std::filesystem::create_directory(symlink_target);
  const auto symlink_path = temporary.path() / "symlink-state";
  std::filesystem::create_directory_symlink(symlink_target, symlink_path);
  expect_permission_denied(symlink_path);

  const auto database_symlink = temporary.path() / "database-symlink";
  std::filesystem::create_directory(database_symlink);
  touch(temporary.path() / "decoy");
  std::filesystem::create_symlink(temporary.path() / "decoy",
                                  database_symlink /
                                      "public-state-v1.sqlite3");
  expect_permission_denied(database_symlink);

  const auto database_directory = temporary.path() / "database-directory";
  std::filesystem::create_directory(database_directory);
  std::filesystem::create_directory(database_directory /
                                    "public-state-v1.sqlite3");
  expect_permission_denied(database_directory);

  const auto database_hardlink = temporary.path() / "database-hardlink";
  std::filesystem::create_directory(database_hardlink);
  const auto hardlink_source = temporary.path() / "hardlink-source";
  touch(hardlink_source);
  std::filesystem::create_hard_link(
      hardlink_source, database_hardlink / "public-state-v1.sqlite3");
  expect_permission_denied(database_hardlink);

  for (const char *companion : {"-journal", "-wal", "-shm"}) {
    const auto companion_state =
        temporary.path() / (std::string("companion") + companion + "-state");
    std::filesystem::create_directory(companion_state);
    std::filesystem::create_symlink(
        temporary.path() / "decoy",
        companion_state /
            (std::string("public-state-v1.sqlite3") + companion));
    expect_permission_denied(companion_state);

    const auto companion_directory_state =
        temporary.path() /
        (std::string("companion-directory") + companion + "-state");
    std::filesystem::create_directory(companion_directory_state);
    std::filesystem::create_directory(
        companion_directory_state /
            (std::string("public-state-v1.sqlite3") + companion));
    expect_permission_denied(companion_directory_state);

    const auto companion_hardlink_state =
        temporary.path() /
        (std::string("companion-hardlink") + companion + "-state");
    std::filesystem::create_directory(companion_hardlink_state);
    const auto companion_hardlink_source =
        temporary.path() /
        (std::string("companion-hardlink") + companion + "-source");
    touch(companion_hardlink_source);
    std::filesystem::create_hard_link(
        companion_hardlink_source,
        companion_hardlink_state /
            (std::string("public-state-v1.sqlite3") + companion));
    expect_permission_denied(companion_hardlink_state);
  }

  const auto unsafe_state = temporary.path() / "unsafe-state";
  std::filesystem::create_directory(unsafe_state);
  const auto unsafe_database = unsafe_state / "public-state-v1.sqlite3";
  touch(unsafe_database);
  assert(::chmod(unsafe_database.c_str(), 0666) == 0);
  {
    PublicStore store(unsafe_state);
    assert(permissions(unsafe_state) == 0700);
    assert(permissions(unsafe_database) == 0600);
  }

  // Store 打开后替换路径名不能把 SQLite 后续写入或 sidecar 导向新目录；
  // VFS 必须始终绑定构造时验证过的目录 fd。
  const auto bound_state = temporary.path() / "bound-state";
  const auto bound_identity = temporary.path() / "bound-state-original";
  {
    PublicStore store(bound_state);
    (void)store.chain_database_compare_and_swap(0, Bytes{21});
    std::filesystem::rename(bound_state, bound_identity);
    std::filesystem::create_directory(bound_state);
    const auto persisted =
        store.transaction_history_compare_and_swap(0, Bytes{22});
    assert(persisted.error_code == CITIZENSDK_OK && persisted.revision == 1);
  }
  assert(std::filesystem::is_empty(bound_state));
  {
    PublicStore store(bound_identity);
    assert((store.chain_database_load().record == Bytes{21}));
    assert((store.transaction_history_load().record == Bytes{22}));
  }

  const auto wrong_schema = temporary.path() / "wrong-public-schema";
  std::filesystem::create_directory(wrong_schema);
  execute_sql(wrong_schema / "public-state-v1.sqlite3",
              "CREATE TABLE singleton_records(domain INTEGER PRIMARY KEY);");
  expect_integrity_on_open(wrong_schema);
  // 未知/部分 schema 必须在任何持久 journal-mode 修改之前被拒绝。
  assert(read_text_pragma(wrong_schema / "public-state-v1.sqlite3",
                          "PRAGMA journal_mode") == "delete");

  // user_version=0 也不等于空库；必须先识别 sqlitex_* 用户表，不能初始化业务 schema。
  const auto uninitialized = temporary.path() / "sqlitex-public-uninitialized";
  std::filesystem::create_directory(uninitialized);
  const auto uninitialized_database = uninitialized / "public-state-v1.sqlite3";
  execute_sql(uninitialized_database, "CREATE TABLE sqlitex_extra(value BLOB);");
  assert(read_text_pragma(uninitialized_database, "PRAGMA user_version") == "0");
  expect_integrity_on_open(uninitialized);
  assert(read_text_pragma(uninitialized_database, "PRAGMA user_version") == "0");
  assert(read_text_pragma(uninitialized_database, "PRAGMA journal_mode") == "delete");
  assert(read_text_pragma(uninitialized_database,
                         "SELECT count(*) FROM sqlite_master WHERE name IN "
                         "('singleton_records','runtime_cache')") == "0");

  const auto extra_schema = temporary.path() / "extra-public-schema";
  {
    PublicStore store(extra_schema);
  }
  execute_sql(extra_schema / "public-state-v1.sqlite3",
              "CREATE TABLE unexpected_state(value BLOB);");
  expect_integrity_on_open(extra_schema);

  // 用户对象 sqlitex_* 不是 SQLite 内部对象，表和触发器都必须计入 schema 闭集。
  const auto disguised_table = temporary.path() / "sqlitex-public-table";
  {
    PublicStore store(disguised_table);
  }
  execute_sql(disguised_table / "public-state-v1.sqlite3",
              "CREATE TABLE sqlitex_extra(value BLOB);");
  expect_integrity_on_open(disguised_table);
  const auto disguised_trigger = temporary.path() / "sqlitex-public-trigger";
  {
    PublicStore store(disguised_trigger);
  }
  execute_sql(disguised_trigger / "public-state-v1.sqlite3",
              "CREATE TRIGGER sqlitex_extra AFTER INSERT ON singleton_records "
              "BEGIN SELECT 1; END;");
  expect_integrity_on_open(disguised_trigger);

  const auto corrupt_revision = temporary.path() / "corrupt-revision";
  {
    PublicStore store(corrupt_revision);
    (void)store.chain_database_compare_and_swap(0, Bytes{1});
  }
  execute_sql(corrupt_revision / "public-state-v1.sqlite3",
              "PRAGMA ignore_check_constraints=ON;"
              "UPDATE singleton_records SET revision=0;");
  expect_corrupt_singleton(corrupt_revision);

  const auto corrupt_blob = temporary.path() / "corrupt-blob";
  {
    PublicStore store(corrupt_blob);
    (void)store.chain_database_compare_and_swap(0, Bytes{1});
  }
  execute_sql(corrupt_blob / "public-state-v1.sqlite3",
              "PRAGMA ignore_check_constraints=ON;"
              "UPDATE singleton_records SET record='not-a-blob';");
  expect_corrupt_singleton(corrupt_blob);

  // 直接从生产 SQLiteStore 的同一连接读回全部安全 PRAGMA，避免只验证
  // 配置语句存在却没有验证实际生效值。
  verify_pragmas(temporary.path() / "pragma-public", false);
  verify_pragmas(temporary.path() / "pragma-secure", true);

  const std::string sqlite_path =
      std::string(CITIZENSDK_LINUX_TEST_SOURCE_DIR) +
      "/src/citizen_sdk_sqlite.cc";
  std::ifstream sqlite_stream(sqlite_path, std::ios::binary);
  assert(sqlite_stream.good());
  const std::string sqlite_source(
      (std::istreambuf_iterator<char>(sqlite_stream)),
      std::istreambuf_iterator<char>());
  assert(sqlite_source.find("count > maximum") != std::string::npos);
  assert(sqlite_source.find("CITIZENSDK_ERROR_INTEGRITY") !=
         std::string::npos);
  // 非当前有效 UID 的节点无法由普通测试进程安全构造；源码合同仍冻结
  // owner 与单一 hardlink 身份检查，动态用例则覆盖 hardlink 拒绝。
  assert(sqlite_source.find("path_status.st_nlink != 1") !=
         std::string::npos);
  assert(sqlite_source.find("path_status.st_uid != ::geteuid()") !=
         std::string::npos);
  assert(sqlite_source.find("\"/proc/self/fd/\"") == std::string::npos);
  assert(sqlite_source.find("class OpenAtSQLiteVfs final") !=
         std::string::npos);
  assert(sqlite_source.find("::openat(directory_fd_") != std::string::npos);
  assert(sqlite_source.find("O_NOFOLLOW") != std::string::npos);
  assert(sqlite_source.find("SQLITE_OPEN_PRIVATECACHE") !=
         std::string::npos);
  assert(sqlite_source.find("verify_schema(database, schema)") !=
         std::string::npos);
  assert(sqlite_source.find("verify_text_pragma(database, \"PRAGMA journal_mode\", \"wal\"") !=
         std::string::npos);
  assert(sqlite_source.find("verify_integer_pragma(database, \"PRAGMA secure_delete\"") !=
         std::string::npos);
  const auto configure =
      sqlite_source.find("void configure_and_verify_database(");
  const auto initialize_transaction =
      sqlite_source.find("execute_checked(\"BEGIN IMMEDIATE\")", configure);
  const auto initialize_version =
      sqlite_source.find("execute_checked(\"PRAGMA user_version=1\")",
                         initialize_transaction);
  const auto initialize_schema =
      sqlite_source.find("verify_schema(database, schema)",
                         initialize_version);
  const auto initialize_commit =
      sqlite_source.find("execute_checked(\"COMMIT\")", initialize_schema);
  const auto wal_configuration =
      sqlite_source.find("execute_checked(\"PRAGMA journal_mode=WAL\")",
                         initialize_commit);
  const auto existing_schema = sqlite_source.rfind(
      "verify_schema(database, schema)", wal_configuration);
  assert(configure != std::string::npos &&
         initialize_transaction != std::string::npos &&
         initialize_version != std::string::npos &&
         initialize_schema != std::string::npos &&
         initialize_commit != std::string::npos &&
         wal_configuration != std::string::npos &&
         existing_schema != std::string::npos &&
         configure < initialize_transaction &&
         initialize_transaction < initialize_version &&
         initialize_version < initialize_schema &&
         initialize_schema < initialize_commit &&
         initialize_commit < existing_schema &&
         existing_schema < wal_configuration);

  const std::string sqlite_header_path =
      std::string(CITIZENSDK_LINUX_TEST_SOURCE_DIR) +
      "/src/citizen_sdk_sqlite.hpp";
  std::ifstream sqlite_header_stream(sqlite_header_path, std::ios::binary);
  assert(sqlite_header_stream.good());
  const std::string sqlite_header(
      (std::istreambuf_iterator<char>(sqlite_header_stream)),
      std::istreambuf_iterator<char>());
  const auto transaction = sqlite_header.find("auto transaction(");
  const auto nothrow_result = sqlite_header.find(
      "std::is_nothrow_move_constructible_v<Result>", transaction);
  const auto precommit_check =
      sqlite_header.find("enforce_file_permissions();", transaction);
  const auto commit =
      sqlite_header.find("execute(database, \"COMMIT\")", precommit_check);
  const auto rollback = sqlite_header.find("ROLLBACK", commit);
  assert(transaction != std::string::npos &&
         nothrow_result != std::string::npos &&
         precommit_check != std::string::npos && commit != std::string::npos &&
         rollback != std::string::npos && transaction < nothrow_result &&
         nothrow_result < precommit_check &&
         precommit_check < commit && commit < rollback);
  const auto next_permission_check =
      sqlite_header.find("enforce_file_permissions();", commit);
  assert(next_permission_check == std::string::npos ||
         next_permission_check > rollback);
  return 0;
}
