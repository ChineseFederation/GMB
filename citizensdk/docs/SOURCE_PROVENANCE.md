# 源码来源与同步策略

## sr25519 初始基线

本阶段从现有稳定实现逐字节导入以下文件：

| 来源 | CitizenSDK 目标 | SHA-256 |
|---|---|---|
| `shared/citizen-signer/Cargo.toml` | `native/signer/Cargo.toml` | `4b063da8dbf821d14798be37b41366be35418f5c14ed2b451420be80d424d3d8` |
| `shared/citizen-signer/src/lib.rs` | `native/signer/src/lib.rs` | `4fcdcda78e3050ab2daff782881b2c223ddabf61dc00113f4f83f799b5436f9d` |

导入时不改变函数体、签名上下文、扩展模式、错误码、FFI 参数顺序或内存擦除逻辑。

## 过渡期权威来源

从本基线开始，`citizensdk/native/signer` 是 CitizenSDK 后续开发的内部权威来源；现有
CitizenApp 与 CitizenWallet 仍继续使用 `shared/citizen-signer`，直到 SDK 稳定并另行批准
迁移。过渡期不做自动双向同步，任何必须回补现有产品的安全修复都要单独列出文件、
向用户申请许可，并用相同向量交叉验收。

CitizenApp 正式切换 CitizenSDK 后，才可另行设计旧共享路径的退役步骤；本阶段不删除、
修改或重定向原共享实现。

## 后续 smoldot 导入规则

轻节点实施步骤必须先生成精确文件清单和来源哈希。初始复制与 SDK 净化分开记录：先证明
所需源文件和 CitizenApp 稳定版本逐字节一致，再仅在 CitizenSDK 中剥离 OpenMLS、聊天、
账户数据加密及产品耦合。禁止回写 CitizenApp，也禁止通过相对路径在 Release 或 CI 中
依赖 CitizenApp 或其他产品源码。

## smoldot FFI 初始基线

本阶段在净化前逐字节核对以下 CitizenApp 来源：

| 来源文件 | 导入前 SHA-256 | 最终处理 |
|---|---|---|
| `citizenapp/smoldot/ffi/Cargo.toml` | `d1dd1d33a9ba94eb22abc2ad29d3284d4f44f27147ebe1a8727f93b285541981` | 删除聊天/OpenMLS/账户加密依赖，signer 改为 SDK 内部路径 |
| `citizenapp/smoldot/ffi/build.rs` | `ac2a70dee7c627f5351b19df4ae4f64632a542be59d7e837738fba54eadb4569` | 只删除 `chat_mls.rs` 监控 |
| `citizenapp/smoldot/ffi/rust-toolchain.toml` | `a0c1fc2a7fb3c42a129cc8285e78ea5b21f1c8e57e9d67485800f88baa5d3c7b` | 逐字节保留 |
| `citizenapp/smoldot/ffi/src/lib.rs` | `ba449aede6a0710b6b07ef34ba961d1b5a70baf6deb65443035e7b1d073e35bf` | 只删除聊天模块和账户加密导出，更新 signer 注释 |
| `citizenapp/smoldot/ffi/src/error.rs` | `1b5ca5ab8ad027916df22b23a9b36cb8a1f6a4d0edc7f392fe1fd181b31c15f7` | 逐字节保留 |
| `citizenapp/smoldot/ffi/src/ffi_types.rs` | `bf32868186129086190934a50a63576bc20b1d29715372ac78d2f2e1b46a0848` | 逐字节保留 |
| `citizenapp/smoldot/include/smoldot.h` | `4bddc46c9bb5d44555c6a0f16ea7027d194906addc83feb93c90b4c33ab1e470` | 只删除 `citizen_chat_mls_*` 声明 |

`chat_mls.rs` 的来源哈希是
`e3098681dd67b4795204eac15fcb0d84224b246394c96e4ffe6314d55c7ba171`，因产品边界明确排除
聊天而没有复制。旧 `Cargo.lock` 同样没有复制，因为依赖集合已经变化，必须在完整轻节点
workspace 就位后受控重新生成。

净化后的 CitizenSDK 文件哈希如下，后续迁入轻节点主体前以此作为 FFI 边界基线：

| CitizenSDK 文件 | 净化后 SHA-256 |
|---|---|
| `native/smoldot/ffi/Cargo.toml` | `32ac923fa321d4dcdf102b2111228b4d539db0f90012b13c47df7fd80d2416e7` |
| `native/smoldot/ffi/build.rs` | `e2766de6bf915e4571414adac072c064074667b5b7b55d9b82f4a431b032a1f2` |
| `native/smoldot/ffi/rust-toolchain.toml` | `a0c1fc2a7fb3c42a129cc8285e78ea5b21f1c8e57e9d67485800f88baa5d3c7b` |
| `native/smoldot/ffi/src/lib.rs` | `975ec18509f7dfe3159fa9115299125131c74f2a247e9bc865186ddb989f6aa2` |
| `native/smoldot/ffi/src/error.rs` | `1b5ca5ab8ad027916df22b23a9b36cb8a1f6a4d0edc7f392fe1fd181b31c15f7` |
| `native/smoldot/ffi/src/ffi_types.rs` | `bf32868186129086190934a50a63576bc20b1d29715372ac78d2f2e1b46a0848` |
| `native/smoldot/include/smoldot.h` | `f7c2645588809f73f8aa799975b363a4a7b22e8de7149da9d0b4c2ea20c90a20` |
| `native/smoldot/include/citizensdk.h` | `18c476d67cd00822b1a14fe4317330d56195712a7f8e33f39a487d84ad1a0819` |

## smoldot light-base 来源基线

以下 18 个文件从 `citizenapp/smoldot/pow/light-base` 逐字节复制到
`citizensdk/native/smoldot/pow/light-base`，本阶段不修改源码或注释：

| 相对文件 | SHA-256 |
|---|---|
| `Cargo.toml` | `3baf396efb453a99d1ca286bfe68fc9a2ac177f93544c1443146a958a0c0493d` |
| `examples/basic.rs` | `ba610512aba7f8e26bcfc61a4407db947cf46a0a62fd860ac895b005b6d3755a` |
| `src/database.rs` | `ced005bf95e2dfe8266fdc721aba5d10422c6be645d82180ddd50e4c8f662089` |
| `src/json_rpc_service.rs` | `6876193d3823cdb7929dc7dbf281f1feac7df110635aa15bb64ae5f5b71a012c` |
| `src/json_rpc_service/background.rs` | `6946597eefac05103b07c51162966d639920854e4410ebb67a453ce41adfce4d` |
| `src/lib.rs` | `a5a26745ce68aed8cfc92c34663f89bf70ef518be4cbef80f6ff57c6dc10e82b` |
| `src/network_service.rs` | `6d64d98034486dd381ae646523c9ce80fefcd6b34f7962727c8ebb1eb4643652` |
| `src/network_service/tasks.rs` | `9ee102374302adca1d9cfb450e737ac91e461d550350699db23ef2c32bd7798d` |
| `src/platform.rs` | `b34445c26b4e1328eda827d3635b41ce53380940107fb5ddd8c834324cde6876` |
| `src/platform/address_parse.rs` | `26d4ffb5a1572b6b8f418e9dd3243c5456c73e713739f21652099fd99c56c2b9` |
| `src/platform/default.rs` | `4a939115b8500ccd1ad219950143301acdca7683db4acfbaec7b524b9d06a2fd` |
| `src/platform/with_prefix.rs` | `d8d6625ad87f5200f137c55ce5ca5612d20f57fa9ea254d469dcb0f9f6942191` |
| `src/runtime_service.rs` | `4c793a448f86c753c0ade7bf1cb03d0dc21fcfb8e3b10e9299042c176ba4292e` |
| `src/sync_service.rs` | `2f88014f4d6ac9d488fb4a6d7703bd49afe0073a8aa694e6c95447f48d154402` |
| `src/sync_service/parachain.rs` | `e9f880d60eabaf46a684660fdfbd8a0ae09d21e10b6f640830db197e97665334` |
| `src/sync_service/standalone.rs` | `b2d34d3fc0b57ab70b808ddce7a1195a566e53c5b11d4dcf52715a13e847310e` |
| `src/transactions_service.rs` | `8cb27c4add97783cb91df5b1bc56be6a169105413d8fc68cb51889cb5d87edf6` |
| `src/util.rs` | `567ad0d158c686c74c5fb29ee90a3b4f09ea9e573ae7293b61c17e3a4f773b5a` |

该来源的部分注释仍提及 CitizenApp，但没有依赖 CitizenApp 路径。为保留可审计基线，本阶段
不改这些历史注释；相邻 README 解释其来源语境，测试守卫实际的跨产品路径和禁止能力。

Apache 2.0 许可证复制自 `citizenapp/smoldot/dart/LICENSE`，目标文件为
`native/smoldot/LICENSE-APACHE-2.0`，SHA-256 是
`4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78`。

## smoldot 链头、终局性与验证原语来源基线

以下 26 个文件从 `citizenapp/smoldot/pow/lib` 逐字节复制到
`citizensdk/native/smoldot/pow/lib`，本阶段不修改源码、注释或测试数据：

| 相对文件 | SHA-256 |
|---|---|
| `src/chain.rs` | `62445c5a7610fd6d1a351d086c2ac0f49688f7a5f777abbf312d74769f66f987` |
| `src/finality.rs` | `15c6bdbd4298382881f83c1ebc0895f83bb4e13c57d75a11af105e4a2a74303b` |
| `src/header.rs` | `a48d7db6d7a14478202e3425c8eef303b9137308c48ad9362cb69ead83ab2e79` |
| `src/verify.rs` | `974296397538aa52345f7e805d8b3e15d0377751d4f3a39396044ae959523b11` |
| `src/chain/async_tree.rs` | `28fd9bd555717e07d2e49d100539e1ae3183cbb89225877e18ea73e4fb6ca95a` |
| `src/chain/blocks_tree.rs` | `641914884f32207869f7e85d935d35f6e419ce7d3fd0cfa566b6c54ea33e40d4` |
| `src/chain/blocks_tree/finality.rs` | `372bc71f71b98ec8e4add197f7b38ee32de22ac39717718d9e3426e250b1e31d` |
| `src/chain/blocks_tree/tests.rs` | `343fcb746009245a410d6c4cf62353849afae6430d327e9f2837ab870b693c4b` |
| `src/chain/blocks_tree/verify.rs` | `efeb633e502aa7dddf1582c1a55e4aa2bd1ba8769dfdd90e9f82eb24a5f05729` |
| `src/chain/chain_information.rs` | `71c5a2dcaac0cbfc1719a1fc719a056d453da1cec090d11cde60e7e78257347a` |
| `src/chain/chain_information/build.rs` | `0ac03aa34dcdac91ed94921e93605778622e6bd2057e5f250d7be58155cea0e5` |
| `src/chain/fork_tree.rs` | `b231c743e3a60ab4cadb903137b3dbcb303e63301de8c476a765946dd2bcffb1` |
| `src/finality/decode.rs` | `64f3fba79eb13902cec5bddcc0824d3f66ef19cf292284e0bac6f49ed19126b5` |
| `src/finality/verify.rs` | `00a00781a6450420ae7928906af29d95c1aab294737cd32286c755862c5ac9a7` |
| `src/header/aura.rs` | `691d0ee48e3e1a6da272fb931da97fd798ef8df572d93068de3966818778a6e9` |
| `src/header/babe.rs` | `8d8d072aa0fe6d6c7edf4fb8a38036ff301e0065b65f4ee24b9d1179809b3bb0` |
| `src/header/grandpa.rs` | `ea1d098942d4fd55729a9537cee30a9ce9bcfb6c07fad3b7dcb2a5d39e5bcca3` |
| `src/header/tests.rs` | `39aac9ccf919787f95aa2588ee719b19488837de2dcd53ff28347b4be49d1bb8` |
| `src/header/tests/header-kusama-7472481` | `8bd9f3b7c61c2cb88c710f67e698f8c39c8e3abf1d3e9449276f3e1f78989472` |
| `src/header/tests/header-polkadot-512271` | `1ec3a7b48b3b9f435a07dfc6b71ffad4fa3162fa9c144854e7a7a6df6cfad6d0` |
| `src/verify/aura.rs` | `e18218f3d3aa16490ad849a5ccc14f86151cf5a522847d047c652235ddef83d7` |
| `src/verify/babe.rs` | `f90c2e2dc08943078fa63433c130ef427a7ea1fd0a58bbfeb03c9b61d212a322` |
| `src/verify/body_only.rs` | `e4a2b9c01d2dba0e21f48fd1d2eedd7f73f3d1a9545200e678242d88fe63bb9f` |
| `src/verify/header_only.rs` | `f068543451dc3db6cf6097704527935d8658f409f0fdcf043c51626c4583dfd1` |
| `src/verify/inherents.rs` | `a5d6836c3513ba344310efbde88d9887d3ee95888bcb41be5e7cb2d445e711b6` |
| `src/verify/pow.rs` | `73a8db3c04f439755978a9f9e8bbaf7ad9e670d1c49e1ecd51195f275b737059` |

第 4 步没有导入 `author` 或 `identity`。后续第 5 步仅为 JSON-RPC 保留
`identity::ss58` 公钥地址编解码；`identity/keystore.rs`、`identity/seed_phrase.rs` 与
`author` 继续排除，不会形成独立于 CitizenSDK 热钱包的另一条私钥生成、保存或签名路径。
`Cargo.toml` 与 `src/lib.rs` 将在依赖闭包完整后再按获准方案导入并净化。

## smoldot 状态、runtime、轻数据库与 JSON-RPC 来源基线

以下 64 个文件从 `citizenapp/smoldot/pow/lib` 逐字节复制到
`citizensdk/native/smoldot/pow/lib`。其中 Wasm、zstd、JSON 与 proof 文件均为上游公开测试
夹具；本阶段不修改源码、注释或夹具字节：

| 相对文件 | SHA-256 |
|---|---|
| `src/database.rs` | `5912a09de1c95218bf6b7c4c70360c7334df1b2497d4c845551c2aee3750f78a` |
| `src/database/finalized_serialize.rs` | `b6c685988f270a473daee616b3ec8574ee4735d1c53933d55906b730ba68c0b4` |
| `src/database/finalized_serialize/defs.rs` | `97852da758b6198ad0b62ce99b5bc5f60c143a8f5ad0d0453d024db93c41ffae` |
| `src/database/full_sqlite.rs` | `5a242d5a002260a174e7cf5043ca01f6b358c7d48ad08d057108bc99ef2321f2` |
| `src/database/full_sqlite/open.rs` | `b83d1857dc8da4f3d5ddcdeb212db784483ec141e0326003d69806053166ac55` |
| `src/database/full_sqlite/tests.rs` | `4c5692d94bfac33bca6c6144040f3953864a396908a45d07506f0737d79a2874` |
| `src/executor.rs` | `91b78b19c46ba37adf5de511b6271f6508dd556feee960aaff926cc66ac4c40f` |
| `src/executor/allocator.rs` | `87476308b9d9dbcd26590bd3be5bdea212f767c9c5a8e773d7dd8513d557ecdc` |
| `src/executor/host.rs` | `da23bbe260f98cfdc39eb41b201e40abd49f46211d336fb23588cb1553b124c6` |
| `src/executor/host/functions.rs` | `4946418e05121b244f97ededc504bdf01b925ad291f3adc7c954bbd70fdd01f4` |
| `src/executor/host/runtime_version.rs` | `90a6f03950343b4f92befd2d26ae7588a6029218f0b4948230051de54130a058` |
| `src/executor/host/tests.rs` | `1fc79fe2c33af5e1ed2d998232533c245e09e6d1bd6d1f499d3080556d8a13d9` |
| `src/executor/host/tests/hash_algorithms.rs` | `1bf9671a1ba33d3623e60c1d0b9b913048bab79f10171620804460ba1c98b20e` |
| `src/executor/host/tests/initialization.rs` | `6a22d8adcf4f87a938067b30099a724c31e4409f61e52640731ef23a3baf516e` |
| `src/executor/host/tests/rococo-genesis.wasm` | `bf19418836e319be5f46b925d2cde46bf3364c3b86071723d04fd87fc71bc602` |
| `src/executor/host/tests/run.rs` | `862f08ce5614e941128951ec224bba425d88402fca7807047ae40e8f3cfaffe7` |
| `src/executor/host/westend-runtime-v9300.wasm` | `f43e2473e8cfb4f9f208a0f34376a29159b7ae3c11f31adcb82ff03428c3ef1a` |
| `src/executor/host/zstd.rs` | `bd93461a63287c6dbf6788a2ad42067427e3b65ebfc47067cb237b693e227ed5` |
| `src/executor/host/zstd/example-runtime.wasm.zstd` | `1e654f397605e50759773d3cb7e2609fcce2eb7de37b8213ccc093b01a2e47fe` |
| `src/executor/host/zstd/polkadot-runtime-v9160.wasm.zstd` | `ebfeb01e3fd0177c2d80de60d90a66b89b7a8fc83822094ba470afec34a0a111` |
| `src/executor/host/zstd/tests.rs` | `beec3045d6b06096652ef68e10b58a47d20ba8002b1836ce06c2c68784fd4b57` |
| `src/executor/runtime_call.rs` | `a9892a64e8c0ca239f01d265e7f12d3933b7164508e7c5a935c8a53bb5407f9a` |
| `src/executor/runtime_call/child-trie-create-multiple.json` | `c488c26dde76334e8929f040ef97c7085af7c7fd243deb98a90ea9aef97ec0f7` |
| `src/executor/runtime_call/child-trie-create-one.json` | `38c0f584fd29557aa795cd89d017be47597f203c0b43e21c218eff45da2b747f` |
| `src/executor/runtime_call/child-trie-destroy.json` | `b6f09834cdaa09b79dbf667a6fbc0dbc31e61a6841baa5a19605fe69a8581a99` |
| `src/executor/runtime_call/child-trie-read-basic.json` | `a9d0c46d079c2a790851d61a7bf7e5e3064fbc9577f76aa27caf3c5cf28ec791` |
| `src/executor/runtime_call/tests.rs` | `007d30c8c343dfb748fca23b32925008c3833a98049352200f865b042ba8a6c0` |
| `src/executor/storage_diff.rs` | `ff9f5620f8e1728d051fa0c33f61c6f89fb380ea817436985b38380b43b76ce1` |
| `src/executor/trie_root_calculator.rs` | `acc999528a49d7d800003b24171a7c738060c83152a552d52beb9eb4dbade342` |
| `src/executor/trie_root_calculator/tests.rs` | `c903256515dade6221013c43d9ea7f9f1e9d89cdf43f7de53704154bb3ea13cd` |
| `src/executor/vm.rs` | `a21637e1967c7e4036af0b4a63f36b791a495b2ade8698bc79f5638967888de9` |
| `src/executor/vm/interpreter.rs` | `f37264e571b9f919327dc2a28a36fcd558bfabe12fa54f3646270ec3e3139de0` |
| `src/executor/vm/jit.rs` | `0c474a5bad389c3279ea15a7eb3cbd54a55283f8a5d6df07ff23dda8bf8da239` |
| `src/executor/vm/test-polkadot-runtime-v9160.wasm` | `972c0ddb692487d3e728892d20fe27eed182393d661f780832208555814339c0` |
| `src/executor/vm/tests.rs` | `dae02f5fb187ac4ef693f5544e311129720b8e8ea2b69876de707da8420a65cc` |
| `src/identity/ss58.rs` | `4009724ef5ee71225237892a6fafb44004e690d48fa37ff87f213102cc0173c9` |
| `src/json_rpc.rs` | `24fdac2898bc3565aa0cb022113d3d41d54e6c108520b36771d9faebd0fe8b17` |
| `src/json_rpc/methods.rs` | `ef59c7ebac0d175fe98e41ceca87851e790be18186bb37ee45905a9765f3b23b` |
| `src/json_rpc/parse.rs` | `16dd658a69497f6a2373ee718753d3c5c454f2f7ce202452cbc16f057ac8ccc6` |
| `src/json_rpc/payment_info.rs` | `d2a36f6bd1bf29f2bfd116ac65ecfe612f56f955d2c2f6750a57d3fde2c744d3` |
| `src/json_rpc/service.rs` | `334ae16a053691988a9ae0bb1a2404a1e58e03eb0f96a7d0bfd4f6329461421d` |
| `src/json_rpc/service/client_main_task.rs` | `27e6a64ea70fafe131e39d0b0c84dd85743c9a52309c1b4be9b419ce33121a88` |
| `src/json_rpc/service/deliver_channel.rs` | `94e3077c9894639702d7e1175a0ce8c3fa8245601675e0f1b44d3303848ea578` |
| `src/trie.rs` | `a0031dd861b51e4503b910ae2d28ef96e20a4fb69b5b739cf5ac8027ab8efd28` |
| `src/trie/branch_search.rs` | `bae4e9e5333ae3b530d2d2633160761d9f909e906aea5cc722a4935ddb3c1abf` |
| `src/trie/branch_search/tests.rs` | `66504be579374f5f4dcb0150ade9f240522665163df01cf48f9fb7b3965d0d5d` |
| `src/trie/calculate_root.rs` | `148bdd6b81052b38955b78e3e0b01d2f697f627f32d27601dc041cefcfe2d8f4` |
| `src/trie/minimize_proof.rs` | `36802547ef87c2f44b9c74661d38d75c964285f3325bbe73bc6706713547ee48` |
| `src/trie/nibble.rs` | `ab2b0576779649296a5f2f704433f716c1ab9b3ea6d6cb857f47ae33bdaa7704` |
| `src/trie/prefix_proof.rs` | `38c189f4cd75e7ae60e64201d60921df50d9b307def0b2a890cc0645aa71f4c9` |
| `src/trie/prefix_proof/test.json` | `23914874daa1d226cdcf1a941b5e55d451d51a1701f6964f3e7d2c3cca7445fd` |
| `src/trie/prefix_proof/tests.rs` | `70e125e338f3d3154669bd4d44497f774cb289cd7e42a20d5cf1986234a01864` |
| `src/trie/proof_decode.rs` | `2a64103d4735a53e281b5ea13b8007a489c8bc9ee52b02b0488a2b147f60f593` |
| `src/trie/proof_decode/issue_2035_bis_proof` | `d39749ad2f5a6b2b20188de9261cc6911963fe6bc7eacdec5e0bf8fa12b5fc8d` |
| `src/trie/proof_decode/issue_2035_proof` | `bd7fbb199b104709a4acf68fda953e02429cdfe771e12894edd292fa333f99cd` |
| `src/trie/proof_decode/issue_2035_ter_proof` | `56954c674595700681b6623f55b93041544eb50d0c07b45e04ad534c9394928e` |
| `src/trie/proof_decode/tests.rs` | `22c094a96ef4483d2d0821ac349e368b06b69919ded13947a9ee911296561d1c` |
| `src/trie/proof_encode.rs` | `27e7e37ef46f8f041bf0bafe2e2dd0a0033b41787ed2d316f90f61fb84af8173` |
| `src/trie/trie_node.rs` | `567901b0f47723771b3d552d18c778cf0036e32d8b6f8f125c2562b1dde30282` |
| `src/trie/trie_structure.rs` | `feb9e44921d5af4521069adb2a61babad38519575dd1ad068cafc9af9e7119ac` |
| `src/trie/trie_structure/tests.rs` | `4cab9af716dd3d47fab5707fbfc9a39aa5c7ee34db56caeda9dbcf815f6a4946` |
| `src/util.rs` | `0cc3eda2f5c841972aa882c5db6588aa6f59430bb356f482d327b0f1dc9709e7` |
| `src/util/leb128.rs` | `4c1ba6194ac92d9035b59fcdcbd0dd202113a6461cc37dfe090d271b746fd3ab` |
| `src/util/protobuf.rs` | `23eec57ad306152044f672b6077b810edc068f33dd6d6ec4dd911a4965aa3e7f` |

`src/identity.rs` 是 CitizenSDK 的最小模块适配文件，只公开 `pub mod ss58;`，目的是让
逐字节保留的 `json_rpc/methods.rs` 继续使用上游模块路径。它不是源码真源、钱包、账户
体系或密钥实现。`identity/keystore.rs` 与 `identity/seed_phrase.rs` 没有复制。

`database/full_sqlite` 保持上游来源以保存模块基线，但由 `database-sqlite` 特性门控；
CitizenSDK 移动轻节点使用 `finalized_serialize` 的紧凑 finalized database，不把 SQLite
数据库当作钱包或密钥存储。

## smoldot 网络、同步与交易来源基线

以下 61 个文件从 `citizenapp/smoldot/pow/lib` 逐字节复制到
`citizensdk/native/smoldot/pow/lib`，本阶段不修改源码、注释或测试夹具：

| 相对文件 | SHA-256 |
|---|---|
| `src/chain_spec.rs` | `5fe6308dbfdedfb7ad33f64763d16dad501fdd93254bd1195d3c4214d7ed45b4` |
| `src/chain_spec/light_sync_state.rs` | `52f697936ac6cf8ffc8e8df26bb81d37ce23cfb4c1940e900b251112c51eb5e5` |
| `src/chain_spec/structs.rs` | `e0a1a0dc9ba7c303a1f03224c886cd3b5337dba2872555bce7521bc6b733ba77` |
| `src/chain_spec/tests.rs` | `ddf724df4365695304bb81f0275c7229354742702ed42f5226a47494e7bc7de0` |
| `src/chain_spec/tests/example.json` | `5a0df9dcc409766621a2913aadeb69136404a6d387d4a69f27aa24552e68e31a` |
| `src/chain_spec/tests/issue-598.json` | `ca7d0b8837b8464ca84609a956c06f29ae5cdc7beba4da832e3c3ef44b8039fa` |
| `src/informant.rs` | `af7290042637a61bf19562b085f2310cf28de03a877c689c3aa66b06d3568f58` |
| `src/libp2p.rs` | `6b3e328068dcec7e7f485e1552056b20b32680529789607c4f8c1e8f26efca00` |
| `src/libp2p/collection.rs` | `baf47f94643884cdc029014358333d928ac55f215cf735cede5c5e3073a7337d` |
| `src/libp2p/collection/multi_stream.rs` | `fd6d5f97a11adf693d2e7c0c75e5462811b0ae3330590a460f388e5970d4cfed` |
| `src/libp2p/collection/single_stream.rs` | `6f356837cc5d9fd39f8d345505cf3859ee9ca9c236a28088f8ed3b5196848488` |
| `src/libp2p/connection.rs` | `09cca45e5a20a76339f7dea42badb4a2fb3c18c0a55befe82d47f3b5d57dfcc2` |
| `src/libp2p/connection/established.rs` | `137147a51601a850ff46b5e5ec9b2e50b5476d5418e58a7de420a283b6872c96` |
| `src/libp2p/connection/established/multi_stream.rs` | `f618486a723cb60808ebe685cb79531983a46581cefabd423431ca31e8f8a0a5` |
| `src/libp2p/connection/established/single_stream.rs` | `05956c6e5702ab5cc8315d7632534170cd2d4730b36e4883bc362fd45dc4f8a9` |
| `src/libp2p/connection/established/substream.rs` | `d955cc30d96285f7752ac8b7789c72b1f26246ed95b73013d06fafbec7ca21d7` |
| `src/libp2p/connection/established/tests.rs` | `3f4c00ad334dab7fbf898ff109d6c88aba6a88546630a5a55c40772c4ff03e15` |
| `src/libp2p/connection/multistream_select.rs` | `92276bc3bec3e3c23b37138d9814b101d150fd32279c417bd15383bac719281a` |
| `src/libp2p/connection/noise.rs` | `761ef066baa8c55697eca87b0550a8835a349def4e39a62e46a7e26b8bd3b302` |
| `src/libp2p/connection/single_stream_handshake.rs` | `775f6064ca7e34405c34d9eb2ca837efc8bbe9f4561e85288b56929ccc29053d` |
| `src/libp2p/connection/single_stream_handshake/tests.rs` | `670b71602fa0a2ca1538698862afc5753b4d09fde574edae830d4a145d6da6f8` |
| `src/libp2p/connection/webrtc_framing.rs` | `3af9fd345138ed0cc7383e14982d3ccef885bdefdf6f17bd2922c2e1f15a1025` |
| `src/libp2p/connection/yamux.rs` | `fd7b9394fa0384123a84f0841d0f861ce1cafe54d049c41a08a8ffdfdfa6dd8f` |
| `src/libp2p/connection/yamux/header.rs` | `ad311b0d988bf01d5c063425e27ca047d4ff591aaa94f55ff68e0aa36730731f` |
| `src/libp2p/connection/yamux/tests.rs` | `f97916c7ac33be14b15d600f001b61bdf3a8ac1d2620844e2f2b4eeffe5e3d47` |
| `src/libp2p/multiaddr.rs` | `1bb2e934333cee6a42f74b6eb815c9c7e8988050cda1167080a256a75e226bc8` |
| `src/libp2p/multihash.rs` | `bc8116707a231f24eb08125327203f8b9d2df0c85647890d25c522be89d45105` |
| `src/libp2p/peer_id.rs` | `a2aa97193cfb42ee7a3b10585575ddaab23cd8daeb43745b17aeb5f4a2524efd` |
| `src/libp2p/read_write.rs` | `916d8ba20c73968077023faec358f6f308783bc1a9092cb2861220deadd5c96b` |
| `src/libp2p/websocket.rs` | `5f590d1ec604733155356bb387022271d35a9f88d2728f2606640eadeeb6f1ee` |
| `src/libp2p/with_buffers.rs` | `e99c9892173ec99410cdc7fbd18bac3fc9f6679d4cc14d2d03b5eb5b09e28edc` |
| `src/network.rs` | `adf894f77725ca0e545919cb40bdf249d8d96709cd969e0feaccdc76a33aa0f9` |
| `src/network/basic_peering_strategy.rs` | `482e679ba7825eb20cf8c8ae317a110a8d0bff8ce02c2707b57dcbb85bdd2cd7` |
| `src/network/codec.rs` | `5635626997c4679ad9faf6ef5ea8c4d56793cfcf17dbcc79c3093d442a687547` |
| `src/network/codec/block_announces.rs` | `01be64235237063f87dfd9099d2e3f2ebcb9269f9b7125b8072ae73dc24d81ef` |
| `src/network/codec/block_request.rs` | `81ec89c8b946f7e8b3bce502ea879a749d255feead59f66d484bbd91fde95110` |
| `src/network/codec/grandpa.rs` | `3827c539de5557f251d97229db27ac4d6800fee3fe00caf733ede27b7d493344` |
| `src/network/codec/grandpa_warp_sync.rs` | `2dbfea017c2b42b27ebd5fc81e532835e3db611ccd6a7725f12d5c43231e4466` |
| `src/network/codec/identify.rs` | `7f5f9c445ba345f2bf14bd97d256bdce331803fc044a06106905f1672cafc76d` |
| `src/network/codec/kademlia.rs` | `f2815a0548c5e1e830cfee46c2f5928210f450d01ad1e1ca340ebaadf3a9b300` |
| `src/network/codec/state_request.rs` | `cb2ff84c2f0537d5e452adeda234baeb339e05e8e8232a24b1e6e9bbfff6e1b4` |
| `src/network/codec/storage_call_proof.rs` | `07bf52d66c3142616d67073eceaed78261e42c90091696feb35d3a631ebaf3b6` |
| `src/network/kademlia.rs` | `d31a24fc8230510914f4b2907117ffbaf150ad0573a156fd2cf59f2541d06e10` |
| `src/network/kademlia/kbuckets.rs` | `b3a0c0c510926365ce665580d3f6b8516d02103f86e6b4172ccf98d44c453a7c` |
| `src/network/service.rs` | `ae18576fcc3fc8de4276e9b292212e89f93547fe3d5eada595678f9c8a9f941c` |
| `src/sync.rs` | `1463ef55230e2da4425de5bfee3fcf96f8b27bde8eba3db9947183fe9543298e` |
| `src/sync/all.rs` | `ee64f82704b7029b7c1ada438b0c0a239c1cfca73c3ac189e6a9827a3ba925e6` |
| `src/sync/all_forks.rs` | `5fd3da573c7bf0765e0f76c97601043923e7c29470ed5f2e4c593c6023189cbb` |
| `src/sync/all_forks/disjoint.rs` | `7f3782aeb77b056b90ac09ec134bacd0ef61df5d1c2f6d4269f17245787bc297` |
| `src/sync/all_forks/pending_blocks.rs` | `a1fe01594e73b9f909d5beb1a7c98ab5e6207c1c51af41781bf3a60644e845d8` |
| `src/sync/all_forks/sources.rs` | `b56388af2c7aa1434b2e1602331b13d9498330feddba6861906f3db331c0f107` |
| `src/sync/para.rs` | `64a79f0a14465e0ae189572fdbfc60b58ec563f304087f388838f38a2f182f77` |
| `src/sync/warp_sync.rs` | `948cb43b4b943288a603e432221ca18611d916ceece00e38ced2c2b8d0fe871d` |
| `src/transactions.rs` | `30821a6c04ae30181f7c90964da78b673843e8dbc459812f0843b7a1ce887d43` |
| `src/transactions/light_pool.rs` | `de66b9b9cd041391c6a10495d15fa00ba6e2f5ed9e43d79492cafeb12a5bffad` |
| `src/transactions/light_pool/tests.rs` | `d14fcacea3e6172cef5eb83862c88d4395aedb4e64a4785517e791019e29e211` |
| `src/transactions/pool.rs` | `26a867bfa6527dc24d8f2d22bf2b98903a032e28d45edbe2ff049a01d705d0ae` |
| `src/transactions/pool/tests.rs` | `b6e23a4fc9cf9a6e78a16ded56a74362e1f9245f66e378619bfbd73a21c477a7` |
| `src/transactions/validate.rs` | `7b8934d4e4a5c2bc803945e5ca826f490a7f79d9aff4fdf58a1a9db13c3f6e75` |
| `src/transactions/validate/test-fixture.json` | `be4323fedd2d994c42be532088d82815a85bac531a1c828553fe022c695f48a4` |
| `src/transactions/validate/tests.rs` | `92a0411a365cc063d521209d7cc8037eee474f3e9ad6df23b4a05e28b48199c7` |

## PoW workspace 与 smoldot crate 净化基线

三个入口文件先逐字节复制，再仅执行下表所列的 CitizenSDK 边界修改：

| 文件 | CitizenApp 基线 SHA-256 | CitizenSDK 净化后 SHA-256 | 修改 |
|---|---|---|---|
| `native/smoldot/pow/Cargo.toml` | `0104de46f6505403b82b8673e752e29d9a0be05cede5145501053829407d006f` | `f5facfa936fc23def8b999e597d1c73b80e3cd75c8e0dc0ed2206921379d5f44` | workspace 仅保留 `lib` 与 `light-base` |
| `native/smoldot/pow/lib/Cargo.toml` | `c11041df5741cecc72484f113caa23896c7e08e8aef9f34187b6ad61b9ebdde8` | `bb4b7ee67f8e3ae28d12f54e699ed51044e3534b553f0f3ee988ee3ffcc9b841` | 删除 `bip39`、`hmac`、`pbkdf2` 与 `schnorrkel/getrandom` |
| `native/smoldot/pow/lib/src/lib.rs` | `1c5690979bde03d718416a59b4bc86212d3ba040fd2883115a7a7175de85123e` | `d61652c79fb324f83890bf86884db6085e6e3b589f7333cdc5aec9ee0717a143` | 只删除 `pub mod author;` |

保留 `schnorrkel`、`merlin` 和 `ed25519-zebra` 是为了验证链共识及 runtime 加密函数；
保留 `chacha20`、`poly1305`、`x25519-dalek` 与 `zeroize` 是为了 libp2p Noise 传输握手。
这些能力不建立钱包或管理员密钥存储。

`light-base/network_service.rs` 为每条连接重新生成 libp2p 与 Noise key，并将临时字节包在
`Zeroizing` 中。连接级传输密钥不持久化，也不与 CitizenSDK signer、钱包账户、TUYU
账户或商家管理员身份共用。

## Dart/Flutter、钱包与交易来源基线

第 7 步首先逐字节迁入以下稳定文件和链资产；目标哈希与来源完全相同：

| CitizenApp 来源 | CitizenSDK 目标 | SHA-256 |
|---|---|---|
| `citizenapp/assets/chainspec.json` | `assets/chainspec.json` | `6ae934933682a8ffca78663dd4391a730b6ae219bd12abfb5d96b4d8154fc2e0` |
| `citizenapp/assets/light_sync_state.json` | `assets/light_sync_state.json` | `014802836a0f6e01a9f1bf7173b8e04c9df8fc3f057565f855abdccdc7361ab6` |
| `citizenapp/smoldot/dart/lib/src/bindings.dart` | `lib/src/smoldot/bindings.dart` | `33d23827c203a0d3f92146f2da27de4615badb8e3732f23b56dbcd79596d31da` |
| `citizenapp/smoldot/dart/lib/src/chain.dart` | `lib/src/smoldot/chain.dart` | `0d3e341d60cca0bb3161b8eeb3710e838aa5e1b33cc23f0e3c298b4ecb8eaba9` |
| `citizenapp/smoldot/dart/lib/src/client.dart` | `lib/src/smoldot/client.dart` | `e238c48e78c5125a7a5b85bb0c06d0c7708128d4331f5d4d817959d37c3226e7` |
| `citizenapp/smoldot/dart/lib/src/json_rpc.dart` | `lib/src/smoldot/json_rpc.dart` | `c81ed472e43ce2d9ccb56ce82477a2c4ff775de29932d26a0aef976d044ed53c` |
| `citizenapp/smoldot/dart/lib/src/types.dart` | `lib/src/smoldot/types.dart` | `e20b6f97d0b6e289c2b492e12dd66afafc1133adc0fc5fe5a547106ed3338e89` |

`chainspec.json` 的来源文件没有末尾换行，目标同样保留该字节形态。以下文件先以稳定来源
为行为基线，再只在 CitizenSDK 内剥离产品依赖或收紧公共接口：

| 稳定来源与 SHA-256 | CitizenSDK 目标与最终 SHA-256 | 适配边界 |
|---|---|---|
| `smoldot/dart/lib/src/platform.dart` `65f48e6cc98a47895973409e79543c4b15ba2311228959bc8a6e8895c4395b95` | `lib/src/smoldot/platform.dart` `75c09a05ac00a0ce5aacd3deae73c17c64788e7bbd4fcc574e11e3b08fbb80cd` | 删除 CitizenApp/target 开发路径与脚本提示，保留官方库名 `smoldot` |
| `lib/wallet/core/native_sr25519.dart` `a5cd6943ba8cecb9191d0e4e2951910c41ec183680a8f2523632848713b3091b` | `lib/src/crypto/native_sr25519.dart` `2d38dccb8ad61c7f8dfea76d778fcf3ac21454ea85785284bd76e648eabce4eb` | 仅改内部 smoldot import、来源说明和格式 |
| `shared/wallet-password/lib/wallet_mini_secret.dart` `0f57539411e42b6d3c57d960a01c2eb4121d8c0d181c50e8ec9a69ac864f55cf` | `lib/src/crypto/wallet_mini_secret.dart` `0ffed1efd9b91350895ef0830c5c69e6ed89afa617e8dc38d3f35e31584653d8` | 保留 substrate_bip39 实现，只清理“两款 App”注释 |
| `shared/wallet-password/lib/wallet_password.dart` `17eb2a119068228f9463a86f31e6a6918f8a4bcaf95369ab94627aaf74ecaf64` | `lib/src/crypto/wallet_password.dart` `6e36f405a62829244f8550d848cb683c96a31eb23adaac0c776328eaebb7fa0a` | 只提取 password 校验/NFKD 核心，不迁入 Flutter 输入框和弹窗 |
| `lib/wallet/core/secure_seed_store.dart` `5110f2fa4b18ede02ac5ba929a39fe3f01940861351cdff17cf5b49a69fb96f4` | `lib/src/wallet/secure_seed_store.dart` `28d0e0346a95a75bcde5849f9a9426a6054ee81f5549433374d282344701db79` | 保留 ROOTLESS 接口，补充幂等清理契约 |

以下是行为提炼而非逐字节复制。来源文件同时包含 CitizenApp 单例、Isar、日志、身份、广场、
聊天或服务端中继，因此不得整体迁入：

| CitizenApp 行为基线 | CitizenSDK 产品无关实现 |
|---|---|
| `lib/rpc/smoldot_client.dart` `8fb89f2facfd6f02b3086801e540149a61bea937cfd4bacec3afa2a5a52f772b` | `lib/src/node/light_client.dart` `351958b518ff7d6914fa62fde441cab87cc7dd0a9f1b8bab22388b48986cfd4c` |
| `lib/rpc/chain_bootstrap_api.dart` `61a3f422cf8ae7fcada20d5f2f08e0857155b75c8fd69856fd8fba864d8be0bb` | `bootstrap_manifest.dart` `648cd16313e89b07a5abbd3492f5c5aebd68d7b3f860d4e11e0120a70fc9c09e`、`bootstrap_client.dart` `2bd2172ac2af63ad7f51df0eb12cd9f5303654ca57b1935ee7aa30755bbf0284`、`chain_assets.dart` `d2390c2b37dcbf9392d28c53c0752116ebb2f19b24ecaeda3788afe9c18f5086` |
| `lib/wallet/core/wallet_manager.dart` `ec0e6fa1f0f97047ad54e37a6ac34c65e3626e405e557356a7ab43d0a2970f6c` | `lib/src/wallet/wallet_service.dart` `43234532103709ee0ec6f4d102547f76f928901eab78b2f3f0bc82cd3c6c8456` |
| `lib/rpc/chain_rpc.dart` `0784269cb147bf482f8ae5f1460189f10bdb51c3ddfaa646561ae2d43c77c083` | `lib/src/transaction/chain_rpc.dart` `05b909f8625addfd98fbccce4811d0f8fa5049a3fa2b928f8fc62567d3f63b75` |
| `lib/rpc/signed_extrinsic_builder.dart` `f9ab8664f37d065492458ac707c36abe8bec44f56ccc22c56ef34fc21ab3cba6` | `lib/src/transaction/signed_extrinsic_builder.dart` `f7b17c2371ecfc8814a313110ffa90de4a304055af3a954de878ea7560cd367a` |
| `lib/rpc/transfer_rpc.dart` `f6be0c87763a68c24fbf0de8541f06997742b3c309784cfff386ab92f261c1cc` | `lib/src/transaction/transfer_service.dart` `173d7071affa6dc851ba6f47e438bb22754d9e209e244ff64ed85072c1b65e1e` |
| `lib/rpc/pallet_registry.dart` `e56b89aa28f54b833e60b0c94ba560d97e9b5148f7b3aa4abd69e0bec921ac41` | `lib/src/transaction/pallet_registry.dart` `dbbd0bb7752a41b8ba59be1631b55059b4559ed7f6449906d03ff5bccef7592b` |

交易适配保留 finalized 读取、实时 runtime nonce、immortal era、sr25519 与
`OnchainTransaction::transfer_with_remark` 字节协议；删除 CitizenApp 日志、缓存单例、
业务 pallet 和服务器中继。钱包适配保留 `//0..//1989` 与 child-only 金库，新增产品无关的
revision CAS 仓储和可恢复清理计划，不迁入 Isar、公民身份、CID、广场或聊天代码。

## 第 8 步：Android/iOS 硬件金库与移动持久化

本步骤只读取现有稳定实现并在 CitizenSDK 新目录内适配；没有修改来源文件或 CitizenApp。
稳定行为基线如下：

| 稳定来源 | SHA-256 | CitizenSDK 适配 |
|---|---|---|
| `shared/hardware-secretvault/lib/hardware_secretvault.dart` | `29fb624765dc930057ec3bb50044ddd3d7d4fcf5877bc52397b31b0390097860` | 保留 AAD 字节格式、字节通道、错误码和缓冲区所有权规则；新写入产品固定为 `citizensdk` |
| `shared/hardware-secretvault/android/src/main/kotlin/org/gmb/hardware_secretvault/HardwareSecretvaultPlugin.kt` | `504d459cc3aef95c8a5b01023fed9c1b83325da540c7343d7b23c73a1b4bb321` | 保留 RSA-OAEP、AES-256-GCM、v1 信封、StrongBox/TEE 和逐次强生物识别 |
| `shared/hardware-secretvault/android/src/test/kotlin/org/gmb/hardware_secretvault/HardwareSecretvaultPluginTest.kt` | `4467439ac571c374a898142ae87e29aecad95fc2d39be47b1b62ce53905ca58b` | 拆分为别名隔离与信封解析测试源码 |
| `shared/hardware-secretvault/ios/Classes/HardwareSecretvaultPlugin.swift` | `9a04dd07ea72f2384debea4b6385a2bbd1e2e13ea837cee1eec7b6154c80c0a5` | 保留 Secure Enclave、ECIES、v1 信封和 `biometryCurrentSet + privateKeyUsage` |
| `citizenapp/lib/wallet/core/hardware_bound_seed_vault.dart` | `56878e867c34e39bdeffe6329e1a0313731b4d0b5ff49cc2cee6b78226c4432d` | 保留 child-only 金库与错误映射，密文键和硬件产品固定为 SDK；不迁入旧产品兼容行为 |
| `citizenapp/android/app/build.gradle.kts` | `7cfdd26e4f9b7743c168da339f692368db6da0bc1a4f76f4ac66c88ae3f4ae3b` | 继承 `CONSOLE_NATIVE_ANDROID_DIR` 与 ARM64-only 原生产物注入边界 |
| `citizenapp/ios/smoldot/smoldot_ffi.podspec` | `b0fbaa7dd56235aa0ed1d56df5d92a703d602f7d69f90097f908c39f84692132` | 继承 `CONSOLE_NATIVE_IOS_DIR`、实抽符号清单、`-force_load` 和逐符号 `-u` |

适配不是逐字节副本：Flutter 插件注册与安全实现被拆分，通道改为
`citizen/sdk/hardware_secretvault`，硬件别名前缀、AAD 产品和原生命名空间都固定为
`citizensdk`。CitizenSDK 不包含旧产品别名查询、解密、迁移或删除分支；宿主迁移必须在
宿主切换步骤中独立完成。

CitizenSDK 最终移动适配源码哈希如下：

| CitizenSDK 文件 | SHA-256 |
|---|---|
| `lib/src/platform/hardware_secret_vault.dart` | `fe7b8d9d933f8763ee72cb645962dd0741e5626541407eae3f6b57b1b3ad10d7` |
| `lib/src/platform/hardware_bound_seed_store.dart` | `c00625a3a3e11044c96c92547518c87dd6aa1f0d46a79a8d69f2498f4d77057a` |
| `lib/src/platform/secure_blob_store.dart` | `b9e1400f0652b9075974ab13b6de0a8014271d1178cce3dfc0e6c833e71948a8` |
| `lib/src/platform/preferences_wallet_repository.dart` | `fd991ce9eee3d6045aae9b0ab0bb3dc8a8dc8793e35454f6cc89f4a074003e9d` |
| `lib/src/platform/preferences_chain_database_store.dart` | `dfd51e5089826708d3823e8f393c49b846d33509cd1eab979ca4f5bde5fe505e` |
| `lib/src/platform/mobile_citizen_sdk.dart` | `b9b5b3913177ee258d09ea2346bf5191696773d35cc1fa72452497c99bc40220` |
| `android/build.gradle` | `9776ede84feed4c064fa8f07c19a19a6d97e72218d111fd2920d9cc1dc5db8ea` |
| `android/src/main/kotlin/CitizenSdkPlugin.kt` | `56369bb9841a8d39fb303bb2194ff1f9187526e294ccdeebe925a9d74be779b6` |
| `android/src/main/kotlin/AndroidHardwareSecretVault.kt` | `15d771e2bf982ccb5331dd58d35ffd8ec9c0abb6362feb3462d1ede521591cac` |
| `ios/citizen_sdk.podspec` | `ed8cf36ab63ee7268620c74839ad90b143d105fa556e98addcba698ed24a34ac` |
| `ios/Classes/CitizenSdkPlugin.swift` | `87556ed110a2b5074bd0801ea821c7c8224cdaa0985f1b79455c8fbceeaead4d` |
| `ios/Classes/SecureEnclaveSecretVault.swift` | `de80d915d3fced9f27ff0c6aefc2220f3892805fd60e7badf723ffa7394611ab` |

`PreferencesWalletRepository`、`PreferencesChainDatabaseStore` 与移动装配层是 CitizenSDK
新写的产品无关适配，不声明来自 CitizenApp 的逐字节复制。它们只保存公开事实；硬件密文
继续由 `flutter_secure_storage` 保存，明文 mini-secret 不进入 preferences。

## 第 9.1 步：单一产品身份、Bootstrap 与依赖锁

- Dart 金库上下文不再接收产品名，Android/iOS 不再接收除 `citizensdk` 之外的原生命名空间。
- 删除 SDK 内旧金库迁移源码和测试；SDK 不读取、移动或删除任何宿主产品数据。
- SDK 只接受 `/chain/citizensdk/bootstrap` 返回的 `citizensdk.chain.bootstrap`，清单排除
  广场、聊天、媒体和宿主交易中继字段；现有宿主 bootstrap 保持独立。
- GMB 根 Cargo workspace 明确排除 `citizensdk/**`，SDK 的 signer、FFI、PoW 三个 Rust
  workspace 和 Flutter 包分别保存独立锁文件。

| 依赖锁文件 | SHA-256 |
|---|---|
| `pubspec.lock` | `d71a06a3c9b899872e8f1ea28c4a871da02707e2f3ccb0a47a140d33d8465e06` |
| `Cargo.lock` | `62571bec0b3a1f40af270aa22415124ae201f07ebd1d0de35ab23884317d5670` |
| `native/smoldot/ffi/Cargo.lock` | `5b1500c074f6a0f1532fce665c1c95bb023f52d1e63206f36d80430c02e083a4` |
| `native/smoldot/pow/Cargo.lock` | `f97e8c350e08d565623974d13dc34ad97a7a8e03a93508898873c78a8765895d` |
