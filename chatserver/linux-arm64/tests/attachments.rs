use axum::body::Bytes;
use futures_util::stream;
use sha2::{Digest, Sha256};

use chatserver_linux::storage::objects::{ObjectError, ObjectStore};

#[tokio::test]
async fn encrypted_object_is_published_only_after_full_hash_match() {
    let directory = tempfile::tempdir().expect("tempdir");
    let store = ObjectStore::open(directory.path().to_path_buf())
        .await
        .expect("object store");
    let ciphertext = b"openmls-ciphertext";
    let digest = format!("{:x}", Sha256::digest(ciphertext));
    let chunks = stream::iter(vec![Ok::<Bytes, std::io::Error>(Bytes::copy_from_slice(
        ciphertext,
    ))]);
    store
        .put_stream(
            "attachment-good",
            0,
            ciphertext.len() as u64,
            &digest,
            1024,
            chunks,
        )
        .await
        .expect("atomic upload");
    let (_, size) = store.open_file("attachment-good", 0).await.expect("object");
    assert_eq!(size, ciphertext.len() as u64);
}

#[tokio::test]
async fn hash_mismatch_leaves_no_public_object() {
    let directory = tempfile::tempdir().expect("tempdir");
    let store = ObjectStore::open(directory.path().to_path_buf())
        .await
        .expect("object store");
    let chunks = stream::iter(vec![Ok::<Bytes, std::io::Error>(Bytes::from_static(
        b"cipher",
    ))]);
    let result = store
        .put_stream("attachment-bad", 0, 6, &"0".repeat(64), 1024, chunks)
        .await;
    assert!(matches!(result, Err(ObjectError::IntegrityMismatch)));
    assert!(matches!(
        store.open_file("attachment-bad", 0).await,
        Err(ObjectError::NotFound)
    ));
}

#[tokio::test]
async fn different_chunk_indexes_never_overwrite_each_other() {
    let directory = tempfile::tempdir().expect("tempdir");
    let store = ObjectStore::open(directory.path().to_path_buf())
        .await
        .expect("object store");
    for (chunk_index, ciphertext) in [(0_u32, b"first".as_slice()), (1_u32, b"second".as_slice())] {
        let digest = format!("{:x}", Sha256::digest(ciphertext));
        store
            .put_stream(
                "attachment-many",
                chunk_index,
                ciphertext.len() as u64,
                &digest,
                1024,
                stream::iter(vec![Ok::<Bytes, std::io::Error>(Bytes::copy_from_slice(
                    ciphertext,
                ))]),
            )
            .await
            .expect("chunk upload");
    }
    assert_eq!(
        store
            .open_file("attachment-many", 0)
            .await
            .expect("chunk 0")
            .1,
        5
    );
    assert_eq!(
        store
            .open_file("attachment-many", 1)
            .await
            .expect("chunk 1")
            .1,
        6
    );
    store
        .remove("attachment-many")
        .await
        .expect("remove chunks");
    assert!(matches!(
        store.open_file("attachment-many", 0).await,
        Err(ObjectError::NotFound)
    ));
    assert!(matches!(
        store.open_file("attachment-many", 1).await,
        Err(ObjectError::NotFound)
    ));
}
