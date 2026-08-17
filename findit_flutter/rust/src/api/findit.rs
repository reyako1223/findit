use std::{
    collections::HashSet,
    fs,
    path::{Path, PathBuf},
};

use chrono::{NaiveDate, Utc};

use super::{
    lock_store,
    models::{
        ItemReport, ItemStatus, MatchReason, MatchResult, NewReportInput, ReportType, Statistics,
        UpdateReportInput,
    },
};

const MINIMUM_MATCH_SCORE: u8 = 60;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Removes data left by the retired audit-ledger experiment from older builds.
pub fn cleanup_legacy_data(storage_dir: String) -> Result<bool, String> {
    let _guard = lock_store()?;
    let path = PathBuf::from(storage_dir.trim()).join("blockchain.json");
    if !path.exists() {
        return Ok(false);
    }
    fs::remove_file(path).map_err(|error| format!("Could not remove old app data: {error}"))?;
    Ok(true)
}

pub fn add_report(storage_dir: String, input: NewReportInput) -> Result<ItemReport, String> {
    let _guard = lock_store()?;
    let input = validate_new(input)?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
    let report = ItemReport {
        id: next_id(&reports, input.report_type),
        item_name: input.item_name,
        category: input.category,
        color: input.color,
        location: input.location,
        date: input.date,
        description: input.description,
        contact_information: input.contact_information,
        report_type: input.report_type,
        status: ItemStatus::from_report_type(input.report_type),
        created_at: Utc::now().to_rfc3339(),
    };
    reports.push(report.clone());
    save_reports(&path, &reports)?;
    Ok(report)
}

pub fn update_report(
    storage_dir: String,
    id: String,
    input: UpdateReportInput,
) -> Result<ItemReport, String> {
    let _guard = lock_store()?;
    let input = validate_update(input)?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
    let report = reports
        .iter_mut()
        .find(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))?;

    report.item_name = input.item_name;
    report.category = input.category;
    report.color = input.color;
    report.location = input.location;
    report.date = input.date;
    report.description = input.description;
    report.contact_information = input.contact_information;
    let updated = report.clone();
    save_reports(&path, &reports)?;
    Ok(updated)
}

pub fn delete_report(storage_dir: String, id: String) -> Result<(), String> {
    let _guard = lock_store()?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
    let index = reports
        .iter()
        .position(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))?;
    reports.remove(index);
    save_reports(&path, &reports)
}

pub fn get_report(storage_dir: String, id: String) -> Result<ItemReport, String> {
    let _guard = lock_store()?;
    let reports = load_reports(&reports_path(&storage_dir)?)?;
    reports
        .into_iter()
        .find(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))
}

pub fn get_reports(
    storage_dir: String,
    search: Option<String>,
    status: Option<ItemStatus>,
) -> Result<Vec<ItemReport>, String> {
    let _guard = lock_store()?;
    let reports = load_reports(&reports_path(&storage_dir)?)?;
    let search = search.unwrap_or_default().trim().to_lowercase();
    let mut filtered: Vec<ItemReport> = reports
        .into_iter()
        .filter(|report| status.is_none_or(|value| report.status == value))
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
        .collect();
    filtered.sort_by(|left, right| right.created_at.cmp(&left.created_at));
    Ok(filtered)
}

pub fn get_statistics(storage_dir: String) -> Result<Statistics, String> {
    let _guard = lock_store()?;
    let reports = load_reports(&reports_path(&storage_dir)?)?;
    Ok(calculate_statistics(&reports))
}

pub fn find_matches(
    storage_dir: String,
    report_id: Option<String>,
) -> Result<Vec<MatchResult>, String> {
    let _guard = lock_store()?;
    let reports = load_reports(&reports_path(&storage_dir)?)?;
    Ok(matches_for(&reports, report_id.as_deref()))
}

pub fn mark_as_returned(
    storage_dir: String,
    lost_id: String,
    found_id: String,
) -> Result<(), String> {
    if lost_id == found_id {
        return Err("A report cannot be matched with itself.".into());
    }

    let _guard = lock_store()?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
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
    save_reports(&path, &reports)
}

pub fn mark_report_as_returned(storage_dir: String, id: String) -> Result<ItemReport, String> {
    let _guard = lock_store()?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
    let report = reports
        .iter_mut()
        .find(|report| report.id == id)
        .ok_or_else(|| format!("Report {id} was not found."))?;

    report.status = ItemStatus::Returned;
    let updated = report.clone();
    save_reports(&path, &reports)?;
    Ok(updated)
}

pub fn is_development() -> bool {
    cfg!(debug_assertions)
}

pub fn seed_sample_data(storage_dir: String) -> Result<Vec<ItemReport>, String> {
    if !cfg!(debug_assertions) {
        return Err("Sample data is available in development builds only.".into());
    }

    let _guard = lock_store()?;
    let path = reports_path(&storage_dir)?;
    let mut reports = load_reports(&path)?;
    if reports.iter().any(|report| report.id.starts_with("DEMO-")) {
        return Ok(reports
            .into_iter()
            .filter(|report| report.id.starts_with("DEMO-"))
            .collect());
    }

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
            created_at: "2026-08-10T08:00:00Z".into(),
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
            created_at: "2026-08-10T08:15:00Z".into(),
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
            created_at: "2026-08-10T06:00:00Z".into(),
        },
    ];
    reports.extend(samples.clone());
    save_reports(&path, &reports)?;
    Ok(samples)
}

fn reports_path(storage_dir: &str) -> Result<PathBuf, String> {
    let storage_dir = storage_dir.trim();
    if storage_dir.is_empty() {
        return Err("The application storage directory is missing.".into());
    }
    Ok(PathBuf::from(storage_dir).join("reports.json"))
}

fn load_reports(path: &Path) -> Result<Vec<ItemReport>, String> {
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

fn save_reports(path: &Path, reports: &[ItemReport]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not create the app data folder: {error}"))?;
    }
    let json = serde_json::to_string_pretty(reports)
        .map_err(|error| format!("Could not serialize reports: {error}"))?;
    fs::write(path, json).map_err(|error| format!("Could not save reports: {error}"))
}

fn validate_new(input: NewReportInput) -> Result<NewReportInput, String> {
    Ok(NewReportInput {
        item_name: clean_required("Item name", input.item_name)?,
        category: clean_required("Category", input.category)?,
        color: clean_required("Color", input.color)?,
        location: clean_required("Location", input.location)?,
        date: validate_date(input.date)?,
        description: clean_optional(input.description, 1_000, "Description")?,
        contact_information: clean_contact(input.contact_information)?,
        report_type: input.report_type,
    })
}

fn validate_update(input: UpdateReportInput) -> Result<UpdateReportInput, String> {
    Ok(UpdateReportInput {
        item_name: clean_required("Item name", input.item_name)?,
        category: clean_required("Category", input.category)?,
        color: clean_required("Color", input.color)?,
        location: clean_required("Location", input.location)?,
        date: validate_date(input.date)?,
        description: clean_optional(input.description, 1_000, "Description")?,
        contact_information: clean_contact(input.contact_information)?,
    })
}

fn clean_required(field: &str, value: String) -> Result<String, String> {
    let value = value.trim().to_string();
    if value.is_empty() {
        return Err(format!("{field} is required."));
    }
    if value.chars().count() > 120 {
        return Err(format!("{field} must be 120 characters or fewer."));
    }
    Ok(value)
}

fn clean_optional(value: String, limit: usize, field: &str) -> Result<String, String> {
    let value = value.trim().to_string();
    if value.chars().count() > limit {
        return Err(format!("{field} must be {limit} characters or fewer."));
    }
    Ok(value)
}

fn clean_contact(value: Option<String>) -> Result<Option<String>, String> {
    value
        .map(|text| clean_optional(text, 200, "Contact information"))
        .transpose()
        .map(|value| value.filter(|text| !text.is_empty()))
}

fn validate_date(value: String) -> Result<String, String> {
    let value = value.trim().to_string();
    NaiveDate::parse_from_str(&value, "%Y-%m-%d")
        .map(|_| value)
        .map_err(|_| "Date must be a valid date in YYYY-MM-DD format.".to_string())
}

fn next_id(reports: &[ItemReport], report_type: ReportType) -> String {
    let prefix = match report_type {
        ReportType::Lost => "LST-",
        ReportType::Found => "FND-",
    };
    let number = reports
        .iter()
        .filter_map(|report| report.id.strip_prefix(prefix))
        .filter_map(|value| value.parse::<u32>().ok())
        .max()
        .unwrap_or(0)
        + 1;
    format!("{prefix}{number:04}")
}

fn calculate_statistics(reports: &[ItemReport]) -> Statistics {
    reports.iter().fold(
        Statistics {
            total: reports.len() as u32,
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
    )
}

fn matches_for(reports: &[ItemReport], report_id: Option<&str>) -> Vec<MatchResult> {
    let lost_reports = reports
        .iter()
        .filter(|report| report.status == ItemStatus::Lost);
    let found_reports: Vec<&ItemReport> = reports
        .iter()
        .filter(|report| report.status == ItemStatus::Found)
        .collect();

    let mut matches: Vec<MatchResult> = lost_reports
        .flat_map(|lost| {
            found_reports.iter().filter_map(move |found| {
                if report_id.is_some_and(|id| lost.id != id && found.id != id) {
                    return None;
                }
                let result = score_pair(lost, found);
                (result.score >= MINIMUM_MATCH_SCORE).then_some(result)
            })
        })
        .collect();
    matches.sort_by_key(|result| std::cmp::Reverse(result.score));
    matches
}

fn score_pair(lost: &ItemReport, found: &ItemReport) -> MatchResult {
    let checks = [
        (
            "Item name matches",
            same(&lost.item_name, &found.item_name),
            35,
        ),
        (
            "Category matches",
            same(&lost.category, &found.category),
            20,
        ),
        ("Color matches", same(&lost.color, &found.color), 15),
        (
            "Location matches",
            same(&lost.location, &found.location),
            20,
        ),
    ];
    let mut reasons: Vec<MatchReason> = checks
        .into_iter()
        .map(|(label, matched, points)| MatchReason {
            label: label.into(),
            points: if matched { points } else { 0 },
            max_points: points,
            matched,
        })
        .collect();
    let similarity = keyword_similarity(&lost.description, &found.description);
    let description_points = (similarity * 10.0).round() as u8;
    reasons.push(MatchReason {
        label: match description_points {
            10 => "Description keywords match",
            1..=9 => "Description partially matches",
            _ => "Description does not match",
        }
        .into(),
        points: description_points,
        max_points: 10,
        matched: description_points > 0,
    });
    let score = reasons.iter().map(|reason| reason.points).sum();
    MatchResult {
        lost_report: lost.clone(),
        found_report: found.clone(),
        score,
        quality: match score {
            90..=100 => "Excellent Match",
            75..=89 => "Strong Match",
            _ => "Possible Match",
        }
        .into(),
        reasons,
    }
}

fn same(left: &str, right: &str) -> bool {
    normalize(left) == normalize(right)
}

fn normalize(value: &str) -> String {
    value
        .trim()
        .to_lowercase()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn keyword_similarity(left: &str, right: &str) -> f32 {
    let left = keywords(left);
    let right = keywords(right);
    if left.is_empty() || right.is_empty() {
        return 0.0;
    }
    left.intersection(&right).count() as f32 / left.union(&right).count() as f32
}

fn keywords(value: &str) -> HashSet<String> {
    const STOP_WORDS: [&str; 12] = [
        "a", "an", "and", "at", "in", "is", "of", "on", "the", "to", "was", "with",
    ];
    value
        .to_lowercase()
        .split(|character: char| !character.is_alphanumeric())
        .filter(|word| word.len() > 1 && !STOP_WORDS.contains(word))
        .map(str::to_string)
        .collect()
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    fn new_input(report_type: ReportType) -> NewReportInput {
        NewReportInput {
            item_name: " Wallet ".into(),
            category: "Wallet".into(),
            color: "BLACK".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: "Black leather wallet with a scratch".into(),
            contact_information: None,
            report_type,
        }
    }

    #[test]
    fn full_demo_flow_persists_matches_and_returned_counts() {
        let directory = tempdir().unwrap();
        let path = directory.path().to_string_lossy().to_string();
        let lost = add_report(path.clone(), new_input(ReportType::Lost)).unwrap();
        let found = add_report(path.clone(), new_input(ReportType::Found)).unwrap();

        let matches = find_matches(path.clone(), None).unwrap();
        assert_eq!(matches.len(), 1);
        assert_eq!(matches[0].score, 100);

        mark_as_returned(path.clone(), lost.id, found.id).unwrap();
        let statistics = get_statistics(path.clone()).unwrap();
        assert_eq!(statistics.returned, 2);
        assert!(find_matches(path, None).unwrap().is_empty());
    }

    #[test]
    fn update_search_delete_and_reload_work() {
        let directory = tempdir().unwrap();
        let path = directory.path().to_string_lossy().to_string();
        let report = add_report(path.clone(), new_input(ReportType::Lost)).unwrap();
        let updated = update_report(
            path.clone(),
            report.id.clone(),
            UpdateReportInput {
                item_name: "Canvas Bag".into(),
                category: "Bag".into(),
                color: "Green".into(),
                location: "Cafeteria".into(),
                date: "2026-08-09".into(),
                description: "Green shoulder bag".into(),
                contact_information: Some("Room 10".into()),
            },
        )
        .unwrap();
        assert_eq!(updated.item_name, "Canvas Bag");
        assert_eq!(
            get_reports(path.clone(), Some("green".into()), None)
                .unwrap()
                .len(),
            1
        );
        delete_report(path.clone(), report.id).unwrap();
        assert!(get_reports(path, None, None).unwrap().is_empty());
    }

    #[test]
    fn rejects_invalid_required_fields() {
        let mut input = new_input(ReportType::Lost);
        input.item_name = "  ".into();
        assert_eq!(validate_new(input).unwrap_err(), "Item name is required.");
    }

    #[test]
    fn individual_report_can_be_marked_as_returned() {
        let directory = tempdir().unwrap();
        let path = directory.path().to_string_lossy().to_string();
        let report = add_report(path.clone(), new_input(ReportType::Lost)).unwrap();

        let returned = mark_report_as_returned(path.clone(), report.id).unwrap();

        assert_eq!(returned.status, ItemStatus::Returned);
        assert_eq!(get_statistics(path).unwrap().returned, 1);
    }
}
