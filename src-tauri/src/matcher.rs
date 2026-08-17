use std::collections::HashSet;

use crate::models::{ItemReport, ItemStatus, MatchReason, MatchResult};

const MINIMUM_MATCH_SCORE: u8 = 60;

pub fn find_matches(reports: &[ItemReport], report_id: Option<&str>) -> Vec<MatchResult> {
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

    matches.sort_by(|left, right| {
        right.score.cmp(&left.score).then_with(|| {
            right
                .lost_report
                .created_at
                .cmp(&left.lost_report.created_at)
        })
    });
    matches
}

pub fn score_pair(lost: &ItemReport, found: &ItemReport) -> MatchResult {
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
            label: label.to_string(),
            points: if matched { points } else { 0 },
            max_points: points,
            matched,
        })
        .collect();

    let similarity = keyword_similarity(&lost.description, &found.description);
    let description_points = (similarity * 10.0).round() as u8;
    reasons.push(MatchReason {
        label: if description_points == 10 {
            "Description keywords match".into()
        } else if description_points > 0 {
            "Description partially matches".into()
        } else {
            "Description does not match".into()
        },
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

/// A small Jaccard-style keyword comparison, deliberately kept explainable.
fn keyword_similarity(left: &str, right: &str) -> f32 {
    let left = keywords(left);
    let right = keywords(right);
    if left.is_empty() || right.is_empty() {
        return 0.0;
    }
    let intersection = left.intersection(&right).count() as f32;
    let union = left.union(&right).count() as f32;
    intersection / union
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
    use chrono::Utc;

    use super::*;
    use crate::models::{ItemStatus, ReportType};

    fn report(id: &str, report_type: ReportType) -> ItemReport {
        ItemReport {
            id: id.into(),
            item_name: " Wallet ".into(),
            category: "Wallet".into(),
            color: "BLACK".into(),
            location: "Library".into(),
            date: "2026-08-10".into(),
            description: "Black leather wallet with a scratch".into(),
            contact_information: None,
            report_type,
            status: ItemStatus::from_report_type(report_type),
            created_at: Utc::now(),
        }
    }

    #[test]
    fn identical_reports_score_one_hundred_case_insensitively() {
        let lost = report("LST-0001", ReportType::Lost);
        let mut found = report("FND-0001", ReportType::Found);
        found.item_name = "wallet".into();

        assert_eq!(score_pair(&lost, &found).score, 100);
    }

    #[test]
    fn matches_below_sixty_are_hidden() {
        let lost = report("LST-0001", ReportType::Lost);
        let mut found = report("FND-0001", ReportType::Found);
        found.item_name = "Keys".into();
        found.category = "Keys".into();
        found.color = "Silver".into();
        found.location = "Cafeteria".into();
        found.description = "Three keys on a blue ring".into();

        assert!(find_matches(&[lost, found], None).is_empty());
    }

    #[test]
    fn returned_items_are_excluded() {
        let lost = report("LST-0001", ReportType::Lost);
        let mut found = report("FND-0001", ReportType::Found);
        found.status = ItemStatus::Returned;

        assert!(find_matches(&[lost, found], None).is_empty());
    }
}
