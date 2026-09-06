use std::num::NonZero;

use citizen_sdk_contracts::{
    validated_finalized_block_range_len, BlockFinality, ChainIdentity, ContractError,
    ContractErrorCode, ContractFuture, ContractResult, ContractStream, ExportedChainState,
    ExtrinsicWatchEvent, FinalizedBlockRef, Hash32, RuntimeContext, RuntimeVersion,
    SignedExtrinsic, StateImportReceipt, SubmittedExtrinsic, VerifiedBlockRef, VerifiedChainClient,
    MAX_FINALIZED_BLOCKS_PER_BATCH,
};
use futures_channel::mpsc;
use serde_json::{json, Value};
use smoldot_light::{
    ChainFinalizedAncestryError, ChainFinalizedBlocksSnapshot, ChainStorageValuesSnapshot,
};

use crate::{
    client::{
        contract_error, provider_error, RunningProvider, SmoldotVerifiedChainClient,
        CHAIN_STATE_FORMAT_VERSION, MAX_CHAIN_DATABASE_BYTES,
    },
    legacy::subscription_result,
};

impl VerifiedChainClient for SmoldotVerifiedChainClient {
    fn identity(&self) -> ContractFuture<'_, ChainIdentity> {
        // Engine 必须在 provider.start 之前核对导入信封身份，因此 identity 是已验证配置的
        // 静态事实，不以网络运行状态为门禁。start 仍会从 smoldot 真实解析结果复核 genesis。
        Box::pin(async { Ok(ChainIdentity::citizenchain()) })
    }

    fn get_best_head(&self) -> ContractFuture<'_, VerifiedBlockRef> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            best_head(&running).await
        })
    }

    fn get_finalized_head(&self) -> ContractFuture<'_, FinalizedBlockRef> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            finalized_head(&running).await
        })
    }

    fn subscribe_finalized_heads(&self) -> ContractStream<'_, FinalizedBlockRef> {
        let (mut sender, receiver) = mpsc::channel(1);
        let preparation = self.running().and_then(|running| {
            let lease = running.rpc.reserve_finalized_worker()?;
            Ok((running, lease))
        });
        let (running, lease) = match preparation {
            Ok(value) => value,
            Err(error) => {
                let _ = sender.try_send(Err(error));
                return Box::pin(receiver);
            }
        };
        self.runtime_handle().spawn(async move {
            let (id, mut notifications) = match running.rpc.subscribe_finalized_heads().await {
                Ok(value) => value,
                Err(error) => { let _ = sender.try_send(Err(error)); return; }
            };
            let mut previous = None;
            let mut pending = None;
            while !sender.is_closed() && !lease.stopping() && !running.rpc.is_closed() {
                if let Some(value) = pending.take() {
                    if let Err(error) = sender.try_send(value) {
                        if error.is_disconnected() { break; }
                        pending = Some(error.into_inner());
                    }
                }
                // 只检查取消，不轮询区块；零 peers 或安静链不会结束订阅。
                let value = match tokio::time::timeout(std::time::Duration::from_millis(250), notifications.recv()).await {
                    Err(_) => continue,
                    Ok(Ok(value)) => value,
                    Ok(Err(tokio::sync::broadcast::error::RecvError::Lagged(_))) => {
                        // finalized 快照可以合并，重新读取 smoldot 验证后的准确头。
                        json!({"method":"chain_finalizedHead","params":{"subscription":id,"result":null}})
                    }
                    Ok(Err(tokio::sync::broadcast::error::RecvError::Closed)) => break,
                };
                if value.get("method").and_then(Value::as_str) != Some("chain_finalizedHead")
                    || subscription_result(&value, &id).is_none() { continue; }
                // RPC header 只是唤醒信号，证明来自已有 typed verified snapshot。
                match finalized_head(&running).await {
                    Ok(block) if previous != Some(block) => {
                        previous = Some(block);
                        pending = Some(Ok(block));
                    }
                    Ok(_) => {}
                    Err(error) => { pending = Some(Err(error)); }
                }
            }
            if let Err(error) = running.rpc.unsubscribe_finalized_heads(&id).await { lease.fail(error); }
        });
        Box::pin(receiver)
    }

    fn get_finalized_block_at(&self, number: u64) -> ContractFuture<'_, FinalizedBlockRef> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            finalized_block_at(&running, number).await
        })
    }

    fn get_finalized_blocks_at(
        &self,
        start_number: u64,
        end_number: u64,
    ) -> ContractFuture<'_, Vec<FinalizedBlockRef>> {
        let range_validation =
            validated_finalized_block_range_len(start_number, end_number).map(|_| ());
        Box::pin(async move {
            range_validation?;
            let running = self.running()?;
            finalized_blocks_at(&running, start_number, end_number).await
        })
    }

    fn resolve_finalized_block(
        &self,
        hash: Hash32,
        number: u64,
    ) -> ContractFuture<'_, FinalizedBlockRef> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            let canonical = finalized_block_at(&running, number).await?;
            if canonical.hash() != hash {
                return Err(contract_error(
                    ContractErrorCode::Conflict,
                    "目标 hash 不是该高度的 finalized canonical hash",
                ));
            }
            Ok(canonical)
        })
    }

    fn get_storage_at(
        &self,
        block: VerifiedBlockRef,
        key: Vec<u8>,
    ) -> ContractFuture<'_, Option<Vec<u8>>> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            validate_exact_block(&running, block).await?;
            storage_at(&running, block, key).await
        })
    }

    fn get_storage_batch_at(
        &self,
        block: VerifiedBlockRef,
        keys: Vec<Vec<u8>>,
    ) -> ContractFuture<'_, Vec<Option<Vec<u8>>>> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            validate_exact_block(&running, block).await?;
            validate_storage_keys(&keys)?;
            if keys.is_empty() {
                return Ok(Vec::new());
            }

            // 先按当前头规划快速路线；typed batch 返回它在异步操作内部实际选中的
            // block 身份。只有该身份与调用者请求的准确 block 完全一致才接受结果，
            // 否则按准确 hash 回退。不能用“调用前后头相同”替代这个证明，因为头可能
            // 在操作期间发生 A→B→A。
            let before = storage_batch_heads(&running).await?;
            let route = select_storage_batch_route(block, before);
            if route == StorageBatchRoute::ExactHash {
                return storage_batch_exact_at(&running, block, keys).await;
            }

            let expected_len = keys.len();
            let snapshot = current_storage_batch(&running, route, keys.clone()).await?;
            validate_storage_batch_len(expected_len, snapshot.values.len())?;
            if !storage_snapshot_matches_block(&snapshot, block) {
                return storage_batch_exact_at(&running, block, keys).await;
            }
            Ok(snapshot.values)
        })
    }

    fn get_runtime_context_at(
        &self,
        block: VerifiedBlockRef,
    ) -> ContractFuture<'_, RuntimeContext> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            validate_exact_block(&running, block).await?;
            let hash = hash_hex(block.hash());
            // 两个请求都显式携带同一个准确 block hash；不允许分别读取“当前”版本与 metadata。
            let version_value = running
                .rpc
                .request("state_getRuntimeVersion", json!([hash]))
                .await?;
            let metadata_value = running
                .rpc
                .request("state_getMetadata", json!([hash_hex(block.hash())]))
                .await?;
            let spec_version = parse_u32_field(&version_value, "specVersion")?;
            let transaction_version = parse_u32_field(&version_value, "transactionVersion")?;
            let metadata = parse_hex_value(&metadata_value, "runtime metadata")?;
            RuntimeContext::try_new(
                block,
                RuntimeVersion::new(spec_version, transaction_version),
                metadata,
            )
        })
    }

    fn get_block_extrinsics_at(&self, block: VerifiedBlockRef) -> ContractFuture<'_, Vec<Vec<u8>>> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            validate_exact_block(&running, block).await?;
            let body_future = {
                let client = running.client.lock();
                client
                    .chain_block_extrinsics(running.chain_id, block.hash().into_bytes())
                    .map_err(provider_error)?
            };
            body_future.await.map_err(provider_error)
        })
    }

    fn submit_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> ContractFuture<'_, SubmittedExtrinsic> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            let encoded = format!("0x{}", hex::encode(extrinsic.as_bytes()));
            let result = running
                .rpc
                .request("author_submitExtrinsic", json!([encoded]))
                .await?;
            let returned_hash = parse_hash_value(&result, "submitted extrinsic hash")?;
            verify_submitted_hash(extrinsic.as_bytes(), returned_hash)
        })
    }

    fn watch_extrinsic(
        &self,
        extrinsic: SignedExtrinsic,
    ) -> ContractStream<'_, ExtrinsicWatchEvent> {
        let (sender, receiver) = mpsc::unbounded();
        let running = match self.running() {
            Ok(running) => running,
            Err(error) => {
                let _ = sender.unbounded_send(Err(error));
                return Box::pin(receiver);
            }
        };
        let lease = match running.rpc.reserve_finalized_worker() {
            Ok(lease) => lease,
            Err(error) => {
                let _ = sender.unbounded_send(Err(error));
                return Box::pin(receiver);
            }
        };
        let runtime = self.runtime_handle();
        runtime.spawn(async move {
            let encoded = format!("0x{}", hex::encode(extrinsic.as_bytes()));
            let subscription = running.rpc.subscribe_extrinsic(encoded).await;
            let (subscription, mut notifications) = match subscription {
                Ok(subscription) => subscription,
                Err(error) => {
                    let _ = sender.unbounded_send(Err(error));
                    return;
                }
            };

            while !lease.stopping() && !sender.is_closed() {
                let notification = match tokio::time::timeout(
                    std::time::Duration::from_millis(250),
                    notifications.recv(),
                )
                .await
                {
                    Ok(notification) => notification,
                    Err(_) => {
                        if sender.is_closed() || running.rpc.is_closed() {
                            break;
                        }
                        continue;
                    }
                };
                let value = match notification {
                    Ok(value) => value,
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                        let _ = sender.unbounded_send(Err(contract_error(
                            ContractErrorCode::Network,
                            "交易观察事件队列溢出，不能保证状态连续性",
                        )));
                        break;
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                };
                let Some(status) = subscription_result(&value, &subscription) else {
                    continue;
                };
                match parse_watch_event(&running, status).await {
                    Ok((event, terminal)) => {
                        if sender.unbounded_send(Ok(event)).is_err() || terminal {
                            break;
                        }
                    }
                    Err(error) => {
                        let _ = sender.unbounded_send(Err(error));
                        break;
                    }
                }
            }
            if let Err(error) = running.rpc.unwatch_extrinsic(&subscription).await {
                lease.fail(error);
            }
        });
        Box::pin(receiver)
    }

    fn export_state(&self) -> ContractFuture<'_, ExportedChainState> {
        let running = self.running();
        Box::pin(async move {
            let running = running?;
            let before = finalized_head(&running).await?;
            let result = running
                .rpc
                .request(
                    "chainHead_unstable_finalizedDatabase",
                    json!([MAX_CHAIN_DATABASE_BYTES]),
                )
                .await?;
            let database = result.as_str().ok_or_else(|| {
                contract_error(
                    ContractErrorCode::Decode,
                    "smoldot finalized database 响应不是字符串",
                )
            })?;
            if database.is_empty() || database.len() > MAX_CHAIN_DATABASE_BYTES {
                return Err(contract_error(
                    ContractErrorCode::Integrity,
                    "smoldot 导出的数据库为空或超过 256 KiB",
                ));
            }
            let parsed: Value = serde_json::from_str(database).map_err(|error| {
                contract_error(
                    ContractErrorCode::Decode,
                    format!("smoldot 导出的数据库不是有效 JSON: {error}"),
                )
            })?;
            if !parsed.is_object() {
                return Err(contract_error(
                    ContractErrorCode::Decode,
                    "smoldot 导出数据库根必须是 JSON object",
                ));
            }
            let after = finalized_head(&running).await?;
            if before != after {
                return Err(contract_error(
                    ContractErrorCode::Conflict,
                    "导出期间 verified finalized 已移动，丢弃本次数据库",
                ));
            }
            ExportedChainState::try_new(
                ChainIdentity::citizenchain(),
                CHAIN_STATE_FORMAT_VERSION,
                before,
                database.as_bytes().to_vec(),
            )
        })
    }

    fn import_state(&self, state: ExportedChainState) -> ContractFuture<'_, StateImportReceipt> {
        Box::pin(async move {
            let finalized = self.import_before_start(state)?;
            Ok(StateImportReceipt::new(finalized))
        })
    }
}

async fn best_head(running: &RunningProvider) -> ContractResult<VerifiedBlockRef> {
    let snapshot_future = {
        let client = running.client.lock();
        client
            .chain_status_snapshot(running.chain_id)
            .map_err(provider_error)?
    };
    let snapshot = snapshot_future.await.map_err(provider_error)?;
    Ok(VerifiedBlockRef::best(
        Hash32::from_bytes(snapshot.best_block_hash),
        snapshot.best_block_number,
    ))
}

async fn finalized_head(running: &RunningProvider) -> ContractResult<FinalizedBlockRef> {
    let snapshot_future = {
        let client = running.client.lock();
        client
            .chain_status_snapshot(running.chain_id)
            .map_err(provider_error)?
    };
    let snapshot = snapshot_future.await.map_err(provider_error)?;
    Ok(FinalizedBlockRef::from_parts(
        Hash32::from_bytes(snapshot.current_verified_finalized_block_hash),
        snapshot.current_verified_finalized_block_number,
    ))
}

/// 单块入口复用 batch ancestry walk，避免产生第二种 finalized 证明语义。
async fn finalized_block_at(
    running: &RunningProvider,
    number: u64,
) -> ContractResult<FinalizedBlockRef> {
    let mut blocks = finalized_blocks_at(running, number, number).await?;
    match blocks.pop() {
        Some(block) if blocks.is_empty() && block.number() == number => Ok(block),
        _ => Err(contract_error(
            ContractErrorCode::Integrity,
            "smoldot finalized ancestry singleton 返回了非单块结果",
        )),
    }
}

/// 从 light-base 一次 proof-backed ancestry walk 投影准确、升序且完整的 finalized 闭区间。
async fn finalized_blocks_at(
    running: &RunningProvider,
    start_number: u64,
    end_number: u64,
) -> ContractResult<Vec<FinalizedBlockRef>> {
    let _expected_len = validated_finalized_block_range_len(start_number, end_number)?;
    let maximum_blocks = NonZero::<u64>::new(MAX_FINALIZED_BLOCKS_PER_BATCH).ok_or_else(|| {
        contract_error(
            ContractErrorCode::Internal,
            "contracts finalized batch 上限意外为零",
        )
    })?;
    let ancestry_future = {
        let client = running.client.lock();
        client
            .chain_finalized_blocks_at(running.chain_id, start_number, end_number, maximum_blocks)
            .map_err(finalized_ancestry_error)?
    };
    let snapshot = ancestry_future.await.map_err(finalized_ancestry_error)?;
    finalized_refs_from_snapshot(snapshot, start_number, end_number)
}

fn finalized_ancestry_error(error: ChainFinalizedAncestryError) -> ContractError {
    let code = match &error {
        ChainFinalizedAncestryError::InvalidArgument(_) => ContractErrorCode::InvalidArgument,
        ChainFinalizedAncestryError::AboveVerifiedUpper(_) => ContractErrorCode::NotFound,
        ChainFinalizedAncestryError::Integrity(_) => ContractErrorCode::Integrity,
        ChainFinalizedAncestryError::Unavailable(_) => ContractErrorCode::Network,
    };
    contract_error(code, error.to_string())
}

fn finalized_refs_from_snapshot(
    snapshot: ChainFinalizedBlocksSnapshot,
    start_number: u64,
    end_number: u64,
) -> ContractResult<Vec<FinalizedBlockRef>> {
    let expected_len = validated_finalized_block_range_len(start_number, end_number)?;
    if start_number > end_number || snapshot.upper_block_number < end_number {
        return Err(contract_error(
            ContractErrorCode::Integrity,
            "smoldot finalized ancestry 上界或请求范围无效",
        ));
    }
    if snapshot.blocks.len() != expected_len {
        return Err(contract_error(
            ContractErrorCode::Integrity,
            "smoldot finalized ancestry 返回了部分区间",
        ));
    }

    let mut refs = Vec::with_capacity(expected_len);
    for (index, block) in snapshot.blocks.into_iter().enumerate() {
        let offset = u64::try_from(index).map_err(|_| {
            contract_error(
                ContractErrorCode::Integrity,
                "finalized ancestry 索引超过 u64",
            )
        })?;
        let expected_number = start_number.checked_add(offset).ok_or_else(|| {
            contract_error(
                ContractErrorCode::Integrity,
                "finalized ancestry 高度顺序溢出",
            )
        })?;
        if block.block_number != expected_number {
            return Err(contract_error(
                ContractErrorCode::Integrity,
                "smoldot finalized ancestry 不是准确升序连续区间",
            ));
        }
        refs.push(FinalizedBlockRef::from_parts(
            Hash32::from_bytes(block.block_hash),
            block.block_number,
        ));
    }
    Ok(refs)
}

async fn validate_exact_block(
    running: &RunningProvider,
    block: VerifiedBlockRef,
) -> ContractResult<()> {
    if block.finality() == BlockFinality::Finalized {
        // `finalized_block_at` 固定执行“verified 上界 → canonical 高度映射”的安全顺序。
        // finality 不回退，所以上界内已证明高度不会在随后的 await 期间被重组。
        let canonical = finalized_block_at(running, block.number()).await?;
        if canonical.hash() != block.hash() {
            return Err(contract_error(
                ContractErrorCode::Conflict,
                "目标 hash 不属于 verified finalized canonical 链",
            ));
        }
        return Ok(());
    }

    let observed_number = block_number_by_hash(running, block.hash()).await?;
    if observed_number != block.number() {
        return Err(contract_error(
            ContractErrorCode::Integrity,
            "block hash 对应高度与 VerifiedBlockRef 不一致",
        ));
    }
    let canonical = running
        .rpc
        .request("chain_getBlockHash", json!([block.number()]))
        .await?;
    let canonical = parse_hash_value(&canonical, "canonical block hash")?;
    if canonical != block.hash() {
        return Err(contract_error(
            ContractErrorCode::Conflict,
            "VerifiedBlockRef 已不在轻节点 canonical 视图中",
        ));
    }
    Ok(())
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum StorageBatchRoute {
    CurrentBest,
    CurrentVerifiedFinalized,
    ExactHash,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct StorageBatchHeads {
    best: VerifiedBlockRef,
    surface_finalized: FinalizedBlockRef,
    verified_finalized: FinalizedBlockRef,
}

async fn storage_batch_heads(running: &RunningProvider) -> ContractResult<StorageBatchHeads> {
    let snapshot_future = {
        let client = running.client.lock();
        client
            .chain_status_snapshot(running.chain_id)
            .map_err(provider_error)?
    };
    let snapshot = snapshot_future.await.map_err(provider_error)?;
    Ok(StorageBatchHeads {
        best: VerifiedBlockRef::best(
            Hash32::from_bytes(snapshot.best_block_hash),
            snapshot.best_block_number,
        ),
        surface_finalized: FinalizedBlockRef::from_parts(
            Hash32::from_bytes(snapshot.finalized_block_hash),
            snapshot.finalized_block_number,
        ),
        verified_finalized: FinalizedBlockRef::from_parts(
            Hash32::from_bytes(snapshot.current_verified_finalized_block_hash),
            snapshot.current_verified_finalized_block_number,
        ),
    })
}

fn select_storage_batch_route(
    block: VerifiedBlockRef,
    heads: StorageBatchHeads,
) -> StorageBatchRoute {
    match block.finality() {
        BlockFinality::Best if block == heads.best => StorageBatchRoute::CurrentBest,
        // typed finalized API 读取同步服务的 surface finalized。只有它与 SDK 的
        // current verified finalized 是同一个准确块时才可使用，warp 目标不能混入。
        BlockFinality::Finalized
            if block == heads.verified_finalized.verified()
                && block == heads.surface_finalized.verified() =>
        {
            StorageBatchRoute::CurrentVerifiedFinalized
        }
        BlockFinality::Best | BlockFinality::Finalized => StorageBatchRoute::ExactHash,
    }
}

async fn current_storage_batch(
    running: &RunningProvider,
    route: StorageBatchRoute,
    keys: Vec<Vec<u8>>,
) -> ContractResult<ChainStorageValuesSnapshot> {
    let batch_future = {
        let client = running.client.lock();
        match route {
            StorageBatchRoute::CurrentBest => client
                .chain_storage_values_snapshot(running.chain_id, keys)
                .map_err(provider_error)?,
            StorageBatchRoute::CurrentVerifiedFinalized => client
                .chain_finalized_storage_values_snapshot(running.chain_id, keys)
                .map_err(provider_error)?,
            StorageBatchRoute::ExactHash => {
                return Err(contract_error(
                    ContractErrorCode::Internal,
                    "历史准确块不能进入 current typed batch",
                ));
            }
        }
    };
    batch_future.await.map_err(provider_error)
}

fn storage_snapshot_matches_block(
    snapshot: &ChainStorageValuesSnapshot,
    block: VerifiedBlockRef,
) -> bool {
    snapshot.block_number == block.number() && snapshot.block_hash == block.hash().into_bytes()
}

async fn storage_batch_exact_at(
    running: &RunningProvider,
    block: VerifiedBlockRef,
    keys: Vec<Vec<u8>>,
) -> ContractResult<Vec<Option<Vec<u8>>>> {
    let mut values = Vec::with_capacity(keys.len());
    for key in keys {
        values.push(storage_at(running, block, key).await?);
    }
    Ok(values)
}

fn validate_storage_keys(keys: &[Vec<u8>]) -> ContractResult<()> {
    if let Some(index) = keys.iter().position(Vec::is_empty) {
        return Err(contract_error(
            ContractErrorCode::InvalidArgument,
            format!("storage key {index} 不能为空"),
        ));
    }
    Ok(())
}

fn validate_storage_batch_len(expected: usize, actual: usize) -> ContractResult<()> {
    if actual != expected {
        return Err(contract_error(
            ContractErrorCode::Integrity,
            format!("smoldot typed storage batch 返回长度错误：期望 {expected}，实际 {actual}"),
        ));
    }
    Ok(())
}

async fn storage_at(
    running: &RunningProvider,
    block: VerifiedBlockRef,
    key: Vec<u8>,
) -> ContractResult<Option<Vec<u8>>> {
    if key.is_empty() {
        return Err(contract_error(
            ContractErrorCode::InvalidArgument,
            "storage key 不能为空",
        ));
    }
    let result = running
        .rpc
        .request("state_getStorage", exact_storage_params(block, key))
        .await?;
    if result.is_null() {
        return Ok(None);
    }
    parse_hex_value(&result, "storage value").map(Some)
}

fn exact_storage_params(block: VerifiedBlockRef, key: Vec<u8>) -> Value {
    json!([format!("0x{}", hex::encode(key)), hash_hex(block.hash())])
}

async fn block_number_by_hash(running: &RunningProvider, hash: Hash32) -> ContractResult<u64> {
    let header = running
        .rpc
        .request("chain_getHeader", json!([hash_hex(hash)]))
        .await?;
    if header.is_null() {
        return Err(contract_error(
            ContractErrorCode::NotFound,
            "轻节点不知道目标 block hash",
        ));
    }
    parse_u64_value(
        header.get("number").ok_or_else(|| {
            contract_error(ContractErrorCode::Decode, "chain_getHeader 响应缺少 number")
        })?,
        "block number",
    )
}

async fn block_ref_from_status_hash(
    running: &RunningProvider,
    value: &Value,
    finality: BlockFinality,
    require_canonical: bool,
) -> ContractResult<VerifiedBlockRef> {
    let hash = parse_hash_value(value, "transaction status block hash")?;
    let number = block_number_by_hash(running, hash).await?;
    let block = match finality {
        BlockFinality::Best => VerifiedBlockRef::best(hash, number),
        BlockFinality::Finalized => VerifiedBlockRef::finalized(hash, number),
    };
    if require_canonical {
        validate_exact_block(running, block).await?;
    }
    Ok(block)
}

async fn parse_watch_event(
    running: &RunningProvider,
    status: &Value,
) -> ContractResult<(ExtrinsicWatchEvent, bool)> {
    if let Some(name) = status.as_str() {
        let event = match name {
            "ready" => ExtrinsicWatchEvent::Ready,
            "broadcast" => ExtrinsicWatchEvent::Broadcast { peer_count: 0 },
            "future" => ExtrinsicWatchEvent::Future,
            "dropped" => ExtrinsicWatchEvent::Dropped,
            "invalid" => ExtrinsicWatchEvent::Invalid,
            "finalityTimeout" => ExtrinsicWatchEvent::FinalityTimeout { block: None },
            _ => {
                return Err(contract_error(
                    ContractErrorCode::Decode,
                    format!("未知 extrinsic watch 状态: {name}"),
                ))
            }
        };
        let terminal = is_definitive_pool_failure(&event);
        return Ok((event, terminal));
    }
    let map = status.as_object().ok_or_else(|| {
        contract_error(
            ContractErrorCode::Decode,
            "extrinsic watch 状态既不是字符串也不是 object",
        )
    })?;
    if let Some(value) = map.get("broadcast") {
        let peer_count = value
            .as_array()
            .map(|peers| u32::try_from(peers.len()).unwrap_or(u32::MAX))
            .or_else(|| value.as_u64().and_then(|count| u32::try_from(count).ok()))
            .unwrap_or(0);
        return Ok((ExtrinsicWatchEvent::Broadcast { peer_count }, false));
    }
    if let Some(value) = map.get("inBlock") {
        let block = block_ref_from_status_hash(running, value, BlockFinality::Best, true).await?;
        return Ok((ExtrinsicWatchEvent::InBlock { block }, false));
    }
    if let Some(value) = map.get("finalized") {
        let block = block_ref_from_status_hash(running, value, BlockFinality::Finalized, true)
            .await?
            .require_finalized()?;
        return Ok((ExtrinsicWatchEvent::Finalized { block }, true));
    }
    if let Some(value) = map.get("retracted") {
        let block = block_ref_from_status_hash(running, value, BlockFinality::Best, false).await?;
        return Ok((ExtrinsicWatchEvent::Retracted { block }, false));
    }
    if let Some(value) = map.get("usurped") {
        let event = ExtrinsicWatchEvent::Usurped {
            replacement_hash: parse_hash_value(value, "replacement extrinsic hash")?,
        };
        return Ok((event, true));
    }
    if let Some(value) = map.get("finalityTimeout") {
        let block = if value.is_null() {
            None
        } else {
            Some(block_ref_from_status_hash(running, value, BlockFinality::Best, false).await?)
        };
        return Ok((ExtrinsicWatchEvent::FinalityTimeout { block }, false));
    }
    for (name, event, terminal) in [
        ("ready", ExtrinsicWatchEvent::Ready, false),
        ("future", ExtrinsicWatchEvent::Future, false),
        ("dropped", ExtrinsicWatchEvent::Dropped, false),
        ("invalid", ExtrinsicWatchEvent::Invalid, true),
    ] {
        if map.contains_key(name) {
            return Ok((event, terminal));
        }
    }
    Err(contract_error(
        ContractErrorCode::Decode,
        "未知 extrinsic watch object 状态",
    ))
}

/// 与既有 Dart 合同一致：只有 invalid/usurped 是交易池确定失败。
/// dropped、future、retracted 与 finalityTimeout 都不能据此断言链上失败。
fn is_definitive_pool_failure(event: &ExtrinsicWatchEvent) -> bool {
    matches!(
        event,
        ExtrinsicWatchEvent::Invalid | ExtrinsicWatchEvent::Usurped { .. }
    )
}

pub(crate) fn parse_hash_value(value: &Value, field: &str) -> ContractResult<Hash32> {
    let bytes = parse_hex_value(value, field)?;
    let bytes: [u8; 32] = bytes.try_into().map_err(|bytes: Vec<u8>| {
        contract_error(
            ContractErrorCode::Decode,
            format!("{field} 必须是 32 字节，实际为 {}", bytes.len()),
        )
    })?;
    Ok(Hash32::from_bytes(bytes))
}

fn parse_hex_value(value: &Value, field: &str) -> ContractResult<Vec<u8>> {
    let text = value.as_str().ok_or_else(|| {
        contract_error(
            ContractErrorCode::Decode,
            format!("{field} 不是 hex 字符串"),
        )
    })?;
    let encoded = text.strip_prefix("0x").ok_or_else(|| {
        contract_error(ContractErrorCode::Decode, format!("{field} 缺少 0x 前缀"))
    })?;
    if encoded.len() % 2 != 0 {
        return Err(contract_error(
            ContractErrorCode::Decode,
            format!("{field} hex 长度不是偶数"),
        ));
    }
    hex::decode(encoded).map_err(|error| {
        contract_error(
            ContractErrorCode::Decode,
            format!("{field} 不是有效 hex: {error}"),
        )
    })
}

fn parse_u32_field(value: &Value, field: &str) -> ContractResult<u32> {
    let value = value.get(field).ok_or_else(|| {
        contract_error(
            ContractErrorCode::Decode,
            format!("runtime version 缺少 {field}"),
        )
    })?;
    let value = parse_u64_value(value, field)?;
    u32::try_from(value)
        .map_err(|_| contract_error(ContractErrorCode::Decode, format!("{field} 超出 u32")))
}

fn parse_u64_value(value: &Value, field: &str) -> ContractResult<u64> {
    if let Some(number) = value.as_u64() {
        return Ok(number);
    }
    let text = value
        .as_str()
        .ok_or_else(|| contract_error(ContractErrorCode::Decode, format!("{field} 不是数字")))?;
    if let Some(hex) = text.strip_prefix("0x") {
        return u64::from_str_radix(hex, 16).map_err(|error| {
            contract_error(
                ContractErrorCode::Decode,
                format!("{field} 不是有效十六进制数字: {error}"),
            )
        });
    }
    text.parse::<u64>().map_err(|error| {
        contract_error(
            ContractErrorCode::Decode,
            format!("{field} 不是有效数字: {error}"),
        )
    })
}

fn hash_hex(hash: Hash32) -> String {
    format!("0x{}", hex::encode(hash.as_bytes()))
}

/// Substrate/CitizenChain 对完整 SCALE extrinsic（含其 Compact 长度前缀）使用的
/// Blake2b-256 身份。节点只报告接收结果；provider 必须独立计算后再接受返回 hash。
fn substrate_blake2_256(bytes: &[u8]) -> Hash32 {
    let digest = blake2_rfc::blake2b::blake2b(32, &[], bytes);
    let mut hash = [0_u8; 32];
    hash.copy_from_slice(digest.as_bytes());
    Hash32::from_bytes(hash)
}

fn verify_submitted_hash(
    extrinsic: &[u8],
    returned_hash: Hash32,
) -> ContractResult<SubmittedExtrinsic> {
    if returned_hash != substrate_blake2_256(extrinsic) {
        return Err(contract_error(
            ContractErrorCode::Integrity,
            "轻节点返回的 extrinsic hash 与完整已签名字节的本地 Blake2-256 不一致",
        ));
    }
    Ok(SubmittedExtrinsic::new(returned_hash))
}

#[cfg(test)]
mod tests {
    use super::*;
    use smoldot_light::ChainFinalizedBlockSnapshot;

    #[test]
    fn strict_hash_parser_rejects_wrong_width_and_prefix() {
        assert!(parse_hash_value(&json!(format!("0x{}", "11".repeat(32))), "hash").is_ok());
        assert!(parse_hash_value(&json!("11".repeat(32)), "hash").is_err());
        assert!(parse_hash_value(&json!(format!("0x{}", "11".repeat(31))), "hash").is_err());
    }

    #[test]
    fn number_parser_accepts_rpc_hex_and_json_numbers() {
        assert_eq!(parse_u64_value(&json!("0x2a"), "number").ok(), Some(42));
        assert_eq!(parse_u64_value(&json!(42), "number").ok(), Some(42));
    }

    #[test]
    fn current_storage_batch_routes_only_exact_matching_heads() {
        let best = VerifiedBlockRef::best(Hash32::from_bytes([0x11; 32]), 11);
        let finalized = FinalizedBlockRef::from_parts(Hash32::from_bytes([0x09; 32]), 9);
        let heads = StorageBatchHeads {
            best,
            surface_finalized: finalized,
            verified_finalized: finalized,
        };
        assert_eq!(
            select_storage_batch_route(best, heads),
            StorageBatchRoute::CurrentBest
        );
        assert_eq!(
            select_storage_batch_route(finalized.verified(), heads),
            StorageBatchRoute::CurrentVerifiedFinalized
        );

        let historical = VerifiedBlockRef::finalized(Hash32::from_bytes([0x08; 32]), 8);
        assert_eq!(
            select_storage_batch_route(historical, heads),
            StorageBatchRoute::ExactHash
        );

        let warp_surface = StorageBatchHeads {
            surface_finalized: FinalizedBlockRef::from_parts(Hash32::from_bytes([0x0a; 32]), 10),
            ..heads
        };
        assert_eq!(
            select_storage_batch_route(finalized.verified(), warp_surface),
            StorageBatchRoute::ExactHash
        );
    }

    #[test]
    fn historical_storage_params_always_carry_the_requested_exact_hash() {
        let block = VerifiedBlockRef::finalized(Hash32::from_bytes([0xab; 32]), 42);
        let params = exact_storage_params(block, vec![0x01, 0x02]);
        assert_eq!(params, json!(["0x0102", format!("0x{}", "ab".repeat(32))]));
        assert!(validate_storage_keys(&[vec![0x01], vec![0x01]]).is_ok());
        let Err(error) = validate_storage_keys(&[vec![0x01], Vec::new()]) else {
            panic!("empty key in a batch must fail before native dispatch");
        };
        assert_eq!(error.code(), ContractErrorCode::InvalidArgument);
        assert!(validate_storage_batch_len(2, 2).is_ok());
        let Err(error) = validate_storage_batch_len(2, 1) else {
            panic!("typed batch length mismatch must fail closed");
        };
        assert_eq!(error.code(), ContractErrorCode::Integrity);
    }

    #[test]
    fn typed_storage_snapshot_must_identify_the_exact_requested_block() {
        let requested = VerifiedBlockRef::best(Hash32::from_bytes([0x11; 32]), 11);
        let matching = ChainStorageValuesSnapshot {
            block_number: 11,
            block_hash: [0x11; 32],
            values: vec![Some(vec![1]), None, Some(vec![1])],
        };
        assert!(storage_snapshot_matches_block(&matching, requested));
        assert_eq!(matching.values[0], matching.values[2]);

        // Models the dangerous middle observation in an A→B→A head sequence:
        // even if outer head samples both see A, values proved against B are
        // rejected and the caller must fall back to an exact-hash query for A.
        let observed_middle_block = ChainStorageValuesSnapshot {
            block_number: 12,
            block_hash: [0x22; 32],
            values: vec![Some(vec![2]), None, Some(vec![2])],
        };
        assert!(!storage_snapshot_matches_block(
            &observed_middle_block,
            requested
        ));

        let wrong_number = ChainStorageValuesSnapshot {
            block_number: 12,
            block_hash: [0x11; 32],
            values: matching.values.clone(),
        };
        assert!(!storage_snapshot_matches_block(&wrong_number, requested));
    }

    #[test]
    fn submitted_hash_uses_complete_extrinsic_blake2_256() {
        let extrinsic = [0x04, 0x01, 0x02, 0x03];
        let actual = substrate_blake2_256(&extrinsic);
        assert_eq!(
            hex::encode(actual.as_bytes()),
            "d1db84052dee9bd43d7a1c22a4349bab845afcb162da4807166309d92d3dfa40"
        );
        assert!(verify_submitted_hash(&extrinsic, actual).is_ok());
        let Err(error) = verify_submitted_hash(&extrinsic[1..], actual) else {
            panic!("hash calculated without the Compact length prefix must fail");
        };
        assert_eq!(error.code(), ContractErrorCode::Integrity);
    }

    #[test]
    fn non_definitive_pool_statuses_do_not_end_the_watch() {
        assert!(!is_definitive_pool_failure(&ExtrinsicWatchEvent::Dropped));
        assert!(!is_definitive_pool_failure(
            &ExtrinsicWatchEvent::FinalityTimeout { block: None }
        ));
        assert!(is_definitive_pool_failure(&ExtrinsicWatchEvent::Invalid));
        assert!(is_definitive_pool_failure(&ExtrinsicWatchEvent::Usurped {
            replacement_hash: Hash32::from_bytes([7; 32]),
        }));
    }

    #[test]
    fn finalized_batch_projection_requires_exact_bounds_length_and_order() {
        let snapshot = ChainFinalizedBlocksSnapshot {
            upper_block_number: 42,
            upper_block_hash: [0xaa; 32],
            blocks: vec![
                ChainFinalizedBlockSnapshot {
                    block_number: 40,
                    block_hash: [0x40; 32],
                },
                ChainFinalizedBlockSnapshot {
                    block_number: 41,
                    block_hash: [0x41; 32],
                },
            ],
        };
        let refs = finalized_refs_from_snapshot(snapshot.clone(), 40, 41)
            .unwrap_or_else(|error| panic!("valid batch: {error}"));
        assert_eq!(refs.len(), 2);
        assert_eq!(refs[0].number(), 40);
        assert_eq!(refs[1].number(), 41);

        let mut partial = snapshot.clone();
        partial.blocks.pop();
        assert!(finalized_refs_from_snapshot(partial, 40, 41).is_err());

        let mut wrong_order = snapshot.clone();
        wrong_order.blocks.swap(0, 1);
        assert!(finalized_refs_from_snapshot(wrong_order, 40, 41).is_err());

        assert!(finalized_refs_from_snapshot(snapshot.clone(), 43, 42).is_err());
        assert!(finalized_refs_from_snapshot(snapshot, 41, 43).is_err());
    }

    #[test]
    fn ancestry_error_kinds_preserve_security_classification() {
        let cases = [
            (
                ChainFinalizedAncestryError::InvalidArgument("range".to_owned()),
                ContractErrorCode::InvalidArgument,
            ),
            (
                ChainFinalizedAncestryError::AboveVerifiedUpper("future".to_owned()),
                ContractErrorCode::NotFound,
            ),
            (
                ChainFinalizedAncestryError::Integrity("fork".to_owned()),
                ContractErrorCode::Integrity,
            ),
            (
                ChainFinalizedAncestryError::Unavailable("offline".to_owned()),
                ContractErrorCode::Network,
            ),
        ];
        for (source, expected) in cases {
            assert_eq!(finalized_ancestry_error(source).code(), expected);
        }
    }
}
