use std::sync::{Mutex, MutexGuard};

use chrono::{TimeZone, Utc};
use tauri::State;

use crate::{
    matcher,
    models::{
        ItemReport, ItemStatus, MatchResult, NewReportInput, ReportQuery, ReportType, Statistics,
        UpdateReportInput,
    },
    storage::JsonStorage,
};

pub(crate) struct AppState {
    storage: JsonStorage,
    reports: Mutex<Vec<ItemReport>>,
}

impl AppState {
    pub(crate) fn new(storage: JsonStorage, reports: Vec<ItemReport>) -> Self {
        Self {
            storage,
            reports: Mutex::new(reports),
        }
    }

    fn lock(&self) -> Result<MutexGuard<'_, Vec<ItemReport>>, String> {
        self.reports
            .lock()
            .map_err(|_| "The report store is temporarily unavailable.".to_string())
    }

    fn persist(&self, reports: &[ItemReport]) -> Result<(), String> {
        self.storage.save_reports(reports)
    }
}

#[tauri::command]
pub(crate) fn add_report(
    state: State<'_, AppState>,
    input: NewReportInput,
) -> Result<ItemReport, String> {
    let input = input.validate_and_clean()?;
    let mut reports = state.lock()?;
    let id = next_id(&reports, input.report_type);
    let report = ItemReport {
        id,
        item_name: input.item_name,
        category: input.category,
        color: input.color,
        location: input.location,
        date: input.date,
        description: input.description,
        contact_information: input.contact_information,
        report_type: input.report_type,
        status: ItemStatus::from_report_type(input.report_type),
        created_at: Utc::now(),
    };

    reports.push(report.clone());
    if let Err(error) = state.persist(&reports) {
        reports.pop();
        return Err(error);
    }
    Ok(report)
}

#[tauri::command]
pub(crate) fn update_report(
    state: State<'_, AppState>,
    id: String,
    input: UpdateReportInput,
) -> Result<ItemReport, String> {
    let input = input.validate_and_clean()?;
    let mut reports = state.lock()?;
    let index = reports
        .iter()
        .position(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))?;
    let previous = reports[index].clone();

    {
        let report = &mut reports[index];
        report.item_name = input.item_name;
        report.category = input.category;
        report.color = input.color;
        report.location = input.location;
        report.date = input.date;
        report.description = input.description;
        report.contact_information = input.contact_information;
    }

    if let Err(error) = state.persist(&reports) {
        reports[index] = previous;
        return Err(error);
    }
    Ok(reports[index].clone())
}

#[tauri::command]
pub(crate) fn delete_report(state: State<'_, AppState>, id: String) -> Result<(), String> {
    let mut reports = state.lock()?;
    let index = reports
        .iter()
        .position(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))?;
    let removed = reports.remove(index);

    if let Err(error) = state.persist(&reports) {
        reports.insert(index, removed);
        return Err(error);
    }
    Ok(())
}

#[tauri::command]
pub(crate) fn get_report(state: State<'_, AppState>, id: String) -> Result<ItemReport, String> {
    state
        .lock()?
        .iter()
        .find(|report| report.id == id)
        .cloned()
        .ok_or_else(|| format!("Report {id} was not found."))
}

#[tauri::command]
pub(crate) fn get_reports(
    state: State<'_, AppState>,
    query: Option<ReportQuery>,
) -> Result<Vec<ItemReport>, String> {
    let reports = state.lock()?;
    let query = query.unwrap_or_default();
    let search = query.search.unwrap_or_default().trim().to_lowercase();

    let mut filtered: Vec<ItemReport> = reports
        .iter()
        .filter(|report| query.status.is_none_or(|status| report.status == status))
        .filter(|report| {
            search.is_empty()
                || [
                    &report.item_name,
                    &report.location,
                    &report.color,
                    &report.category,
                ]
                .iter()
                .any(|field| field.to_lowercase().contains(&search))
        })
        .cloned()
        .collect();
    filtered.sort_by_key(|report| std::cmp::Reverse(report.created_at));
    Ok(filtered)
}

#[tauri::command]
pub(crate) fn get_statistics(state: State<'_, AppState>) -> Result<Statistics, String> {
    let reports = state.lock()?;
    Ok(reports.iter().fold(
        Statistics {
            total: reports.len(),
            ..Statistics::default()
        },
        |mut statistics, report| {
            match report.status {
                ItemStatus::Lost => statistics.lost += 1,
                ItemStatus::Found => statistics.found += 1,
                ItemStatus::Returned => statistics.returned += 1,
            }
            statistics
        },
    ))
}

#[tauri::command]
pub(crate) fn find_matches(
    state: State<'_, AppState>,
    report_id: Option<String>,
) -> Result<Vec<MatchResult>, String> {
    let reports = state.lock()?;
    Ok(matcher::find_matches(&reports, report_id.as_deref()))
}

#[tauri::command]
pub(crate) fn mark_as_returned(
    state: State<'_, AppState>,
    lost_id: String,
    found_id: String,
) -> Result<(), String> {
    if lost_id == found_id {
        return Err("A report cannot be matched with itself.".into());
    }

    let mut reports = state.lock()?;
    let lost_index = reports
        .iter()
        .position(|report| report.id == lost_id && report.report_type == ReportType::Lost)
        .ok_or_else(|| "The lost report was not found.".to_string())?;
    let found_index = reports
        .iter()
        .position(|report| report.id == found_id && report.report_type == ReportType::Found)
        .ok_or_else(|| "The found report was not found.".to_string())?;

    if reports[lost_index].status != ItemStatus::Lost
        || reports[found_index].status != ItemStatus::Found
    {
        return Err("Only active lost and found reports can be returned.".into());
    }

    reports[lost_index].status = ItemStatus::Returned;
    reports[found_index].status = ItemStatus::Returned;
    if let Err(error) = state.persist(&reports) {
        reports[lost_index].status = ItemStatus::Lost;
        reports[found_index].status = ItemStatus::Found;
        return Err(error);
    }
    Ok(())
}

#[tauri::command]
pub(crate) fn is_development() -> bool {
    cfg!(debug_assertions)
}

#[tauri::command]
pub(crate) fn seed_sample_data(state: State<'_, AppState>) -> Result<Vec<ItemReport>, String> {
    if !cfg!(debug_assertions) {
        return Err("Sample data is available in development builds only.".into());
    }

    let mut reports = state.lock()?;
    if reports.iter().any(|report| report.id.starts_with("DEMO-")) {
        return Ok(reports
            .iter()
            .filter(|report| report.id.starts_with("DEMO-"))
            .cloned()
            .collect());
    }

    let created_at = Utc
        .with_ymd_and_hms(2026, 8, 10, 8, 0, 0)
        .single()
        .ok_or_else(|| "Could not create the sample timestamp.".to_string())?;
    let samples = vec![
        ItemReport {
            id: "DEMO-LST-0001".into(),
            item_name: "Wallet".into(),
            category: "Wallet".into(),
            color: "Black".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: "Black leather wallet with a small scratch on the front.".into(),
            contact_information: None,
            report_type: ReportType::Lost,
            status: ItemStatus::Lost,
            created_at,
        },
        ItemReport {
            id: "DEMO-FND-0001".into(),
            item_name: "Wallet".into(),
            category: "Wallet".into(),
            color: "Black".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: "Black leather wallet with a scratch on the front.".into(),
            contact_information: Some("Student Services desk".into()),
            report_type: ReportType::Found,
            status: ItemStatus::Found,
            created_at: created_at + chrono::Duration::minutes(15),
        },
        ItemReport {
            id: "DEMO-LST-0002".into(),
            item_name: "USB Flash Drive".into(),
            category: "Electronics".into(),
            color: "Black".into(),
            location: "Computer Laboratory".into(),
            date: "2026-08-09".into(),
            description: "Small 32GB drive with a red cap.".into(),
            contact_information: None,
            report_type: ReportType::Lost,
            status: ItemStatus::Lost,
            created_at: created_at - chrono::Duration::hours(2),
        },
    ];

    reports.extend(samples.clone());
    if let Err(error) = state.persist(&reports) {
        let sample_ids: Vec<&str> = samples.iter().map(|sample| sample.id.as_str()).collect();
        reports.retain(|report| !sample_ids.contains(&report.id.as_str()));
        return Err(error);
    }
    Ok(samples)
}

fn next_id(reports: &[ItemReport], report_type: ReportType) -> String {
    let prefix = match report_type {
        ReportType::Lost => "LST-",
        ReportType::Found => "FND-",
    };
    let next_number = reports
        .iter()
        .filter_map(|report| report.id.strip_prefix(prefix))
        .filter_map(|number| number.parse::<u32>().ok())
        .max()
        .unwrap_or(0)
        + 1;
    format!("{prefix}{next_number:04}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_are_sequential_for_each_report_type() {
        let reports = vec![ItemReport {
            id: "LST-0008".into(),
            item_name: "Wallet".into(),
            category: "Wallet".into(),
            color: "Black".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: String::new(),
            contact_information: None,
            report_type: ReportType::Lost,
            status: ItemStatus::Lost,
            created_at: Utc::now(),
        }];

        assert_eq!(next_id(&reports, ReportType::Lost), "LST-0009");
        assert_eq!(next_id(&reports, ReportType::Found), "FND-0001");
    }
}
