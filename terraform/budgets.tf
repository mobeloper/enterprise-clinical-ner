# ==========================================
# Enterprise AWS Budget & Cost Safeguard
# ==========================================
resource "aws_budgets_budget" "clinical_ai_compute_budget" {
  name              = "clinical-ai-compute-budget-${var.environment}"
  budget_type       = "COST"
  limit_amount      = var.environment == "production" ? "2000" : "500" # Differentiated baseline thresholds
  limit_unit        = "USD"
  time_period_start = "2026-01-01_00:00" # Current multi-year timeline baseline boundary
  time_unit         = "MONTHLY"

  # Scopes the cost tracker explicitly to your pipeline using resource tags
  cost_filter {
    name = "TagKeyValue"
    values = [
      "Application$Clinical-NER"
    ]
  }

  # Alert 1: Triggers instantly if ACTUAL monthly spend hits 80% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["clinical-ai-alerts@your-enterprise.com"]
  }

  # Alert 2: Triggers aggressively if FORECASTED monthly trends cross 100% of budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["clinical-ai-alerts@your-enterprise.com"]
  }
}
