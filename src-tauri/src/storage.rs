use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::models::ItemReport;

#[derive(Debug)]
pub struct JsonStorage {
    path: PathBuf,
}

impl JsonStorage {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load_reports(&self) -> Result<Vec<ItemReport>, String> {
        load_reports(&self.path)
    }

    pub fn save_reports(&self, reports: &[ItemReport]) -> Result<(), String> {
        save_reports(&self.path, reports)
    }
}

/// Loads persisted records; a missing file is a valid first-run state.
pub fn load_reports(path: &Path) -> Result<Vec<ItemReport>, String> {
    if !path.exists() {
        return Ok(Vec::new());
    }

    let contents = fs::read_to_string(path)
        .map_err(|error| format!("Could not read saved reports: {error}"))?;
    if contents.trim().is_empty() {
        return Ok(Vec::new());
    }
    serde_json::from_str(&contents)
        .map_err(|error| format!("The saved report file is not valid JSON: {error}"))
}

/// Serializes the complete Vec so disk and in-memory state stay in sync.
pub fn save_reports(path: &Path, reports: &[ItemReport]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not create the app data folder: {error}"))?;
    }
    let json = serde_json::to_string_pretty(reports)
        .map_err(|error| format!("Could not serialize reports: {error}"))?;
    fs::write(path, json).map_err(|error| format!("Could not save reports: {error}"))
}

#[cfg(test)]
mod tests {
    use chrono::Utc;
    use tempfile::tempdir;

    use super::*;
    use crate::models::{ItemStatus, ReportType};

    fn report() -> ItemReport {
        ItemReport {
            id: "LST-0001".into(),
            item_name: "Wallet".into(),
            category: "Wallet".into(),
            color: "Black".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: "Leather wallet".into(),
            contact_information: None,
            report_type: ReportType::Lost,
            status: ItemStatus::Lost,
            created_at: Utc::now(),
        }
    }

    #[test]
    fn saves_and_reloads_reports() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("nested").join("reports.json");
        let expected = vec![report()];

        save_reports(&path, &expected).unwrap();
        let actual = load_reports(&path).unwrap();

        assert_eq!(actual, expected);
    }

    #[test]
    fn missing_file_returns_empty_collection() {
        let directory = tempdir().unwrap();
        assert!(
            load_reports(&directory.path().join("missing.json"))
                .unwrap()
                .is_empty()
        );
    }
}
