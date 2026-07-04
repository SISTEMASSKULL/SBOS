// ============================================================
// bauth::domain::usertemplate_validator — Validacion 15 secciones
//
// Contrato: BAUTH-USERTEMPLATE-SECCIONES.md v6.0
// Valida la estructura completa del UserTemplate al crear/actualizar.
// 15 secciones: identity, personal_info, professional, roles,
//   keycloak_credentials, physical_credentials, device_registry,
//   session_state, location, temporal, network, audit,
//   external_services, compliance, lifecycle
// ============================================================
#![allow(dead_code)]

use serde_json::Value;

#[derive(Debug, Clone)]
pub struct UsValidationReport {
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

const UT_SECTIONS: &[&str] = &[
    "identity",
    "personal_info",
    "professional",
    "roles",
    "keycloak_credentials",
    "physical_credentials",
    "device_registry",
    "session_state",
    "location",
    "temporal",
    "network",
    "audit",
    "external_services",
    "compliance",
    "lifecycle",
];

pub fn validate_usertemplate(template: &Value) -> UsValidationReport {
    let mut errors = Vec::new();
    let mut present = 0;
    let mut valid = 0;

    let obj = match template.as_object() {
        Some(o) => o,
        None => return UsValidationReport {
            valid: false, sections_total: 15, sections_present: 0, sections_valid: 0,
            section_errors: vec![SectionError {
                section: "root".into(), field: "template".into(),
                message: "el template debe ser un objeto JSON".into(),
            }],
        },
    };

    for section_name in UT_SECTIONS {
        let section = match obj.get(*section_name) {
            Some(v) => v,
            None => continue,
        };
        present += 1;
        let section_obj = match section.as_object() {
            Some(o) => o,
            None => {
                errors.push(SectionError {
                    section: section_name.to_string(), field: "root".into(),
                    message: format!("la seccion '{}' debe ser un objeto JSON", section_name),
                });
                continue;
            }
        };

        match *section_name {
            "identity" => v_identity(section_name, section_obj, &mut errors),
            "personal_info" => v_personal(section_name, section_obj, &mut errors),
            "professional" => v_professional(section_name, section_obj, &mut errors),
            "roles" => v_roles(section_name, section_obj, &mut errors),
            "keycloak_credentials" => v_kc_creds(section_name, section_obj, &mut errors),
            "physical_credentials" => v_physical_creds(section_name, section_obj, &mut errors),
            "device_registry" => v_devices(section_name, section_obj, &mut errors),
            "session_state" => v_session(section_name, section_obj, &mut errors),
            "location" => v_location(section_name, section_obj, &mut errors),
            "temporal" => v_temporal(section_name, section_obj, &mut errors),
            "network" => v_network(section_name, section_obj, &mut errors),
            "audit" => v_audit(section_name, section_obj, &mut errors),
            "external_services" => v_external(section_name, section_obj, &mut errors),
            "compliance" => v_compliance(section_name, section_obj, &mut errors),
            "lifecycle" => v_lifecycle(section_name, section_obj, &mut errors),
            _ => {}
        }
    }

    let names_with_errors: std::collections::HashSet<String> =
        errors.iter().map(|e| e.section.clone()).collect();
    for s in UT_SECTIONS {
        if obj.contains_key(*s) && !names_with_errors.contains(*s) { valid += 1; }
    }

    UsValidationReport {
        valid: errors.is_empty(),
        sections_total: 15, sections_present: present,
        sections_valid: valid,
        section_errors: errors,
    }
}

// ── Helpers ──────────────────────────────────────────────

fn chk(s: &str, o: &serde_json::Map<String,Value>, f: &str, e: &mut Vec<SectionError>) {
    if !o.contains_key(f) {
        e.push(SectionError { section: s.into(), field: f.into(),
            message: format!("campo obligatorio '{}' ausente en seccion '{}'", f, s) });
    }
}
fn str_val(o: &serde_json::Map<String,Value>, f: &str) -> Option<String> {
    o.get(f).and_then(|v| v.as_str()).map(String::from)
}
fn arr_val<'a>(o: &'a serde_json::Map<String,Value>, f: &str) -> Option<&'a Vec<Value>> {
    o.get(f).and_then(|v| v.as_array())
}
fn chk_email(s: &str, o: &serde_json::Map<String,Value>, f: &str, e: &mut Vec<SectionError>) {
    if let Some(email) = str_val(o, f) {
        if !email.contains('@') || email.len() < 5 {
            e.push(SectionError { section: s.into(), field: f.into(),
                message: format!("email '{}' invalido", email) });
        }
    }
}
fn chk_phone(s: &str, o: &serde_json::Map<String,Value>, f: &str, e: &mut Vec<SectionError>) {
    if let Some(phone) = str_val(o, f) {
        let digits: String = phone.chars().filter(|c| c.is_ascii_digit()).collect();
        if digits.len() < 7 || digits.len() > 15 {
            e.push(SectionError { section: s.into(), field: f.into(),
                message: format!("telefono '{}' invalido (7-15 digitos)", phone) });
        }
    }
}

// ── SECCION 0: identity ─────────────────────────────────

fn v_identity(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "username", e); chk(s, o, "email", e); chk(s, o, "tenant_id", e);
    chk(s, o, "empresa_id", e); chk(s, o, "accountType", e);
    chk_email(s, o, "email", e);
    if let Some(at) = str_val(o, "accountType") {
        if !["HUMAN","SERVICE","MACHINE","GUEST"].contains(&at.as_str()) {
            e.push(SectionError { section: s.into(), field: "accountType".into(),
                message: format!("accountType '{}' invalido. Use: HUMAN, SERVICE, MACHINE, GUEST", at) });
        }
    }
    if let Some(uname) = str_val(o, "username") {
        if uname.len() < 3 || uname.len() > 64 {
            e.push(SectionError { section: s.into(), field: "username".into(),
                message: "username debe tener entre 3 y 64 caracteres".into() });
        }
    }
}

// ── SECCION 1: personal_info ────────────────────────────

fn v_personal(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "first_name", e); chk(s, o, "last_name", e);
    chk(s, o, "document_type", e); chk(s, o, "document_number", e);
    chk_email(s, o, "personal_email", e);
    chk_phone(s, o, "mobile_phone", e);
    if let Some(dt) = str_val(o, "document_type") {
        let valid = ["CI","PASSPORT","DNI","RUC","NIT","RUT","CPF","CURP","INE"];
        if !valid.contains(&dt.as_str()) {
            e.push(SectionError { section: s.into(), field: "document_type".into(),
                message: format!("document_type '{}' invalido", dt) });
        }
    }
    if let Some(dob) = str_val(o, "date_of_birth") {
        if chrono::NaiveDate::parse_from_str(&dob, "%Y-%m-%d").is_err() {
            e.push(SectionError { section: s.into(), field: "date_of_birth".into(),
                message: "date_of_birth debe ser formato YYYY-MM-DD".into() });
        }
    }
}

// ── SECCION 2: professional ─────────────────────────────

fn v_professional(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "department", e); chk(s, o, "job_title", e);
    chk(s, o, "employee_id", e); chk(s, o, "sucursal_id", e);
    if let Some(jt) = str_val(o, "job_title") {
        if jt.len() < 2 { e.push(SectionError { section: s.into(), field: "job_title".into(),
            message: "job_title debe tener al menos 2 caracteres".into() }); }
    }
}

// ── SECCION 3: roles ────────────────────────────────────

fn v_roles(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    if let Some(roles) = arr_val(o, "assigned_roles") {
        if roles.is_empty() {
            e.push(SectionError { section: s.into(), field: "assigned_roles".into(),
                message: "debe tener al menos 1 rol asignado".into() });
        }
        for (i, role) in roles.iter().enumerate() {
            if let Some(code) = role.as_str() {
                if code.len() < 3 {
                    e.push(SectionError { section: s.into(), field: format!("assigned_roles[{}]", i).into(),
                        message: format!("role_code '{}' muy corto", code) });
                }
            }
        }
    } else { chk(s, o, "assigned_roles", e); }
    chk(s, o, "primary_role", e);
}

// ── SECCION 4: keycloak_credentials ─────────────────────

fn v_kc_creds(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "enrolled_methods", e);
    if let Some(methods) = arr_val(o, "enrolled_methods") {
        let valid = ["PASSWORD","TOTP","HOTP","WEBAUTHN_PWDLESS","WEBAUTHN_2FA","PASSKEY",
                     "X509_MTLS","KERBEROS","SAML_20","CIBA","DEVICE_AUTH","RECOVERY_CODES",
                     "EMAIL_OTP","CLIENT_CREDENTIALS","TOKEN_EXCHANGE"];
        for (i, m) in methods.iter().enumerate() {
            if let Some(name) = m.as_str() {
                if !valid.contains(&name) {
                    e.push(SectionError { section: s.into(), field: format!("enrolled_methods[{}]", i).into(),
                        message: format!("metodo '{}' no reconocido", name) });
                }
            }
        }
    }
    chk(s, o, "aal_level", e);
    if let Some(aal) = o.get("aal_level").and_then(|v| v.as_i64()) {
        if aal < 1 || aal > 3 {
            e.push(SectionError { section: s.into(), field: "aal_level".into(),
                message: "aal_level debe ser 1, 2, o 3 (NIST 800-63B)".into() });
        }
    }
    chk(s, o, "last_password_change", e);
}

// ── SECCION 5: physical_credentials ─────────────────────

fn v_physical_creds(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    if let Some(cards) = arr_val(o, "access_cards") {
        for (i, card) in cards.iter().enumerate() {
            if let Some(c) = card.as_object() {
                if !c.contains_key("card_number") {
                    e.push(SectionError { section: s.into(), field: format!("access_cards[{}]", i).into(),
                        message: "cada tarjeta debe tener card_number".into() });
                }
            }
        }
    }
    if let Some(bio) = o.get("biometric_templates").and_then(|v| v.as_array()) {
        let valid_types = ["FINGERPRINT","FACE","IRIS","VOICE","PALM","RETINA","PPG","ECG"];
        for (i, b) in bio.iter().enumerate() {
            if let Some(bt) = b.get("type").and_then(|v| v.as_str()) {
                if !valid_types.contains(&bt) {
                    e.push(SectionError { section: s.into(), field: format!("biometric_templates[{}].type", i).into(),
                        message: format!("tipo biometrico '{}' no reconocido", bt) });
                }
            }
        }
    }
}

// ── SECCION 6: device_registry ──────────────────────────

fn v_devices(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    if let Some(devices) = arr_val(o, "bound_devices") {
        let valid_cats = ["MOBILE","WATCH","RING","IMPLANT","CARD","WEARABLE","IOT","CHIP","DESKTOP","LAPTOP"];
        for (i, d) in devices.iter().enumerate() {
            if let Some(obj) = d.as_object() {
                if let Some(cat) = str_val(obj, "category") {
                    if !valid_cats.contains(&cat.as_str()) {
                        e.push(SectionError { section: s.into(), field: format!("bound_devices[{}].category", i).into(),
                            message: format!("categoria '{}' invalida", cat) });
                    }
                } else {
                    e.push(SectionError { section: s.into(), field: format!("bound_devices[{}]", i).into(),
                        message: "cada dispositivo debe tener 'category'".into() });
                }
            }
        }
    }
    chk(s, o, "max_devices", e);
}

// ── SECCION 7: session_state ────────────────────────────

fn v_session(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "max_concurrent_sessions", e);
    chk(s, o, "session_ttl_seconds", e);
    chk(s, o, "inactivity_timeout_seconds", e);
    if let Some(ttl) = o.get("session_ttl_seconds").and_then(|v| v.as_i64()) {
        if ttl < 300 || ttl > 86400 {
            e.push(SectionError { section: s.into(), field: "session_ttl_seconds".into(),
                message: "session_ttl_seconds debe estar entre 300 (5min) y 86400 (24h)".into() });
        }
    }
    if let Some(active) = arr_val(o, "active_sessions") {
        for (i, sess) in active.iter().enumerate() {
            if let Some(s) = sess.as_object() {
                if !s.contains_key("ctx_id") {
                    e.push(SectionError { section: section_name().into(), field: format!("active_sessions[{}].ctx_id", i).into(),
                        message: "cada sesion activa debe tener ctx_id".into() });
                }
            }
        }
        fn section_name() -> &'static str { "session_state" }
    }
}

// ── SECCION 8: location ─────────────────────────────────

fn v_location(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "country_code", e);
    if let Some(cc) = str_val(o, "country_code") {
        if cc.len() != 2 { e.push(SectionError { section: s.into(), field: "country_code".into(),
            message: "country_code debe ser ISO 3166-1 alpha-2 (2 letras)".into() }); }
    }
    if let Some(lat) = o.get("default_latitude").and_then(|v| v.as_f64()) {
        if !(-90.0..=90.0).contains(&lat) {
            e.push(SectionError { section: s.into(), field: "default_latitude".into(),
                message: "latitud debe estar entre -90 y 90".into() });
        }
    }
    if let Some(lon) = o.get("default_longitude").and_then(|v| v.as_f64()) {
        if !(-180.0..=180.0).contains(&lon) {
            e.push(SectionError { section: s.into(), field: "default_longitude".into(),
                message: "longitud debe estar entre -180 y 180".into() });
        }
    }
    chk(s, o, "preferred_timezone", e);
}

// ── SECCION 9: temporal ─────────────────────────────────

fn v_temporal(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    if let Some(schedule) = o.get("work_schedule").and_then(|v| v.as_object()) {
        chk(s, schedule, "days_of_week", e);
        chk(s, schedule, "start_hour", e);
        chk(s, schedule, "end_hour", e);
    }
    if let Some(vac) = o.get("vacation_days_remaining").and_then(|v| v.as_i64()) {
        if vac < 0 || vac > 365 { e.push(SectionError { section: s.into(),
            field: "vacation_days_remaining".into(), message: "debe estar entre 0 y 365".into() }); }
    }
}

// ── SECCION 10: network ─────────────────────────────────

fn v_network(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "vpn_profile_id", e);
    chk(s, o, "mtls_certificate_id", e);
    chk(s, o, "allowed_ips", e);
    if let Some(ips) = arr_val(o, "allowed_ips") {
        for (i, ip) in ips.iter().enumerate() {
            if let Some(addr) = ip.as_str() {
                if !addr.contains('.') && !addr.contains(':') {
                    e.push(SectionError { section: s.into(), field: format!("allowed_ips[{}]", i).into(),
                        message: format!("IP '{}' invalida", addr) });
                }
            }
        }
    }
    chk(s, o, "ztna_policy_id", e);
}

// ── SECCION 11: audit ───────────────────────────────────

fn v_audit(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "audit_enabled", e);
    chk(s, o, "retention_days", e);
    if let Some(ret) = o.get("retention_days").and_then(|v| v.as_i64()) {
        if ret < 30 || ret > 3650 { e.push(SectionError { section: s.into(),
            field: "retention_days".into(), message: "retention_days entre 30 y 3650 (10 años)".into() }); }
    }
    if let Some(events) = arr_val(o, "audited_events") {
        let valid = ["LOGIN","LOGOUT","PASSWORD_CHANGE","MFA_ENROLL","ROLE_CHANGE",
                     "SESSION_CREATE","SESSION_REVOKE","ACCESS_DENY","PRIVILEGE_ESCALATION"];
        for (i, evt) in events.iter().enumerate() {
            if let Some(name) = evt.as_str() {
                if !valid.contains(&name) {
                    e.push(SectionError { section: s.into(), field: format!("audited_events[{}]", i).into(),
                        message: format!("evento '{}' no reconocido", name) });
                }
            }
        }
    }
}

// ── SECCION 12: external_services ───────────────────────

fn v_external(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    if let Some(svcs) = arr_val(o, "linked_services") {
        for (i, svc) in svcs.iter().enumerate() {
            if let Some(s) = svc.as_object() {
                if !s.contains_key("service_name") || !s.contains_key("external_id") {
                    e.push(SectionError { section: section_name().into(),
                        field: format!("linked_services[{}]", i).into(),
                        message: "cada servicio debe tener service_name y external_id".into() });
                }
            }
        }
        fn section_name() -> &'static str { "external_services" }
    }
    chk(s, o, "federation_protocols", e);
}

// ── SECCION 13: compliance ──────────────────────────────

fn v_compliance(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "data_classification", e); chk(s, o, "gdpr_consent", e);
    chk(s, o, "terms_accepted", e); chk(s, o, "privacy_policy_version", e);
    if let Some(dc) = str_val(o, "data_classification") {
        let valid = ["PUBLIC","INTERNAL","CONFIDENTIAL","RESTRICTED","SECRET","TOP_SECRET"];
        if !valid.contains(&dc.as_str()) {
            e.push(SectionError { section: s.into(), field: "data_classification".into(),
                message: format!("clasificacion '{}' invalida", dc) });
        }
    }
    if let Some(fws) = arr_val(o, "applicable_frameworks") {
        let valid_fw = ["ISO27001","NIST80053","PCI_DSS","GDPR","SOX","HIPAA","SOC2","eIDAS","FAPI2","OWASP_ASVS"];
        for (i, fw) in fws.iter().enumerate() {
            if let Some(name) = fw.as_str() {
                if !valid_fw.contains(&name) {
                    e.push(SectionError { section: s.into(), field: format!("applicable_frameworks[{}]", i).into(),
                        message: format!("framework '{}' no reconocido", name) });
                }
            }
        }
    }
}

// ── SECCION 14: lifecycle ───────────────────────────────

fn v_lifecycle(s: &str, o: &serde_json::Map<String,Value>, e: &mut Vec<SectionError>) {
    chk(s, o, "status", e); chk(s, o, "created_at", e);
    if let Some(st) = str_val(o, "status") {
        let valid = ["PENDING","ACTIVE","INACTIVE","SUSPENDED","TERMINATED","LOCKED"];
        if !valid.contains(&st.as_str()) {
            e.push(SectionError { section: s.into(), field: "status".into(),
                message: format!("status '{}' invalido", st) });
        }
    }
    chk(s, o, "last_login_at", e);
    if let Some(exp) = o.get("account_expires_at").and_then(|v| v.as_str()) {
        if chrono::NaiveDate::parse_from_str(exp, "%Y-%m-%d").is_err() {
            e.push(SectionError { section: s.into(), field: "account_expires_at".into(),
                message: "account_expires_at debe ser YYYY-MM-DD o null".into() });
        }
    }
}

// ── Tests ───────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn make_valid_user() -> Value {
        serde_json::json!({
            "identity": {"username":"jperez","email":"jperez@sbos.bo","tenant_id":"t1","empresa_id":"e1","accountType":"HUMAN"},
            "personal_info": {"first_name":"Juan","last_name":"Perez","document_type":"CI","document_number":"1234567","personal_email":"juan@mail.com","mobile_phone":"+59170000000","date_of_birth":"1990-01-15"},
            "professional": {"department":"IT","job_title":"Developer","employee_id":"EMP001","sucursal_id":"s1"},
            "roles": {"assigned_roles":["ROL-IT","ROL-CAJERO"],"primary_role":"ROL-IT"},
            "keycloak_credentials": {"enrolled_methods":["PASSWORD","TOTP"],"aal_level":2,"last_password_change":"2026-01-01"},
            "physical_credentials": {"access_cards":[{"card_number":"CARD001","type":"PROXIMITY"}],"biometric_templates":[{"type":"FINGERPRINT","template_hash":"abc123"}]},
            "device_registry": {"bound_devices":[{"device_id":"d1","category":"MOBILE","trust_level":85}],"max_devices":5},
            "session_state": {"max_concurrent_sessions":3,"session_ttl_seconds":28800,"inactivity_timeout_seconds":1800,"active_sessions":[{"ctx_id":"ctx-1"}]},
            "location": {"country_code":"BO","default_latitude":-16.5,"default_longitude":-68.15,"preferred_timezone":"America/La_Paz"},
            "temporal": {"work_schedule":{"days_of_week":["MON","TUE","WED","THU","FRI"],"start_hour":"08:00","end_hour":"18:00"},"vacation_days_remaining":15},
            "network": {"vpn_profile_id":"vpn-basic","mtls_certificate_id":"cert-01","allowed_ips":["192.168.1.0/24"],"ztna_policy_id":"ztna-default"},
            "audit": {"audit_enabled":true,"retention_days":365,"audited_events":["LOGIN","LOGOUT","PASSWORD_CHANGE"]},
            "external_services": {"linked_services":[{"service_name":"google_workspace","external_id":"gw-001"}],"federation_protocols":["OIDC"]},
            "compliance": {"data_classification":"INTERNAL","gdpr_consent":true,"terms_accepted":true,"privacy_policy_version":"2.0","applicable_frameworks":["ISO27001","GDPR"]},
            "lifecycle": {"status":"ACTIVE","created_at":"2026-01-01","last_login_at":"2026-06-28","account_expires_at":null}
        })
    }

    #[test] fn test_valid_user_passes() { let r = validate_usertemplate(&make_valid_user()); assert!(r.valid, "valido: {:?}", r.section_errors); assert_eq!(r.sections_present, 15, "debe tener 15 secciones"); }
    #[test] fn test_empty_passes() { let r = validate_usertemplate(&serde_json::json!({})); assert!(r.valid); }
    #[test] fn test_invalid_email() { let t = serde_json::json!({"identity":{"username":"x","email":"noemail","tenant_id":"t1","empresa_id":"e1","accountType":"HUMAN"}}); let r = validate_usertemplate(&t); assert!(!r.valid); }
    #[test] fn test_invalid_status() { let t = serde_json::json!({"lifecycle":{"status":"DELETED","created_at":"2026-01-01","last_login_at":"2026-01-01"}}); let r = validate_usertemplate(&t); assert!(!r.valid); }
    #[test] fn test_invalid_aal() { let t = serde_json::json!({"keycloak_credentials":{"enrolled_methods":["PASSWORD"],"aal_level":5,"last_password_change":"2026-01-01"}}); let r = validate_usertemplate(&t); assert!(!r.valid); }
    #[test] fn test_invalid_device_category() { let t = serde_json::json!({"device_registry":{"bound_devices":[{"category":"UNKNOWN_DEVICE"}],"max_devices":3}}); let r = validate_usertemplate(&t); assert!(!r.valid); }
}
