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
    pub(crate) fn from_report_type(report_type: ReportType) -> Self {
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
    /// RFC 3339 text keeps the bridge type beginner-friendly and sorts correctly.
    pub created_at: String,
}

#[derive(Debug, Clone)]
pub struct NewReportInput {
    pub item_name: String,
    pub category: String,
    pub color: String,
    pub location: String,
    pub date: String,
    pub description: String,
    pub contact_information: Option<String>,
    pub report_type: ReportType,
}

#[derive(Debug, Clone)]
pub struct UpdateReportInput {
    pub item_name: String,
    pub category: String,
    pub color: String,
    pub location: String,
    pub date: String,
    pub description: String,
    pub contact_information: Option<String>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct Statistics {
    pub lost: u32,
    pub found: u32,
    pub returned: u32,
    pub total: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchReason {
    pub label: String,
    pub points: u8,
    pub max_points: u8,
    pub matched: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MatchResult {
    pub lost_report: ItemReport,
    pub found_report: ItemReport,
    pub score: u8,
    pub quality: String,
    pub reasons: Vec<MatchReason>,
}
