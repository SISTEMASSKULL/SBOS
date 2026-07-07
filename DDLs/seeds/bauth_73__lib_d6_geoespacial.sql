-- =============================================================================
-- bauth_73__lib_d6_geoespacial.sql — Políticas geoespaciales D6 (incremento)
-- =============================================================================
-- Propósito  : Agregar políticas de autenticación del dominio geoespacial
--              directamente a cfg_policy_library (sin depender de JSON fuente).
-- Normas     : GDPR (UE) 2016/679 — Capítulo V (transferencias internacionales)
--              NIS2 Directive (UE) 2022/2555 — Restricciones geográficas
--              Bolivia Ley 164 (2011) — Soberanía digital
--              Bolivia DS 1793 (2013) — Reglamento datos personales
--              FATF Recommendation 10, 15, 16 — Evaluación riesgo geográfico
--              ISO 27701:2019 — Privacy Information Management (geolocalización)
--              NIST SP 800-53 Rev.5 SC-7 — Boundary Protection
--              NIST SP 800-207 — Zero Trust Network Access (ZTNA geográfico)
--              OWASP Top 10:2021 A05 — Security Misconfiguration (geofencing)
-- Fuente     : Investigación 2025-2026 (normas vigentes hasta 2026)
-- Idempotente: Sí — ON CONFLICT (json_path) DO NOTHING
-- =============================================================================
SET lock_timeout = '5s';

INSERT INTO bauth.cfg_policy_library (
  section_name, parent_path, json_path, depth, array_index, node_type,
  semantic_type, domain_map, source, standard_ref, compliance_ref,
  content, content_en, content_es,
  enforcement, risk_level, lifecycle,
  assurance_level, mfa_required, phishing_resistant
) VALUES

-- 1. Geofencing — Restricción de acceso por zona geográfica
(
  'geofencing_access_control', NULL, 'd6_geospatial_ext.geofencing_access_control',
  1, 0, 'policy', 'policy', ARRAY['D6'], 'd6_geospatial_ext',
  'NIST SP 800-207', ARRAY['NIST SP 800-207 §2.3', 'NIST SP 800-53 Rev.5 AC-2', 'GDPR Art.25 (Privacy by Design)'],
  '{"title":"Geofencing Access Control Policy","description":"SBOS enforces location-based access control using IP geolocation and optionally GPS coordinates. Three-tier policy: (1) ALLOW zone: Bolivia and adjacent countries (Chile, Peru, Argentina, Brazil, Paraguay) — normal authentication applies, (2) ELEVATED zone: EU, USA, Canada, APAC — requires AAL2+ and step-up challenge, (3) BLOCK zone: FATF high-risk jurisdictions, OFAC sanctioned countries — access denied regardless of credentials. IP geolocation database: MaxMind GeoLite2 or equivalent (updated weekly). VPN/proxy/Tor exit node detection: mandatory block. GPS coordinates accepted for mobile apps only with OS-level attestation (Play Integrity API / Apple DeviceCheck).","zones":{"allow":["BO","CL","PE","AR","BR","PY"],"elevated":["EU","US","CA","AU","JP","SG"],"block":["FATF_HIGH_RISK","OFAC_SANCTIONED"]},"vpn_tor_detection":"mandatory_block","geolocation_db":"MaxMind_GeoLite2","gps_mobile_only":true,"gps_attestation":"Play_Integrity_or_DeviceCheck"}',
  '{"title":"Geofencing Access Control Policy","description":"Location-based access: ALLOW (Bolivia/adjacent), ELEVATED (EU/US/APAC needs AAL2+), BLOCK (FATF high-risk/OFAC). VPN/Tor mandatory block. MaxMind GeoLite2 geolocation.","zones":{"allow":["BO","CL","PE","AR","BR","PY"],"elevated":["EU","US","CA"],"block":["FATF_HIGH_RISK","OFAC_SANCTIONED"]}}',
  '{"titulo":"Política Control Acceso Geofencing","descripcion":"Acceso basado en ubicación: PERMITIR (Bolivia/países adyacentes), ELEVADO (UE/EEUU/APAC requiere AAL2+), BLOQUEAR (alto riesgo FATF/OFAC). Bloqueo obligatorio VPN/Tor. Geolocalización MaxMind GeoLite2.","zonas":{"permitir":["BO","CL","PE","AR","BR","PY"],"elevado":["UE","US","CA"],"bloquear":["FATF_ALTO_RIESGO","OFAC_SANCIONADOS"]}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 2. Bolivia Ley 164 — Soberanía digital y residencia de datos
(
  'bolivia_ley164_digital_sovereignty', NULL, 'd6_geospatial_ext.bolivia_ley164_digital_sovereignty',
  1, 0, 'policy', 'standard', ARRAY['D6'], 'd6_geospatial_ext',
  'Bolivia Ley 164 (2011)', ARRAY['Bolivia Ley 164 Art.5', 'Bolivia Ley 164 Art.75', 'Bolivia DS 1793 Art.9', 'Bolivia DS 3251 Art.4'],
  '{"title":"Bolivia Ley 164 — Digital Sovereignty and Data Residency","description":"Bolivia Ley 164 (Ley General de Telecomunicaciones, Tecnologías de Información y Comunicación) establishes digital sovereignty principles. For SBOS: (1) Personal data of Bolivian citizens must be stored primarily within Bolivia (data residency), (2) Processing of data outside Bolivia requires explicit consent and ATIC notification, (3) Electronic signatures on Bolivian administrative documents must use ADSIB-certified certificates, (4) Government entities must use national platforms when available, (5) SBOS metadata about Bolivian users must not leave Bolivia without legal basis. Replication to foreign cloud: prohibited for government tenants without ATIC authorization.","requirements":{"bolivian_data_primary_residency":"Bolivia","cross_border_consent":true,"atic_notification_required":true,"adsib_signature_mandatory_gov":true,"national_platform_preference":true,"government_tenant_restriction":"no_foreign_cloud_without_ATIC"},"exceptions":["GDPR_SCC","bilateral_treaty","explicit_consent"]}',
  '{"title":"Bolivia Ley 164 Digital Sovereignty","description":"Bolivia Ley 164 requires data residency in Bolivia for Bolivian citizens data, ADSIB signatures for government documents, ATIC notification for cross-border data transfer. Government tenants cannot use foreign cloud without ATIC authorization.","requirements":{"data_residency":"Bolivia","adsib_signature_mandatory_gov":true,"atic_notification_required":true}}',
  '{"titulo":"Soberanía Digital Bolivia Ley 164","descripcion":"Ley 164 Bolivia requiere residencia de datos en Bolivia para datos de ciudadanos bolivianos, firmas ADSIB para documentos gubernamentales, notificación ATIC para transferencia transfronteriza. Los tenants gubernamentales no pueden usar nube extranjera sin autorización ATIC.","requisitos":{"residencia_datos":"Bolivia","firma_adsib_obligatoria_gov":true,"notificacion_atic_requerida":true}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 3. GDPR Capítulo V — Transferencias internacionales de datos
(
  'gdpr_chapter_v_international_transfer', NULL, 'd6_geospatial_ext.gdpr_chapter_v_international_transfer',
  1, 0, 'policy', 'standard', ARRAY['D6'], 'd6_geospatial_ext',
  'GDPR (UE) 2016/679', ARRAY['GDPR Art.44', 'GDPR Art.46(2)(c)', 'GDPR Art.49', 'EDPB Recommendations 01/2020'],
  '{"title":"GDPR Chapter V — International Data Transfers","description":"Transfers of personal data of EU/EEA residents processed in SBOS to countries outside the EU/EEA require adequate protection per GDPR Chapter V. Lawful mechanisms: (1) Adequacy decision (EC Decision) for Bolivia not yet adopted — SCCs mandatory, (2) Standard Contractual Clauses (SCCs) 2021 — implemented in all third-party contracts, (3) Binding Corporate Rules (BCR) — for intra-group transfers, (4) Derogations per Art.49: explicit consent, contract necessity, vital interests. SBOS authentication events involving EU residents must be geo-tagged. Cross-border data flows logged for GDPR compliance audit.","mechanisms":{"scc_2021":"mandatory_for_bolivia","adequacy_decision":"pending","bcr":"for_group_entities","derogations":"art49_explicit_consent"},"logging":{"geo_tag_eu_residents":true,"audit_trail":true,"dpo_notification_threshold_gb":0.5}}',
  '{"title":"GDPR Chapter V International Transfers","description":"EU/EEA personal data transfers outside EU require GDPR Chapter V compliance. Bolivia: no adequacy decision — SCCs 2021 mandatory. EU resident authentication events geo-tagged and logged for GDPR audit.","mechanisms":{"scc_2021":"mandatory_for_bolivia","derogations":"art49_explicit_consent"}}',
  '{"titulo":"Transferencias Internacionales GDPR Capítulo V","descripcion":"Las transferencias de datos personales de residentes UE/EEE fuera de la UE requieren cumplimiento GDPR Capítulo V. Bolivia: sin decisión de adecuación — SCCs 2021 obligatorias. Eventos de autenticación de residentes UE etiquetados geográficamente y registrados para auditoría GDPR.","mecanismos":{"scc_2021":"obligatorias_para_bolivia","derogaciones":"art49_consentimiento_explicito"}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 4. NIS2 — Restricción de acceso a infraestructura crítica por origen geográfico
(
  'nis2_geographic_restriction_critical', NULL, 'd6_geospatial_ext.nis2_geographic_restriction_critical',
  1, 0, 'policy', 'standard', ARRAY['D6','D7'], 'd6_geospatial_ext',
  'NIS2 Directive (UE) 2022/2555', ARRAY['NIS2 Art.21(2)(b)', 'NIS2 Art.21(2)(i)', 'ENISA Good Practices 2022 §4.2'],
  '{"title":"NIS2 Geographic Restriction for Critical Infrastructure","description":"The NIS2 Directive requires essential and important entities to implement supply chain security measures including geographic restrictions on access to critical systems. For SBOS essential entity deployments: (1) Administrative access to critical infrastructure (IdP, key management, audit) restricted to EU/EEA or explicitly approved countries, (2) Network access from high-risk geographic zones to management interfaces: denied by default, (3) Third-party remote support from non-EU suppliers: requires additional approval and enhanced monitoring, (4) Incident reporting to national CSIRT must include geographic information of attack origin, (5) Annual supply chain risk assessment including geographic threat landscape.","requirements":{"admin_access_zones":"EU_EEA_or_approved","high_risk_zones_default":"deny","third_party_noneu_support":"approval_required","incident_report_geo_info":true,"annual_supply_chain_review":true},"reporting_obligation_hours":24}',
  '{"title":"NIS2 Geographic Restriction for Critical Infrastructure","description":"NIS2 Directive requires geographic restrictions: admin access to EU/EEA+ approved, high-risk zones denied by default, non-EU third-party support needs approval. Incident reporting includes geographic attack origin.","requirements":{"admin_access_zones":"EU_EEA_or_approved","high_risk_zones_default":"deny"}}',
  '{"titulo":"Restricción Geográfica NIS2 para Infraestructura Crítica","descripcion":"La Directiva NIS2 requiere restricciones geográficas: acceso admin limitado a UE/EEE+ aprobados, zonas de alto riesgo denegadas por defecto, soporte de terceros no-UE requiere aprobación. Los informes de incidentes incluyen origen geográfico del ataque.","requisitos":{"zonas_acceso_admin":"UE_EEE_o_aprobadas","zonas_alto_riesgo_defecto":"denegar"}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 5. FATF — Evaluación de riesgo geográfico (KYC/AML)
(
  'fatf_geographic_risk_kyc', NULL, 'd6_geospatial_ext.fatf_geographic_risk_kyc',
  1, 0, 'policy', 'standard', ARRAY['D6','D3'], 'd6_geospatial_ext',
  'FATF Recommendations 2023', ARRAY['FATF Recommendation 10', 'FATF Recommendation 15', 'FATF Recommendation 16', 'Bolivia Ley 393 Servicios Financieros Art.124'],
  '{"title":"FATF Geographic Risk Assessment — KYC/AML","description":"SBOS financial modules must assess geographic risk as part of KYC (Know Your Customer) and AML (Anti-Money Laundering) compliance. FATF high-risk jurisdictions require enhanced due diligence (EDD). Policies: (1) Authentication from FATF black/grey list countries triggers EDD workflow, (2) Financial transactions with counterparties in high-risk jurisdictions require additional authentication step, (3) Geographic risk score integrated in the authentication risk engine, (4) FATF list updated quarterly in SBOS geo-risk database, (5) PEP (Politically Exposed Persons) from high-risk countries: AAL3 required, (6) Correspondent banking relationships: geographic origin logged per FATF Rec.16.","risk_levels":{"fatf_blacklist":"BLOCK_or_manual_review","fatf_greylist":"EDD_required","pep_high_risk_country":"AAL3","high_risk_threshold_usd":10000},"update_frequency":"quarterly"}',
  '{"title":"FATF Geographic Risk Assessment KYC/AML","description":"FATF high-risk country access triggers EDD. FATF blacklist blocks or requires manual review, greylist requires EDD. PEP from high-risk countries needs AAL3. Quarterly FATF list updates.","risk_levels":{"fatf_blacklist":"BLOCK_or_manual_review","fatf_greylist":"EDD_required","pep_high_risk_country":"AAL3"}}',
  '{"titulo":"Evaluación Riesgo Geográfico FATF KYC/AML","descripcion":"El acceso desde países de alto riesgo FATF activa DDR. Lista negra FATF bloquea o requiere revisión manual, lista gris requiere DDR. PEP de países alto riesgo necesita AAL3. Actualizaciones FATF trimestrales.","niveles_riesgo":{"lista_negra_fatf":"BLOQUEAR_o_revision_manual","lista_gris_fatf":"DDR_requerida","pep_pais_alto_riesgo":"AAL3"}}',
  'mandatory', 'critical', 'active', 'AAL2', true, false
),

-- 6. Protección de privacidad de datos de geolocalización
(
  'geolocation_privacy_protection', NULL, 'd6_geospatial_ext.geolocation_privacy_protection',
  1, 0, 'policy', 'standard', ARRAY['D6'], 'd6_geospatial_ext',
  'ISO 27701:2019', ARRAY['ISO 27701:2019 §7.2.3', 'GDPR Art.5(1)(c) (data minimization)', 'GDPR Art.9 (special category)', 'NIST SP 800-188 §3.4'],
  '{"title":"Geolocation Data Privacy Protection","description":"Geolocation data collected by SBOS during authentication is personal data under GDPR and requires specific protections. Policy: (1) Collect minimum necessary geolocation precision (country/region sufficient for most decisions — not GPS), (2) Geolocation data retention: 90 days for authentication logs, 7 years for audit trail, (3) GPS coordinates (mobile): collected only with explicit consent, stored hashed, precision reduced to ±1km for non-forensic purposes, (4) IP geolocation: considered less precise — no sole reliance on IP for location decisions, (5) User right to access/delete their location history (GDPR Art.17), (6) Geolocation data must not be sold or shared with third parties for advertising, (7) Cross-border geolocation data flows documented in ROPA (Record of Processing Activities).","data_minimization":{"country_region":"default","gps":"explicit_consent_only","gps_precision_non_forensic_km":1},"retention_days":{"auth_logs":90,"audit_trail":2555},"user_rights":["access","deletion","portability"],"no_advertising_use":true}',
  '{"title":"Geolocation Privacy Protection","description":"Geolocation data minimization: country/region default, GPS with explicit consent only. 90-day auth log retention, 7-year audit trail. User rights: access, deletion, portability. No advertising use.","data_minimization":{"country_region":"default","gps":"explicit_consent_only"}}',
  '{"titulo":"Protección Privacidad Datos Geolocalización","descripcion":"Minimización datos geolocalización: país/región por defecto, GPS solo con consentimiento explícito. Retención 90 días logs auth, 7 años pista auditoría. Derechos usuario: acceso, eliminación, portabilidad. Sin uso publicitario.","minimizacion_datos":{"pais_region":"defecto","gps":"solo_consentimiento_explicito"}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
),

-- 7. Detección de ubicación anómala (impossible travel)
(
  'impossible_travel_detection', NULL, 'd6_geospatial_ext.impossible_travel_detection',
  1, 0, 'policy', 'policy', ARRAY['D6','D8'], 'd6_geospatial_ext',
  'NIST SP 800-207', ARRAY['NIST SP 800-207 §2.3', 'NIST SP 800-53 Rev.5 SI-4', 'OWASP ASVS v5.0 §7.4.3'],
  '{"title":"Impossible Travel Detection Policy","description":"SBOS detects physically impossible geographic transitions between authentication events (impossible travel). Algorithm: if a user authenticates from Location A, and a subsequent authentication from Location B occurs within time T such that T < (distance(A,B) / max_travel_speed), the event is flagged. Policy: (1) Max assumed travel speed: 1,000 km/h (commercial aviation), (2) Action on detection: require step-up authentication (add factor), alert SOC, log security event, (3) Threshold for automatic block: <30 min travel time for intercontinental distances, (4) VPN adjustment: if VPN provider confirmed, reduce sensitivity (geographic inaccuracy expected), (5) False positive handling: user can self-explain with 48-hour window, (6) Consecutive anomalies (3+): temporary account lock + CISO notification.","algorithm":{"max_speed_kmh":1000,"step_up_required":true,"soc_alert":true,"auto_block_threshold_min":30,"vpn_reduced_sensitivity":true},"false_positive_window_hours":48,"lock_threshold_anomalies":3}',
  '{"title":"Impossible Travel Detection Policy","description":"Detects impossible geographic transitions. 1000 km/h max speed assumption. Step-up required on detection, SOC alert, auto-block for <30min intercontinental. VPN reduces sensitivity. 3 anomalies = account lock.","algorithm":{"max_speed_kmh":1000,"step_up_required":true,"auto_block_threshold_min":30}}',
  '{"titulo":"Política Detección Viaje Imposible","descripcion":"Detecta transiciones geográficas físicamente imposibles. Velocidad máxima asumida 1000 km/h. Se requiere step-up al detectar, alerta SOC, bloqueo automático para <30min intercontinental. VPN reduce sensibilidad. 3 anomalías = bloqueo cuenta.","algoritmo":{"velocidad_max_kmh":1000,"step_up_requerido":true,"umbral_bloqueo_auto_min":30}}',
  'mandatory', 'high', 'active', 'AAL2', true, false
),

-- 8. Residencia de datos por sector en Bolivia
(
  'bolivia_data_residency_by_sector', NULL, 'd6_geospatial_ext.bolivia_data_residency_by_sector',
  1, 0, 'policy', 'standard', ARRAY['D6'], 'd6_geospatial_ext',
  'Bolivia DS 1793 (2013)', ARRAY['Bolivia DS 1793 Art.9-15', 'Bolivia AGETIC Resolución Ministerial 001/2022', 'Bolivia DS 3251 Art.4-8'],
  '{"title":"Bolivia Data Residency by Sector","description":"Bolivia establishes sector-specific data residency requirements. Requirements for SBOS: (1) Banking/Financial: data must reside on servers in Bolivia per ASFI Circular RE-001/2020 — only operational replicas may be in MERCOSUR countries, (2) Government/Public sector: data exclusively in Bolivia, no exceptions without AGETIC authorization, (3) Telecommunications: core network data in Bolivia per ATIC regulations, (4) Health: patient data in Bolivia per MINSALUD regulations, (5) Education: student records in Bolivia per Ministerio de Educación regulations. SBOS server deployment must map tenant type to residency requirement.","sectors":{"banking":{"primary":"Bolivia","replicas":["MERCOSUR"],"authority":"ASFI"},"government":{"primary":"Bolivia","replicas":"none_without_AGETIC","authority":"AGETIC"},"telecom":{"primary":"Bolivia","authority":"ATIC"},"health":{"primary":"Bolivia","authority":"MINSALUD"},"education":{"primary":"Bolivia","authority":"MinEducacion"}},"enforcement_mechanism":"tenant_type_mapping"}',
  '{"title":"Bolivia Data Residency by Sector","description":"Bolivia sector residency: Banking (ASFI) — Bolivia primary + MERCOSUR replicas; Government (AGETIC) — Bolivia only; Telecom (ATIC), Health (MINSALUD), Education — Bolivia only. SBOS maps tenant type to residency rules.","sectors":{"banking":{"primary":"Bolivia","replicas":["MERCOSUR"]},"government":{"primary":"Bolivia","replicas":"none_without_AGETIC"}}}',
  '{"titulo":"Residencia Datos por Sector en Bolivia","descripcion":"Residencia por sector Bolivia: Banca (ASFI) — Bolivia principal + réplicas MERCOSUR; Gobierno (AGETIC) — solo Bolivia; Telecom (ATIC), Salud (MINSALUD), Educación — solo Bolivia. SBOS mapea tipo tenant a reglas de residencia.","sectores":{"banca":{"principal":"Bolivia","replicas":["MERCOSUR"]},"gobierno":{"principal":"Bolivia","replicas":"ninguna_sin_AGETIC"}}}',
  'mandatory', 'high', 'active', 'AAL1', false, false
)

ON CONFLICT (json_path) DO NOTHING;

SELECT COUNT(*) AS politicas_d6_incremento_insertadas FROM bauth.cfg_policy_library WHERE source = 'd6_geospatial_ext';
