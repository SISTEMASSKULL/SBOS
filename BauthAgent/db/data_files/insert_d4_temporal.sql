INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'time_based_access_d4',
  '{
    "temporal_access_controls_d4": {
      "description": "Time-based access control (TBAC) policies for D4 Temporal domain",
      "access_windows": {
        "absolute_time": {"description": "Fixed start and end dates for access grants", "use_cases": ["contractors", "project_based_staff", "temporary_employees"]},
        "periodic_time": {"description": "Recurring schedules: daily, weekly, monthly patterns", "use_cases": ["standard_work_hours", "business_hours_9to6", "weekday_only_access"]},
        "recurring_time": {"description": "Interval-based access triggered by events", "use_cases": ["on_call_rotation", "incident_response_windows"]}
      },
      "work_schedule_policies": {
        "standard_hours": {"start": "09:00", "end": "18:00", "days": ["monday","tuesday","wednesday","thursday","friday"], "description": "Standard business hours access"},
        "after_hours_restriction": {"enabled": true, "requires_approval": true, "max_duration_hours": 4, "description": "After-hours access requires manager approval with 4h max"},
        "weekend_restriction": {"enabled": true, "requires_approval": true, "description": "Weekend access restricted to on-call personnel only"},
        "holiday_restriction": {"enabled": true, "requires_emergency_break_glass": true, "description": "Holiday access requires break-glass emergency procedure"},
        "shift_based_access": {"enabled": true, "shift_types": ["morning_6to14", "afternoon_14to22", "night_22to6"], "description": "24/7 facilities with rotating shift credentials"}
      },
      "just_in_time_access": {
        "description": "Grant elevated permissions only when needed, auto-revoke after task",
        "max_duration_minutes": 120,
        "auto_revoke": true,
        "requires_justification": true,
        "use_cases": ["debugging_production", "incident_response", "database_maintenance", "config_changes"]
      },
      "session_management": {
        "idle_timeout_minutes": 15,
        "absolute_timeout_hours": 8,
        "concurrent_session_limit": 3,
        "force_reauth_after_timeout": true
      },
      "contractor_vendor_temporal": {
        "auto_expiration": true,
        "max_grant_days": 90,
        "renewal_required": true,
        "approval_workflow": "manager_plus_project_owner",
        "description": "Third-party credentials auto-expire after project duration"
      },
      "emergency_override": {
        "break_glass_procedure": true,
        "requires_multi_approval": true,
        "full_logging": true,
        "post_incident_review_hours": 48,
        "auto_revoke_after_incident": true,
        "description": "Documented workflow for granting after-hours emergency access"
      },
      "ntp_synchronization": {
        "required": true,
        "max_clock_drift_seconds": 5,
        "description": "All systems must use synchronized NTP sources — clock drift can cause policy misapplication"
      },
      "compliance_alignment": ["NIST 800-53", "ISO 27001 A.8.5", "GDPR", "HIPAA", "SOC 2", "SOX"],
      "industry_stat": "79% of data breaches involve compromised credentials — TBAC limits damage window by deactivating credentials outside approved hours"
    }
  }'::jsonb
);
