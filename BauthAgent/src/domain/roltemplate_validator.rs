// ============================================================
// bauth::domain::roltemplate_validator — Validacion 16 bloques
// ALINEADO EXACTAMENTE con:
//   BAUTH-ROLTEMPLATE-SECCIONES.md v6.0
//   seed_idn_role_template_data.sql (bloques 1-16)
//   DDL_skSBOS_db.sql CHECK constraints
// ============================================================
#![allow(dead_code)]

use serde_json::Value;

#[derive(Debug, Clone)]
pub struct ValidationReport {
    pub valid: bool,
    pub sections_total: usize,
    pub sections_present: usize,
    pub sections_valid: usize,
    pub section_errors: Vec<SectionError>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct SectionError {
    pub section: String,
    pub field: String,
    pub message: String,
}

/// 16 bloques del RolTemplate — nombres EXACTOS del seed
const SECTIONS: &[&str] = &[
    "role", "logical_access", "physical_access", "financial",
    "temporal", "biometric", "geospatial", "network",
    "context", "credentials", "delegation", "audit",
    "blockchain", "security", "compliance", "sync",
];

pub fn validate_roltemplate(template: &Value) -> ValidationReport {
    let mut errors = Vec::new();
    let mut present = 0;
    let mut valid = 0;

    let obj = match template.as_object() {
        Some(o) => o,
        None => return ValidationReport {
            valid: false, sections_total: 16, sections_present: 0, sections_valid: 0,
            section_errors: vec![SectionError {
                section: "root".into(), field: "template".into(),
                message: "el template debe ser un objeto JSON".into(),
            }],
        },
    };

    for sec in SECTIONS {
        let section_val = match obj.get(*sec) {
            Some(v) => v,
            None => continue,
        };
        present += 1;
        let so = match section_val.as_object() {
            Some(o) => o,
            None => { errors.push(err(sec,"root",format!("'{}' debe ser objeto JSON",sec))); continue; }
        };

        match *sec {
            "role"             => v_role(sec, so, &mut errors),
            "logical_access"   => v_logical(sec, so, &mut errors),
            "physical_access"  => v_physical(sec, so, &mut errors),
            "financial"        => v_financial(sec, so, &mut errors),
            "temporal"         => v_temporal(sec, so, &mut errors),
            "biometric"        => v_biometric(sec, so, &mut errors),
            "geospatial"       => v_geospatial(sec, so, &mut errors),
            "network"          => v_network(sec, so, &mut errors),
            "context"          => v_context(sec, so, &mut errors),
            "credentials"      => v_credentials(sec, so, &mut errors),
            "delegation"       => v_delegation(sec, so, &mut errors),
            "audit"            => v_audit(sec, so, &mut errors),
            "blockchain"       => v_blockchain(sec, so, &mut errors),
            "security"         => v_security(sec, so, &mut errors),
            "compliance"       => v_compliance(sec, so, &mut errors),
            "sync"             => v_sync(sec, so, &mut errors),
            _ => {}
        }
    }

    let names_with_err: std::collections::HashSet<String> = errors.iter().map(|e| e.section.clone()).collect();
    for s in SECTIONS { if obj.contains_key(*s) && !names_with_err.contains(*s) { valid += 1; } }

    ValidationReport { valid: errors.is_empty(), sections_total: 16, sections_present: present, sections_valid: valid, section_errors: errors }
}

// ── Helpers ──────────────────────────────────────────────
fn err(s: &str, f: &str, m: String) -> SectionError { SectionError { section: s.into(), field: f.into(), message: m } }
fn chk(s: &str, o: &serde_json::Map<String,Value>, f: &str, e: &mut Vec<SectionError>) {
    if !o.contains_key(f) { e.push(err(s,f,format!("campo obligatorio '{}' ausente", f))); }
}
fn str_val<'a>(o: &'a serde_json::Map<String,Value>, f: &str) -> Option<&'a str> { o.get(f).and_then(|v| v.as_str()) }
fn arr_val<'a>(o: &'a serde_json::Map<String,Value>, f: &str) -> Option<&'a Vec<Value>> { o.get(f).and_then(|v| v.as_array()) }
fn int_val(o: &serde_json::Map<String,Value>, f: &str) -> Option<i64> { o.get(f).and_then(|v| v.as_i64()) }
fn bool_val(o: &serde_json::Map<String,Value>, f: &str) -> Option<bool> { o.get(f).and_then(|v| v.as_bool()) }

// ── BLOQUE 1: role (identidad) ───────────────────────────
fn v_role(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"id",e); chk(s,o,"type_id",e); chk(s,o,"hierarchy_level",e);
    chk(s,o,"version",e); chk(s,o,"status",e); chk(s,o,"tier",e);
    chk(s,o,"loa_required",e); chk(s,o,"mfa_required",e);
    if let Some(tier) = str_val(o,"tier") {
        let valid = ["SU","SYS","BIZ_N5","BIZ_N4","BIZ_N3","BIZ_N2","BIZ_N1","EXT_N0","M2M","VISITANTE"];
        if !valid.contains(&tier) { e.push(err(s,"tier",format!("'{}' invalido", tier))); }
    }
    if let Some(st) = str_val(o,"status") {
        let valid = ["DEFINIDO","DESARROLLADO","REVISADO","AUTORIZADO","PUBLICADO","DEPRECADO","RETIRADO"];
        if !valid.contains(&st) { e.push(err(s,"status",format!("'{}' invalido", st))); }
    }
    if let Some(loa) = int_val(o,"loa_required") { if loa<1||loa>4 { e.push(err(s,"loa_required","debe ser 1-4".into())); } }
}

// ── BLOQUE 2: logical_access (D1) ────────────────────────
fn v_logical(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableZones",e); chk(s,o,"selectedZones",e);
    chk(s,o,"availableApplications",e); chk(s,o,"availableVerbs",e);
    chk(s,o,"selectedVerbs",e); chk(s,o,"scope",e); chk(s,o,"dataClassification",e);
    if let Some(sc) = str_val(o,"scope") {
        if !["GLOBAL","COMPANY","BRANCH","PERSONAL"].contains(&sc) { e.push(err(s,"scope",format!("'{}' invalido",sc))); }
    }
    if let Some(dc) = str_val(o,"dataClassification") {
        if !["PUBLIC","INTERNAL","CONFIDENTIAL","RESTRICTED"].contains(&dc) { e.push(err(s,"dataClassification",format!("'{}' invalido",dc))); }
    }
}

// ── BLOQUE 3: physical_access (D2) ───────────────────────
fn v_physical(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableZones",e); chk(s,o,"selectedZones",e);
    chk(s,o,"zoneMethods",e); chk(s,o,"maxSecurityZone",e);
    chk(s,o,"requiresEscort",e); chk(s,o,"requiresTwoPerson",e);
}

// ── BLOQUE 4: financial (D3) ─────────────────────────────
fn v_financial(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableTransactionTypes",e); chk(s,o,"limits",e);
    chk(s,o,"requiresDualApproval",e); chk(s,o,"maxApprovalAmount",e);
    chk(s,o,"activeSoDRules",e);
}

// ── BLOQUE 5: temporal (D4) ──────────────────────────────
fn v_temporal(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableSchedules",e); chk(s,o,"selectedScheduleId",e);
    chk(s,o,"holidays",e); chk(s,o,"overtimePolicy",e); chk(s,o,"breakPolicy",e);
    chk(s,o,"allowOvertime",e); chk(s,o,"requiresApprovalOutside",e);
}

// ── BLOQUE 6: biometric (D5) ─────────────────────────────
fn v_biometric(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableMethods",e); chk(s,o,"policies",e); chk(s,o,"configDefaults",e);
    chk(s,o,"fmrThreshold",e); chk(s,o,"livenessRequired",e); chk(s,o,"enrollmentSupervised",e);
}

// ── BLOQUE 7: geospatial (D6) ────────────────────────────
fn v_geospatial(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableGeoFences",e); chk(s,o,"trustTiers",e);
    chk(s,o,"velocityPolicy",e); chk(s,o,"homeCountry",e);
    chk(s,o,"allowedCountries",e); chk(s,o,"crossBorderBlocked",e);
}

// ── BLOQUE 8: network (D7) ───────────────────────────────
fn v_network(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableNetworks",e); chk(s,o,"availableDeviceTypes",e);
    chk(s,o,"ztnaPolicy",e); chk(s,o,"vpnRequired",e);
    chk(s,o,"mTLSRequired",e); chk(s,o,"deviceTrustMin",e);
}

// ── BLOQUE 9: context (D8) ───────────────────────────────
fn v_context(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"sessionTtlSeconds",e); chk(s,o,"inactivityTimeoutSeconds",e);
    chk(s,o,"maxContexts",e); chk(s,o,"contextSwitchAllowed",e);
    chk(s,o,"caepEvents",e); chk(s,o,"riskPolicy",e); chk(s,o,"dctxRequired",e);
    if let Some(ttl) = int_val(o,"sessionTtlSeconds") { if ttl<300||ttl>86400 { e.push(err(s,"sessionTtlSeconds","debe estar 300-86400".into())); } }
}

// ── BLOQUE 10: credentials (D9) ──────────────────────────
fn v_credentials(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"availableMethods",e); chk(s,o,"requiredMethods",e);
    chk(s,o,"appliedPolicies",e); chk(s,o,"stepUpRules",e);
    chk(s,o,"mfaRequired",e); chk(s,o,"minAal",e);
    chk(s,o,"sessionTimeoutSecs",e); chk(s,o,"maxSessions",e); chk(s,o,"stepUpAllowed",e);
    if let Some(aal) = str_val(o,"minAal") {
        if !["AAL1","AAL2","AAL3","AAL4"].contains(&aal) { e.push(err(s,"minAal",format!("'{}' invalido",aal))); }
    }
}

// ── BLOQUE 11: delegation (D10) ──────────────────────────
fn v_delegation(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"enabled",e); chk(s,o,"maxDurationDays",e); chk(s,o,"maxChainDepth",e);
    chk(s,o,"autoRevokeOnExpiry",e); chk(s,o,"requiresApproval",e);
    chk(s,o,"nonDelegableRoles",e); chk(s,o,"allowedTargetRoles",e);
}

// ── BLOQUE 12: audit (D11) ───────────────────────────────
fn v_audit(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"level",e); chk(s,o,"retentionDays",e);
    chk(s,o,"hashChainRequired",e); chk(s,o,"blockchainAnchorRequired",e);
    chk(s,o,"reviewFrequency",e); chk(s,o,"complianceControls",e);
    if let Some(lv) = str_val(o,"level") {
        if !["none","basic","full"].contains(&lv) { e.push(err(s,"level",format!("'{}' invalido",lv))); }
    }
    if let Some(rf) = str_val(o,"reviewFrequency") {
        if !["monthly","quarterly","semi_annual","annual"].contains(&rf) { e.push(err(s,"reviewFrequency",format!("'{}' invalido",rf))); }
    }
}

// ── BLOQUE 13: blockchain (D12) ──────────────────────────
fn v_blockchain(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"enabled",e); chk(s,o,"variant",e); chk(s,o,"anchorFrequencySeconds",e);
    chk(s,o,"network",e); chk(s,o,"merkleAlgorithm",e); chk(s,o,"batchSize",e);
    chk(s,o,"verifiableExternally",e);
    if let Some(v) = str_val(o,"variant") { if !["A","B"].contains(&v) { e.push(err(s,"variant",format!("'{}' invalido, use A o B",v))); } }
    if let Some(algo) = str_val(o,"merkleAlgorithm") { if algo!="keccak256" { e.push(err(s,"merkleAlgorithm","solo keccak256 soportado".into())); } }
}

// ── BLOQUE 14: security (D13) ────────────────────────────
fn v_security(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"keyInventory",e); chk(s,o,"cryptoAlgorithms",e);
    chk(s,o,"sodValidation",e); chk(s,o,"securityZone",e);
}

// ── BLOQUE 15: compliance (D14) ──────────────────────────
fn v_compliance(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"frameworks",e); chk(s,o,"gdprConsent",e); chk(s,o,"dataSubjectRights",e);
    chk(s,o,"dataRetentionDays",e); chk(s,o,"breachNotificationHours",e);
    chk(s,o,"complianceStatus",e); chk(s,o,"controlsImplemented",e); chk(s,o,"controlsTotal",e);
    if let Some(cs) = str_val(o,"complianceStatus") {
        if !["full","basic","none"].contains(&cs) { e.push(err(s,"complianceStatus",format!("'{}' invalido",cs))); }
    }
}

// ── BLOQUE 16: sync (metadatos) ──────────────────────────
fn v_sync(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s,o,"kcCompositeRole",e); chk(s,o,"kcAuthFlow",e);
    chk(s,o,"trytonGroup",e); chk(s,o,"trytonIrModelAccess",e);
    chk(s,o,"syncStatus",e);
    if let Some(ss) = str_val(o,"syncStatus") {
        if !["PENDING","SYNCING","SYNCED","ERROR","DRIFT"].contains(&ss) { e.push(err(s,"syncStatus",format!("'{}' invalido",ss))); }
    }
}

// ── Tests ────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_template() -> Value { serde_json::json!({
        "role":{"id":"ROL-TEST","type_id":"TYPE-OPERATIVO","hierarchy_level":1,"version":"1.0.0","status":"DEFINIDO","tier":"BIZ_N1","loa_required":2,"mfa_required":true,"name":{"es":"Test"},"description":{"es":"Rol test"},"metadata":{}},
        "logical_access":{"availableZones":[],"selectedZones":[],"availableApplications":[],"availableVerbs":[1,2,3,4],"selectedVerbs":[1,2,4],"scope":"COMPANY","dataClassification":"INTERNAL"},
        "physical_access":{"availableZones":[],"selectedZones":[],"zoneMethods":[],"maxSecurityZone":3,"requiresEscort":false,"requiresTwoPerson":false},
        "financial":{"availableTransactionTypes":[],"limits":[],"requiresDualApproval":false,"maxApprovalAmount":50000,"activeSoDRules":[]},
        "temporal":{"availableSchedules":[],"selectedScheduleId":null,"holidays":[],"overtimePolicy":{},"breakPolicy":{},"allowOvertime":false,"requiresApprovalOutside":true},
        "biometric":{"availableMethods":[],"policies":[],"configDefaults":[],"fmrThreshold":0.001,"livenessRequired":false,"enrollmentSupervised":false},
        "geospatial":{"availableGeoFences":[],"trustTiers":[],"velocityPolicy":{},"homeCountry":"BO","allowedCountries":["BO"],"crossBorderBlocked":true},
        "network":{"availableNetworks":[],"availableDeviceTypes":[],"ztnaPolicy":{},"vpnRequired":true,"mTLSRequired":true,"deviceTrustMin":40},
        "context":{"sessionTtlSeconds":28800,"inactivityTimeoutSeconds":900,"maxContexts":3,"contextSwitchAllowed":true,"caepEvents":[],"riskPolicy":{},"dctxRequired":true},
        "credentials":{"availableMethods":[],"requiredMethods":{},"appliedPolicies":[],"stepUpRules":[],"mfaRequired":true,"minAal":"AAL2","sessionTimeoutSecs":28800,"maxSessions":3,"stepUpAllowed":true},
        "delegation":{"enabled":false,"maxDurationDays":7,"maxChainDepth":1,"autoRevokeOnExpiry":true,"requiresApproval":true,"nonDelegableRoles":[],"allowedTargetRoles":[]},
        "audit":{"level":"basic","retentionDays":2555,"hashChainRequired":false,"blockchainAnchorRequired":false,"reviewFrequency":"quarterly","complianceControls":[]},
        "blockchain":{"enabled":false,"variant":"A","anchorFrequencySeconds":3600,"network":"arbitrum_one","merkleAlgorithm":"keccak256","batchSize":1000,"verifiableExternally":true},
        "security":{"keyInventory":[],"cryptoAlgorithms":[],"sodValidation":{},"securityZone":3},
        "compliance":{"frameworks":["ISO 27001:2022"],"gdprConsent":{"dataProcessing":true,"marketing":false,"thirdParty":false},"dataSubjectRights":["access"],"dataRetentionDays":2555,"breachNotificationHours":72,"complianceStatus":"basic","controlsImplemented":15,"controlsTotal":34},
        "sync":{"kcCompositeRole":"ROL-TEST","kcAuthFlow":"browser","trytonGroup":"ROL-TEST","trytonIrModelAccess":{},"syncStatus":"PENDING"}
    })}

    #[test] fn test_valid_16_sections() { let r = validate_roltemplate(&valid_template()); assert!(r.valid,"valido: {:?}", r.section_errors); assert_eq!(r.sections_present,16,"16 secciones requeridas"); }
    #[test] fn test_empty_passes() { let r = validate_roltemplate(&serde_json::json!({})); assert!(r.valid); assert_eq!(r.sections_present,0); }
    #[test] fn test_invalid_tier() { let t = serde_json::json!({"role":{"id":"x","type_id":"x","hierarchy_level":1,"version":"1","status":"DEFINIDO","tier":"INVALID","loa_required":1,"mfa_required":false}}); assert!(!validate_roltemplate(&t).valid); }
    #[test] fn test_invalid_status() { let t = serde_json::json!({"role":{"id":"x","type_id":"x","hierarchy_level":1,"version":"1","status":"DELETED","tier":"BIZ_N1","loa_required":1,"mfa_required":false}}); assert!(!validate_roltemplate(&t).valid); }
    #[test] fn test_invalid_loa() { let t = serde_json::json!({"role":{"id":"x","type_id":"x","hierarchy_level":1,"version":"1","status":"DEFINIDO","tier":"BIZ_N1","loa_required":5,"mfa_required":false}}); assert!(!validate_roltemplate(&t).valid); }
    #[test] fn test_missing_role_fields() { let t = serde_json::json!({"role":{}}); let r = validate_roltemplate(&t); assert!(!r.valid); assert!(r.section_errors.iter().any(|e| e.field=="id")); }
    #[test] fn test_string_not_object() { assert!(!validate_roltemplate(&serde_json::json!({"logical_access":"bad"})).valid); }
    #[test] fn test_invalid_sync_status() { let t = serde_json::json!({"sync":{"kcCompositeRole":"x","kcAuthFlow":"x","trytonGroup":"x","trytonIrModelAccess":{},"syncStatus":"BROKEN"}}); assert!(!validate_roltemplate(&t).valid); }
    #[test] fn test_invalid_audit_level() { let t = serde_json::json!({"audit":{"level":"extreme","retentionDays":365,"hashChainRequired":false,"blockchainAnchorRequired":false,"reviewFrequency":"monthly","complianceControls":[]}}); assert!(!validate_roltemplate(&t).valid); }
    #[test] fn test_biometric_all_fields() { let t = serde_json::json!({"biometric":{"availableMethods":[],"policies":[],"configDefaults":[],"fmrThreshold":0.0001,"livenessRequired":true,"enrollmentSupervised":true}}); assert!(validate_roltemplate(&t).valid); }
}
