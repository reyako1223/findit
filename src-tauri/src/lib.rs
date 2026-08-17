mod commands;
mod matcher;
mod models;
mod storage;

use std::io;

use tauri::Manager;

use crate::{commands::AppState, storage::JsonStorage};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            // Tauri resolves the correct private app-data folder on every platform.
            let data_dir = app.path().app_data_dir()?;
            let storage = JsonStorage::new(data_dir.join("reports.json"));
            let reports = storage.load_reports().map_err(io::Error::other)?;
            app.manage(AppState::new(storage, reports));
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::add_report,
            commands::update_report,
            commands::delete_report,
            commands::get_report,
            commands::get_reports,
            commands::get_statistics,
            commands::find_matches,
            commands::mark_as_returned,
            commands::seed_sample_data,
            commands::is_development
        ])
        .run(tauri::generate_context!())
        .expect("FindIt could not start");
}
