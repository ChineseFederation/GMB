use citizen_sdk_contracts::{CapabilityName, CapabilityReason};
use citizen_sdk_engine::{CapabilityProbe, resolve_capabilities};

fn all_ready() -> Vec<CapabilityProbe> {
    CapabilityName::ALL
        .into_iter()
        .map(CapabilityProbe::ready)
        .collect()
}

fn probe_mut(probes: &mut [CapabilityProbe], name: CapabilityName) -> &mut CapabilityProbe {
    match probes.iter_mut().find(|probe| probe.name == name) {
        Some(probe) => probe,
        None => panic!("missing probe: {}", name.as_str()),
    }
}

#[test]
fn chain_read_failure_closes_chain_dependent_capabilities() {
    let mut probes = all_ready();
    let chain = probe_mut(&mut probes, CapabilityName::ChainRead);
    chain.runtime_ready = false;
    chain.not_ready_reason = Some(CapabilityReason::ChainUnsynced);

    let snapshot = match resolve_capabilities(7, probes) {
        Ok(snapshot) => snapshot,
        Err(error) => panic!("capability resolution failed: {error}"),
    };
    assert_eq!(snapshot.revision(), 7);
    assert_eq!(snapshot.statuses().len(), 10);
    assert_eq!(
        snapshot
            .status(CapabilityName::ChainRead)
            .and_then(|status| status.reason()),
        Some(CapabilityReason::ChainUnsynced)
    );
    for dependent in [
        CapabilityName::TransactionBuild,
        CapabilityName::TransactionSubmit,
        CapabilityName::TransactionVerify,
        CapabilityName::History,
        CapabilityName::BackgroundSync,
    ] {
        let status = match snapshot.status(dependent) {
            Some(status) => status,
            None => panic!("missing status: {}", dependent.as_str()),
        };
        assert!(!status.is_ready());
        assert_eq!(status.reason(), Some(CapabilityReason::DependencyNotReady));
    }
    assert!(snapshot
        .status(CapabilityName::WalletProfile)
        .is_some_and(|status| status.is_ready()));
}

#[test]
fn submit_and_signing_do_not_invent_unrelated_dependencies() {
    let mut probes = all_ready();
    probe_mut(&mut probes, CapabilityName::TransactionBuild).enabled = false;
    probe_mut(&mut probes, CapabilityName::HardwareVault).supported = false;
    probe_mut(&mut probes, CapabilityName::UserAuthentication).supported = false;

    let snapshot = match resolve_capabilities(8, probes) {
        Ok(snapshot) => snapshot,
        Err(error) => panic!("capability resolution failed: {error}"),
    };
    assert!(snapshot
        .status(CapabilityName::TransactionSubmit)
        .is_some_and(|status| status.is_ready()));
    assert!(snapshot
        .status(CapabilityName::LocalSigning)
        .is_some_and(|status| status.is_ready()));
    assert!(!snapshot
        .status(CapabilityName::HardwareVault)
        .is_some_and(|status| status.is_ready()));
}

#[test]
fn duplicate_or_missing_probes_fail_closed() {
    let mut probes = all_ready();
    let _ = probes.pop();
    assert!(resolve_capabilities(1, probes).is_err());

    let mut duplicate = all_ready();
    duplicate[9].name = CapabilityName::ChainRead;
    assert!(resolve_capabilities(2, duplicate).is_err());
}

