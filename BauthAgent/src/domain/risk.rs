//! bauth::domain::risk — H-12 Risk Scoring Engine
//! NIST SP 800-207 Zero Trust — verificación continua.
#![allow(dead_code)]
use chrono::Timelike;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct RiskContext {
    pub user_id: String, pub client_ip: String, pub device_fingerprint: String,
    pub time_of_day: chrono::NaiveTime,
    pub known_device: bool, pub known_location: bool,
    pub vpn_detected: bool, pub tor_exit_node: bool,
    pub login_attempts_last_hour: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskScore {
    pub total: f64, pub identity_score: f64, pub device_score: f64,
    pub network_score: f64, pub behavioral_score: f64, pub flags: Vec<RiskFlag>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum RiskFlag { NewDevice, NewLocation, OutsideBusinessHours, TorExitNode, VpnDetected, HighVelocityAttempts }

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum RiskAction { Allow, MfaRecommended, MfaRequired, Deny }

impl RiskScore {
    pub fn compute(ctx: &RiskContext) -> Self {
        let identity = Self::identity_factor(ctx);
        let device = if ctx.known_device { 0.0 } else { 60.0 };
        let network = {
            let mut s = 0.0;
            if ctx.tor_exit_node { s += 95.0; }
            if ctx.vpn_detected && !ctx.known_location { s += 50.0; }
            if !ctx.known_location { s += 20.0; }
            s
        };
        let behavioral = {
            let h = ctx.time_of_day.hour();
            if !(6..22).contains(&h) { 40.0 } else if !(8..18).contains(&h) { 15.0 } else { 0.0 }
        };
        let mut flags = vec![];
        if !ctx.known_device { flags.push(RiskFlag::NewDevice); }
        if !ctx.known_location { flags.push(RiskFlag::NewLocation); }
        if ctx.tor_exit_node { flags.push(RiskFlag::TorExitNode); }
        if ctx.vpn_detected { flags.push(RiskFlag::VpnDetected); }
        if ctx.login_attempts_last_hour > 10 { flags.push(RiskFlag::HighVelocityAttempts); }
        let h = ctx.time_of_day.hour();
        if !(8..18).contains(&h) { flags.push(RiskFlag::OutsideBusinessHours); }

        let mut total = identity * 0.30 + device * 0.30 + network * 0.20 + behavioral * 0.20;
        if ctx.tor_exit_node { total = total.max(85.0); }
        total = total.clamp(0.0, 100.0);
        RiskScore { total, identity_score: identity, device_score: device,
                    network_score: network, behavioral_score: behavioral, flags }
    }

    pub fn action(&self) -> RiskAction {
        if self.total < 25.0 { RiskAction::Allow }
        else if self.total < 50.0 { RiskAction::MfaRecommended }
        else if self.total < 75.0 { RiskAction::MfaRequired }
        else { RiskAction::Deny }
    }

    fn identity_factor(ctx: &RiskContext) -> f64 {
        if ctx.login_attempts_last_hour > 20 { 80.0 }
        else if ctx.login_attempts_last_hour > 10 { 50.0 }
        else if ctx.login_attempts_last_hour > 5 { 25.0 }
        else { 0.0 }
    }
}

#[cfg(test)]
mod tests {
    use super::*; use chrono::NaiveTime;
    fn ctx() -> RiskContext { RiskContext {
        user_id: "t".into(), client_ip: "10.0.0.1".into(), device_fingerprint: "fp".into(),
        time_of_day: NaiveTime::from_hms_opt(14,0,0).unwrap(),
        known_device: true, known_location: true, vpn_detected: false,
        tor_exit_node: false, login_attempts_last_hour: 0,
    }}

    #[test] fn test_low() { assert!(RiskScore::compute(&ctx()).total < 25.0); }
    #[test] fn test_tor() {
        let mut c = ctx(); c.tor_exit_node = true; c.known_device = false; c.known_location = false;
        assert_eq!(RiskScore::compute(&c).action(), RiskAction::Deny);
    }
    #[test] fn test_madrugada() {
        let mut c = ctx(); c.known_device = false;
        c.time_of_day = NaiveTime::from_hms_opt(3,0,0).unwrap();
        let a = RiskScore::compute(&c).action();
        assert!(matches!(a, RiskAction::MfaRecommended | RiskAction::MfaRequired));
    }
}
