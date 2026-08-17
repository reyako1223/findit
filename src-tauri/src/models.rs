use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ReportType {
    Lost,
    Found,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ItemStatus {
    Lost,
    Found,
    Returned,
}

impl ItemStatus {
    pub fn from_report_type(report_type: ReportType) -> Self {
        match report_type {
            ReportType::Lost => Self::Lost,
            ReportType::Found => Self::Found,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ItemReport {
    pub id: String,
    pub item_name: String,
    pub category: String,
    pub color: String,
    pub location: String,
    pub date: String,
    pub description: String,
    pub contact_information: Option<String>,
    pub report_type: ReportType,
    pub status: ItemStatus,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NewReportInput {
    pub item_name: String,
    pub category: String,
    pub color: String,
    pub location: String,
    pub date: String,
    #[serde(default)]
    pub description: String,
    pub contact_information: Option<String>,
    pub report_type: ReportType,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateReportInput {
    pub item_name: String,
    pub category: String,
    pub color: String,
    pub location: String,
    pub date: String,
    #[serde(default)]
    pub description: String,
    pub contact_information: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReportQuery {
    pub search: Option<String>,
    pub status: Option<ItemStatus>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Statistics {
    pub lost: usize,
    pub found: usize,
    pub returned: usize,
    pub total: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MatchReason {
    pub label: String,
    pub points: u8,
    pub max_points: u8,
    pub matched: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MatchResult {
    pub lost_report: ItemReport,
    pub found_report: ItemReport,
    pub score: u8,
    pub quality: String,
    pub reasons: Vec<MatchReason>,
}

impl NewReportInput {
    pub fn validate_and_clean(self) -> Result<Self, String> {
        let cleaned = Self {
            item_name: clean_required("Item name", self.item_name)?,
            category: clean_required("Category", self.category)?,
            color: clean_required("Color", self.color)?,
            location: clean_required("Location", self.location)?,
            date: validate_date(self.date)?,
            description: clean_optional_text(self.description, 1_000, "Description")?,
            contact_information: clean_option(
                self.contact_information,
                200,
                "Contact information",
            )?,
            report_type: self.report_type,
        };
        Ok(cleaned)
    }
}

impl UpdateReportInput {
    pub fn validate_and_clean(self) -> Result<Self, String> {
        let cleaned = Self {
            item_name: clean_required("Item name", self.item_name)?,
            category: clean_required("Category", self.category)?,
            color: clean_required("Color", self.color)?,
            location: clean_required("Location", self.location)?,
            date: validate_date(self.date)?,
            description: clean_optional_text(self.description, 1_000, "Description")?,
            contact_information: clean_option(
                self.contact_information,
                200,
                "Contact information",
            )?,
        };
        Ok(cleaned)
    }
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

fn clean_optional_text(value: String, limit: usize, field: &str) -> Result<String, String> {
    let value = value.trim().to_string();
    if value.chars().count() > limit {
        return Err(format!("{field} must be {limit} characters or fewer."));
    }
    Ok(value)
}

fn clean_option(
    value: Option<String>,
    limit: usize,
    field: &str,
) -> Result<Option<String>, String> {
    value
        .map(|text| clean_optional_text(text, limit, field))
        .transpose()
        .map(|value| value.filter(|text| !text.is_empty()))
}

fn validate_date(value: String) -> Result<String, String> {
    let value = value.trim().to_string();
    NaiveDate::parse_from_str(&value, "%Y-%m-%d")
        .map(|_| value)
        .map_err(|_| "Date must be a valid date in YYYY-MM-DD format.".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validation_trims_fields_and_removes_empty_contact() {
        let input = NewReportInput {
            item_name: " Wallet ".into(),
            category: " Wallet ".into(),
            color: " Black ".into(),
            location: " Library ".into(),
            date: "2026-08-10".into(),
            description: " Small scratch ".into(),
            contact_information: Some("   ".into()),
            report_type: ReportType::Lost,
        };

        let cleaned = input.validate_and_clean().unwrap();
        assert_eq!(cleaned.item_name, "Wallet");
        assert_eq!(cleaned.contact_information, None);
    }

    #[test]
    fn validation_rejects_empty_required_fields() {
        let input = NewReportInput {
            item_name: " ".into(),
            category: "Wallet".into(),
            color: "Black".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: String::new(),
            contact_information: None,
            report_type: ReportType::Lost,
        };

        assert_eq!(
            input.validate_and_clean().unwrap_err(),
            "Item name is required."
        );
    }
}
