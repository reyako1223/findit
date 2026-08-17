use std::sync::{Mutex, MutexGuard};

pub mod findit;
pub mod models;

static STORE_LOCK: Mutex<()> = Mutex::new(());

pub(crate) fn lock_store() -> Result<MutexGuard<'static, ()>, String> {
    STORE_LOCK
        .lock()
        .map_err(|_| "The FindIt data store is temporarily unavailable.".to_string())
}
