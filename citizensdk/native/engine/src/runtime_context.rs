use citizen_sdk_contracts::{BlockFinality, RuntimeContext, VerifiedBlockRef};

use crate::error::EngineError;

/// Opaque request identity used to keep late in-flight completions from
/// replacing a newer best-head runtime context.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RuntimeContextRequest {
    block: VerifiedBlockRef,
    sequence: u64,
}

impl RuntimeContextRequest {
    pub const fn block(self) -> VerifiedBlockRef {
        self.block
    }
}

/// Exact-block runtime cache. Entries are immutable for their verified block;
/// `current_best` is advanced only by the latest request identity.
#[derive(Debug, Default)]
pub struct RuntimeContextCache {
    next_sequence: u64,
    latest_best_request: Option<u64>,
    current_best: Option<VerifiedBlockRef>,
    contexts: Vec<RuntimeContext>,
}

impl RuntimeContextCache {
    pub const fn new() -> Self {
        Self {
            next_sequence: 0,
            latest_best_request: None,
            current_best: None,
            contexts: Vec::new(),
        }
    }

    pub fn begin(&mut self, block: VerifiedBlockRef) -> RuntimeContextRequest {
        let sequence = self.next_sequence;
        self.next_sequence = self.next_sequence.saturating_add(1);
        if block.finality() == BlockFinality::Best {
            self.latest_best_request = Some(sequence);
        }
        RuntimeContextRequest { block, sequence }
    }

    pub fn complete(
        &mut self,
        request: RuntimeContextRequest,
        context: RuntimeContext,
    ) -> Result<RuntimeContext, EngineError> {
        // A block's metadata is immutable when the same hash/height advances
        // from best to finalized. Rebind only that verified finality marker;
        // any hash or height difference remains a hard context error.
        let context = if context.block() == request.block {
            context
        } else if context.block().hash() == request.block.hash()
            && context.block().number() == request.block.number()
        {
            RuntimeContext::try_new(
                request.block,
                context.version(),
                context.metadata().to_vec(),
            )
            .map_err(|error| EngineError::Contract(error.to_string()))?
        } else {
            return Err(EngineError::BlockContextMismatch(
                "runtime context does not match its request block".to_owned(),
            ));
        };
        if self.contexts.iter().any(|existing| {
            existing.block().hash() == context.block().hash()
                && existing.block().number() != context.block().number()
        }) {
            return Err(EngineError::BlockContextMismatch(
                "one block hash was associated with multiple heights".to_owned(),
            ));
        }
        if self.contexts.iter().any(|existing| {
            existing.block().hash() == context.block().hash()
                && existing.block().number() == context.block().number()
                && (existing.version() != context.version()
                    || existing.metadata() != context.metadata())
        }) {
            return Err(EngineError::BlockContextMismatch(
                "runtime context changed while one block advanced finality".to_owned(),
            ));
        }
        if let Some(existing) = self
            .contexts
            .iter()
            .find(|existing| existing.block() == context.block())
        {
            if existing != &context {
                return Err(EngineError::BlockContextMismatch(
                    "runtime context changed for an immutable block".to_owned(),
                ));
            }
        } else {
            self.contexts.push(context.clone());
        }

        if request.block.finality() == BlockFinality::Best
            && self.latest_best_request == Some(request.sequence)
        {
            self.current_best = Some(request.block);
        }
        Ok(context)
    }

    pub fn get(&self, block: VerifiedBlockRef) -> Option<&RuntimeContext> {
        self.contexts
            .iter()
            .find(|context| context.block() == block)
    }

    pub fn current_best(&self) -> Option<&RuntimeContext> {
        let block = self.current_best?;
        self.get(block)
    }
}
