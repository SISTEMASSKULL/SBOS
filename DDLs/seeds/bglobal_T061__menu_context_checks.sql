-- =============================================================================
-- SEED: bglobal_T061__menu_context_checks.sql
-- Tablas : bglobal.menu_context · bglobal.menu_item
-- Versión: 3.1.0
-- Origen : CHECK = ANY(ARRAY[...]) de SBOSDB — 261 ENUMs implícitos
-- Nota   : Se ejecuta DESPUÉS de T060 (no trunca, solo inserta)
-- Codes  : {dominio}.{entidad}.{atributo} — trazables al modelo de datos
-- =============================================================================


INSERT INTO bglobal.menu_context (code, name, menu_type, description, is_active, sort_order)
VALUES
  ('auth.intento.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_aal_outcome] — bauth.auth_attempt_log.outcome; bauth.auth_attempt_log_2026_07.outcome; bauth.auth_attempt_log_2026_08.outcome; bauth.auth_attempt_log_2026_09.outcome', true, 1010),
  ('auth.cumplimiento.nivel_cobertura', '{"es": "Nivel de cobertura", "en": "Coverage Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_acm_cov] — bauth.auth_compliance_map.coverage_level', true, 1020),
  ('auth.credencial.nivel_aal', '{"es": "Nivel de garantía (AAL)", "en": "Loa Provided"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ac_loa] — bauth.auth_credential.loa_provided; bauth.auth_federation_protocol.aal_max; bauth.auth_method.loa_provided; bauth.auth_policy.loa_required', true, 1030),
  ('auth.credencial.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ac_status] — bauth.auth_credential.status', true, 1040),
  ('auth.fido2.formato_atestacion', '{"es": "Formato de atestación", "en": "Attestation Fmt"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_af2_fmt] — bauth.auth_credential_fido2.attestation_fmt', true, 1050),
  ('auth.secreto.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_acs_type] — bauth.auth_credential_secret.type', true, 1060),
  ('auth.x509.origen', '{"es": "Origen", "en": "Origin"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ax509_origin] — bauth.auth_credential_x509.origin', true, 1070),
  ('auth.cripto.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_aca_status] — bauth.auth_crypto_algorithm.status', true, 1080),
  ('auth.cripto.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_aca_type] — bauth.auth_crypto_algorithm.type', true, 1090),
  ('auth.dispositivo.categoria', '{"es": "Categoría", "en": "Category"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ad_cat] — bauth.auth_device.category', true, 1100),
  ('auth.dispositivo.version_osdp', '{"es": "Versión OSDP (protocolo lector físico)", "en": "Osdp Version"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ad_osdp] — bauth.auth_device.osdp_version', true, 1110),
  ('auth.dispositivo.plataforma', '{"es": "Plataforma", "en": "Platform"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ad_plat] — bauth.auth_device.platform', true, 1120),
  ('auth.dispositivo.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ad_status] — bauth.auth_device.status', true, 1130),
  ('auth.dispositivo.confianza', '{"es": "Nivel de confianza", "en": "Trust Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ad_trust] — bauth.auth_device.trust_level', true, 1140),
  ('auth.vinculo_disp.tipo_vinculo', '{"es": "Tipo de vínculo", "en": "Binding Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_adcb_type] — bauth.auth_device_credential_binding.binding_type', true, 1150),
  ('auth.postura_disp.cumplimiento', '{"es": "Estado de cumplimiento", "en": "Compliance Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_adp_comp] — bauth.auth_device_posture.compliance_status', true, 1160),
  ('auth.postura_disp.mdm', '{"es": "Cumplimiento MDM", "en": "Mdm Compliance"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_adp_mdm] — bauth.auth_device_posture.mdm_compliance', true, 1170),
  ('auth.postura_disp.fuente_postura', '{"es": "Fuente de postura", "en": "Posture Source"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_adp_src] — bauth.auth_device_posture.posture_source', true, 1180),
  ('auth.federacion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_afp_status] — bauth.auth_federation_protocol.status', true, 1190),
  ('auth.metodo.categoria', '{"es": "Categoría", "en": "Category"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_am_cat] — bauth.auth_method.category', true, 1200),
  ('auth.metodo.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_am_status] — bauth.auth_method.status', true, 1210),
  ('auth.saga.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_asc_status] — bauth.auth_saga_catalog.status', true, 1220),
  ('blk.cuenta.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_bac_status] — bauth.blk_account.status', true, 1230),
  ('blk.ancla.cadena', '{"es": "Cadena", "en": "Chain"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ba_chain] — bauth.blk_anchor.chain', true, 1240),
  ('blk.ancla.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ba_status] — bauth.blk_anchor.status', true, 1250),
  ('blk.merkle.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_bmb_status] — bauth.blk_merkle_batch.status', true, 1260),
  ('blk.reconciliacion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_br_status] — bauth.blk_reconciliation.status', true, 1270),
  ('cfg.politica.factor_auth', '{"es": "Factor de autenticación", "en": "Auth Factor"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_auth_factor_check] — bauth.cfg_policy_library.auth_factor', true, 1280),
  ('cfg.politica.aplicacion', '{"es": "Modo de aplicación", "en": "Enforcement"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_enforcement_check] — bauth.cfg_policy_library.enforcement', true, 1290),
  ('cfg.politica.ciclo_vida', '{"es": "Ciclo de vida", "en": "Lifecycle"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_lifecycle_check] — bauth.cfg_policy_library.lifecycle', true, 1300),
  ('cfg.politica.tipo_nodo', '{"es": "Tipo de nodo", "en": "Node Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_node_type_check] — bauth.cfg_policy_library.node_type', true, 1310),
  ('cfg.politica.nivel_riesgo', '{"es": "Nivel de riesgo", "en": "Risk Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_risk_level_check] — bauth.cfg_policy_library.risk_level', true, 1320),
  ('cfg.politica.tipo_semantico', '{"es": "Tipo semántico", "en": "Semantic Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [cfg_policy_library_semantic_type_check] — bauth.cfg_policy_library.semantic_type', true, 1330),
  ('fed.cliente.perfil_fapi', '{"es": "Perfil FAPI", "en": "Fapi Profile"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fc_fapi] — bauth.fed_client.fapi_profile', true, 1340),
  ('fed.cliente.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fc_status] — bauth.fed_client.status; bauth.idn_global_admin.status', true, 1350),
  ('fed.cliente.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fc_type] — bauth.fed_client.type', true, 1360),
  ('fed.proveedor.nivel_fal', '{"es": "Nivel FAL", "en": "Fal"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fpe_fal] — bauth.fed_provider_ext.fal; bauth.idn_tenant_fal_config.fal_level', true, 1370),
  ('fed.proveedor.protocolo', '{"es": "Protocolo", "en": "Protocol"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fpe_proto] — bauth.fed_provider_ext.protocol', true, 1380),
  ('fed.token.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fti_type] — bauth.fed_token_issued.type; bauth.fed_token_issued_2026_07.type; bauth.fed_token_issued_2026_08.type; bauth.fed_token_issued_2026_09.type', true, 1390),
  ('acceso.contrato.tipo_acceso', '{"es": "Tipo de acceso", "en": "Access Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iac_access_type] — bauth.idn_access_contract.access_type', true, 1400),
  ('acceso.contrato.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iac_status] — bauth.idn_access_contract.status', true, 1410),
  ('registry.attr_schema.clasificacion', '{"es": "Clasificación", "en": "Classification"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idras_clas] — bauth.idn_attribute_schema.classification; bauth.idn_identity_attribute.classification', true, 1420),
  ('registry.attr_schema.mutabilidad', '{"es": "Mutabilidad", "en": "Mutability"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idras_mut] — bauth.idn_attribute_schema.mutability', true, 1430),
  ('registry.attr_schema.campo_retorno', '{"es": "Campo retornado", "en": "Returned"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idras_ret] — bauth.idn_attribute_schema.returned; bauth.idn_identity_attribute.returned; bauth.idn_registry_attribute_schema.returned', true, 1440),
  ('registry.attr_schema.tipo_dato', '{"es": "Tipo de dato", "en": "Data Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idras_tipo] — bauth.idn_attribute_schema.data_type', true, 1450),
  ('d11.auditoria.codigo_dominio', '{"es": "Código de dominio", "en": "Domain Code"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_event_log_domain_code_check] — bauth.idn_audit_event_log.domain_code; bauth.idn_audit_event_log_2026_07.domain_code; bauth.idn_audit_event_log_2026_08.domain_code; bauth.idn_audit_event_log_2026_09.domain_code', true, 1460),
  ('d11.auditoria.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_event_log_outcome_check] — bauth.idn_audit_event_log.outcome; bauth.idn_audit_event_log_2026_07.outcome; bauth.idn_audit_event_log_2026_08.outcome; bauth.idn_audit_event_log_2026_09.outcome', true, 1470),
  ('d11.auditoria.tipo_sujeto', '{"es": "Tipo de sujeto", "en": "Subject Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_event_log_subject_type_check] — bauth.idn_audit_event_log.subject_type; bauth.idn_audit_event_log_2026_07.subject_type; bauth.idn_audit_event_log_2026_08.subject_type; bauth.idn_audit_event_log_2026_09.subject_type', true, 1480),
  ('d11.retencion.accion_expiracion', '{"es": "Acción al expirar", "en": "Expiration Action"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_retention_policy_expiration_action_check] — bauth.idn_audit_retention_policy.expiration_action', true, 1490),
  ('d11.siem.formato_log', '{"es": "Formato de log", "en": "Log Format"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_siem_target_log_format_check] — bauth.idn_audit_siem_target.log_format', true, 1500),
  ('d11.siem.tipo_protocolo', '{"es": "Tipo de protocolo", "en": "Protocol Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_audit_siem_target_protocol_type_check] — bauth.idn_audit_siem_target.protocol_type', true, 1510),
  ('d05.inscripcion.tipo_biometrico', '{"es": "Tipo biométrico", "en": "Biometric Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_enrollment_biometric_type_check] — bauth.idn_biometric_enrollment.biometric_type; bauth.idn_biometric_pad_policy.biometric_type; bauth.idn_biometric_quality_policy.biometric_type', true, 1520),
  ('d05.inscripcion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_enrollment_status_check] — bauth.idn_biometric_enrollment.status; bauth.idn_delegation_grant.status; bauth.idn_identity_vc.status; bauth.idn_physical_access_credential.status', true, 1530),
  ('d05.identificacion.resultado', '{"es": "Resultado", "en": "Result"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_identification_log_result_check] — bauth.idn_biometric_identification_log.result; bauth.idn_biometric_identification_log_default.result', true, 1540),
  ('d05.pad.accion_fallo', '{"es": "Acción en fallo", "en": "Fail Action"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_pad_policy_fail_action_check] — bauth.idn_biometric_pad_policy.fail_action', true, 1550),
  ('d05.pad.nivel_pad', '{"es": "Nivel PAD (anti-spoofing)", "en": "Pad Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_pad_policy_pad_level_check] — bauth.idn_biometric_pad_policy.pad_level', true, 1560),
  ('d05.pad.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_pad_policy_status_check] — bauth.idn_biometric_pad_policy.status; bauth.idn_biometric_quality_policy.status; bauth.idn_financial_sod_rule.status; bauth.idn_geospatial_data_residency.status', true, 1570),
  ('d05.revocacion_bio.motivo_revocacion', '{"es": "Motivo de revocación", "en": "Revocation Reason"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_revocation_revocation_reason_check] — bauth.idn_biometric_revocation.revocation_reason', true, 1580),
  ('d05.verificacion_bio.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_biometric_verification_log_outcome_check] — bauth.idn_biometric_verification_log.outcome; bauth.idn_biometric_verification_log_2026_07.outcome; bauth.idn_biometric_verification_log_2026_08.outcome; bauth.idn_biometric_verification_log_default.outcome', true, 1590),
  ('d12.ancla.tipo_evento_fuente', '{"es": "Tipo de evento fuente", "en": "Source Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_anchor_ext_source_event_type_check] — bauth.idn_blockchain_anchor_ext.source_event_type', true, 1600),
  ('d12.nodo.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_node_status_check] — bauth.idn_blockchain_node.status', true, 1610),
  ('d12.transaccion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_transaction_status_check] — bauth.idn_blockchain_transaction.status', true, 1620),
  ('d12.transaccion.tipo_tx', '{"es": "Tipo de transacción blockchain", "en": "Tx Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_transaction_tx_type_check] — bauth.idn_blockchain_transaction.tx_type', true, 1630),
  ('d12.wallet.cadena', '{"es": "Cadena", "en": "Chain"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_wallet_chain_check] — bauth.idn_blockchain_wallet.chain', true, 1640),
  ('d12.wallet.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_blockchain_wallet_status_check] — bauth.idn_blockchain_wallet.status', true, 1650),
  ('d09.revocacion_cred.motivo', '{"es": "Motivo", "en": "Motivo"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idcr_motivo] — bauth.idn_credencial_revocacion.motivo', true, 1660),
  ('d09.token.motivo_revocacion', '{"es": "Motivo de revocación", "en": "Revocation Reason"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_credential_token_issued_revocation_reason_check] — bauth.idn_credential_token_issued.revocation_reason; bauth.idn_credential_token_issued_2026_07.revocation_reason; bauth.idn_credential_token_issued_2026_08.revocation_reason; bauth.idn_credential_token_issued_2026_09.revocation_reason', true, 1670),
  ('d09.token.tipo_token', '{"es": "Tipo de token", "en": "Token Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_credential_token_issued_token_type_check] — bauth.idn_credential_token_issued.token_type; bauth.idn_credential_token_issued_2026_07.token_type; bauth.idn_credential_token_issued_2026_08.token_type; bauth.idn_credential_token_issued_2026_09.token_type', true, 1680),
  ('d10.delegacion.tipo_delegacion', '{"es": "Tipo de delegación", "en": "Delegation Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_delegation_grant_delegation_type_check] — bauth.idn_delegation_grant.delegation_type', true, 1690),
  ('d10.rar.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_delegation_rar_request_status_check] — bauth.idn_delegation_rar_request.status', true, 1700),
  ('d10.restriccion.tipo_restriccion', '{"es": "Tipo de restricción", "en": "Restriction Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_delegation_restriction_restriction_type_check] — bauth.idn_delegation_restriction.restriction_type', true, 1710),
  ('d10.uso_delegacion.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_delegation_usage_log_outcome_check] — bauth.idn_delegation_usage_log.outcome; bauth.idn_delegation_usage_log_2026_07.outcome; bauth.idn_delegation_usage_log_2026_08.outcome; bauth.idn_delegation_usage_log_default.outcome', true, 1720),
  ('identidad.did.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idd_status] — bauth.idn_did_document.status', true, 1730),
  ('privacidad.dpia_reg.estado', '{"es": "Estado", "en": "Estado"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idpia_estado] — bauth.idn_dpia_registro.estado', true, 1740),
  ('privacidad.dpia_reg.riesgo_residual', '{"es": "Riesgo residual (DPIA)", "en": "Riesgo Residual"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_idpia_riesgo] — bauth.idn_dpia_registro.riesgo_residual', true, 1750),
  ('d03.aprobacion.tipo_operacion', '{"es": "Tipo de operación", "en": "Operation Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_approval_operation_type_check] — bauth.idn_financial_approval.operation_type', true, 1760),
  ('d03.voto.decision', '{"es": "Decisión", "en": "Decision"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_approval_vote_decision_check] — bauth.idn_financial_approval_vote.decision', true, 1770),
  ('d03.fraude.tipo_alerta', '{"es": "Tipo de alerta de fraude", "en": "Alert Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_fraud_alert_alert_type_check] — bauth.idn_financial_fraud_alert.alert_type', true, 1780),
  ('d03.fraude.resultado', '{"es": "Resultado", "en": "Result"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_fraud_alert_result_check] — bauth.idn_financial_fraud_alert.result', true, 1790),
  ('d03.factura.estado_sin', '{"es": "Estado SIN Bolivia", "en": "Sin Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_invoice_auth_sin_status_check] — bauth.idn_financial_invoice_auth.sin_status', true, 1800),
  ('d03.limite.tipo_operacion', '{"es": "Tipo de operación", "en": "Operation Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_limit_operation_type_check] — bauth.idn_financial_limit.operation_type', true, 1810),
  ('d03.limite.alcance', '{"es": "Alcance", "en": "Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_limit_scope_check] — bauth.idn_financial_limit.scope', true, 1820),
  ('d03.limite.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_limit_status_check] — bauth.idn_financial_limit.status; bauth.idn_geospatial_geofence.status; bauth.idn_network_connection_policy.status; bauth.idn_network_dlp_policy.status', true, 1830),
  ('d03.reconciliacion.tipo_reconciliacion', '{"es": "Tipo de reconciliación", "en": "Reconciliation Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_reconciliation_reconciliation_type_check] — bauth.idn_financial_reconciliation.reconciliation_type', true, 1840),
  ('d03.reconciliacion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_reconciliation_status_check] — bauth.idn_financial_reconciliation.status', true, 1850),
  ('d03.reporte.tipo_reporte', '{"es": "Tipo de reporte", "en": "Report Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_report_report_type_check] — bauth.idn_financial_report.report_type', true, 1860),
  ('d03.reporte.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_report_status_check] — bauth.idn_financial_report.status', true, 1870),
  ('d03.sod.tipo_conflicto', '{"es": "Tipo de conflicto", "en": "Conflict Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_sod_rule_conflict_type_check] — bauth.idn_financial_sod_rule.conflict_type', true, 1880),
  ('d03.tpp.perfil_fapi', '{"es": "Perfil FAPI", "en": "Fapi Profile"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_tpp_consent_fapi_profile_check] — bauth.idn_financial_tpp_consent.fapi_profile', true, 1890),
  ('d03.tpp.revocado_por', '{"es": "Revocado por", "en": "Revoked By"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_financial_tpp_consent_revoked_by_check] — bauth.idn_financial_tpp_consent.revoked_by', true, 1900),
  ('d06.residencia.aplica_a', '{"es": "Aplica a", "en": "Apply To"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_data_residency_apply_to_check] — bauth.idn_geospatial_data_residency.apply_to', true, 1910),
  ('d06.residencia.accion_violacion', '{"es": "Acción en violación", "en": "Violation Action"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_data_residency_violation_action_check] — bauth.idn_geospatial_data_residency.violation_action', true, 1920),
  ('d06.geocerca.accion_dentro', '{"es": "Acción dentro de geocerca", "en": "Action Inside"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_geofence_action_inside_check] — bauth.idn_geospatial_geofence.action_inside', true, 1930),
  ('d06.geocerca.accion_fuera', '{"es": "Acción fuera de geocerca", "en": "Action Outside"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_geofence_action_outside_check] — bauth.idn_geospatial_geofence.action_outside; bauth.idn_geospatial_velocity_policy.action', true, 1940),
  ('d06.geocerca.tipo_geocerca', '{"es": "Tipo de geocerca", "en": "Fence Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_geofence_fence_type_check] — bauth.idn_geospatial_geofence.fence_type', true, 1950),
  ('d06.ubicacion.fuente_ubicacion', '{"es": "Fuente de ubicación", "en": "Location Source"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_geospatial_location_log_location_source_check] — bauth.idn_geospatial_location_log.location_source; bauth.idn_geospatial_location_log_2026_07.location_source; bauth.idn_geospatial_location_log_2026_08.location_source; bauth.idn_geospatial_location_log_default.location_source', true, 1960),
  ('d99.admin.rol_admin', '{"es": "Rol de administrador global", "en": "Admin Role"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_admin_admin_role_check] — bauth.idn_global_admin.admin_role', true, 1970),
  ('d99.cumplimiento.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_compliance_control_status_check] — bauth.idn_global_compliance_control.status', true, 1980),
  ('d99.cripto.familia_algoritmo', '{"es": "Familia de algoritmo", "en": "Algorithm Family"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_crypto_params_algorithm_family_check] — bauth.idn_global_crypto_params.algorithm_family', true, 1990),
  ('d99.hitl.tipo_entidad', '{"es": "Tipo de entidad afectada", "en": "Affected Entity Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_hitl_exception_affected_entity_type_check] — bauth.idn_global_hitl_exception.affected_entity_type', true, 2000),
  ('d99.hitl.tipo_excepcion', '{"es": "Tipo de excepción", "en": "Exception Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_hitl_exception_exception_type_check] — bauth.idn_global_hitl_exception.exception_type', true, 2010),
  ('d99.hitl.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_hitl_exception_status_check] — bauth.idn_global_hitl_exception.status', true, 2020),
  ('d99.notificacion.tipo_notificacion', '{"es": "Tipo de notificación", "en": "Notification Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_notification_notification_type_check] — bauth.idn_global_notification.notification_type', true, 2030),
  ('d99.notificacion.severidad', '{"es": "Severidad", "en": "Severity"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_notification_severity_check] — bauth.idn_global_notification.severity', true, 2040),
  ('d99.notificacion.alcance_destino', '{"es": "Alcance del destino", "en": "Target Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_notification_target_scope_check] — bauth.idn_global_notification.target_scope', true, 2050),
  ('d99.sbom.tipo_componente', '{"es": "Tipo de componente SBOM", "en": "Component Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_sbom_component_type_check] — bauth.idn_global_sbom.component_type', true, 2060),
  ('d99.sbom.nivel_riesgo', '{"es": "Nivel de riesgo", "en": "Risk Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_global_sbom_risk_level_check] — bauth.idn_global_sbom.risk_level', true, 2070),
  ('identidad.ciclo_vida.tipo_evento', '{"es": "Tipo de evento", "en": "Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ile_event_type] — bauth.idn_identidad_lifecycle_event.event_type', true, 2080),
  ('identidad.atributo.mutabilidad', '{"es": "Mutabilidad", "en": "Mutability"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iiattr_mutability] — bauth.idn_identity_attribute.mutability', true, 2090),
  ('identidad.atributo.unicidad', '{"es": "Unicidad del atributo", "en": "Uniqueness"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iiattr_uniqueness] — bauth.idn_identity_attribute.uniqueness', true, 2100),
  ('identidad.attr_historial.operacion', '{"es": "Operación", "en": "Operation"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iah_operation] — bauth.idn_identity_attribute_history.operation; bauth.idn_identity_attribute_history_2026_07.operation; bauth.idn_identity_attribute_history_2026_08.operation; bauth.idn_identity_attribute_history_2026_09.operation', true, 2110),
  ('identidad.consentimiento.via_otorgamiento', '{"es": "Otorgado vía", "en": "Granted Via"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ic_granted_via] — bauth.idn_identity_consent.granted_via', true, 2120),
  ('identidad.consentimiento.base_legal', '{"es": "Base legal (GDPR)", "en": "Legal Basis"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ic_legal_basis] — bauth.idn_identity_consent.legal_basis', true, 2130),
  ('identidad.consentimiento.via_retiro', '{"es": "Retirado vía", "en": "Withdrawn Via"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ic_withdrawn_via] — bauth.idn_identity_consent.withdrawn_via', true, 2140),
  ('identidad.entidad.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_identidad_entidad_status_check] — bauth.idn_identity_entity.status', true, 2150),
  ('identidad.proofing.nivel_eidas', '{"es": "Nivel eIDAS", "en": "Eidas Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iip_eidas] — bauth.idn_identity_proofing.eidas_level; bauth.idn_identity_vc.eidas_assurance_level', true, 2160),
  ('identidad.proofing.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ip_status] — bauth.idn_identity_proofing.status', true, 2170),
  ('identidad.proofing.tipo_proofing', '{"es": "Tipo de proofing", "en": "Proofing Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ip_type] — bauth.idn_identity_proofing.proofing_type', true, 2180),
  ('identidad.vc.tipo_vc_eidas', '{"es": "Tipo VC eIDAS", "en": "Eidas Vc Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ivc_eidas_type] — bauth.idn_identity_vc.eidas_vc_type', true, 2190),
  ('identidad.vc.formato_vc', '{"es": "Formato VC", "en": "Vc Format"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ivc_format] — bauth.idn_identity_vc.vc_format', true, 2200),
  ('d07.conexion.version_tls', '{"es": "Versión mínima TLS", "en": "Min Tls Version"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_connection_policy_min_tls_version_check] — bauth.idn_network_connection_policy.min_tls_version', true, 2210),
  ('d07.propagacion.formato_propagacion', '{"es": "Formato de propagación", "en": "Propagation Format"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_context_propagation_propagation_format_check] — bauth.idn_network_context_propagation.propagation_format', true, 2220),
  ('d07.dlp.accion_deteccion', '{"es": "Acción al detectar", "en": "Action On Match"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_dlp_policy_action_on_match_check] — bauth.idn_network_dlp_policy.action_on_match', true, 2230),
  ('d07.dpop.algoritmo', '{"es": "Algoritmo criptográfico", "en": "Alg"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_dpop_binding_alg_check] — bauth.idn_network_dpop_binding.alg', true, 2240),
  ('d07.postura_red.accion_fallo', '{"es": "Acción en fallo", "en": "Action On Fail"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_posture_policy_action_on_fail_check] — bauth.idn_network_posture_policy.action_on_fail', true, 2250),
  ('d07.tasa_limite.accion_exceso', '{"es": "Acción al exceder", "en": "Action On Exceed"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_rate_policy_action_on_exceed_check] — bauth.idn_network_rate_policy.action_on_exceed', true, 2260),
  ('d07.tasa_limite.alcance', '{"es": "Alcance", "en": "Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_rate_policy_scope_check] — bauth.idn_network_rate_policy.scope', true, 2270),
  ('d07.segmento.tipo_segmento', '{"es": "Tipo de segmento", "en": "Segment Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_segment_segment_type_check] — bauth.idn_network_segment.segment_type', true, 2280),
  ('d07.segmento.confianza', '{"es": "Nivel de confianza", "en": "Trust Level"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_network_segment_trust_level_check] — bauth.idn_network_segment.trust_level', true, 2290),
  ('d15.nhi_rotacion.accion_fallo', '{"es": "Acción en fallo", "en": "Fail Action"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_nhi_rotation_policy_fail_action_check] — bauth.idn_nhi_rotation_policy.fail_action', true, 2300),
  ('d15.nhi_rotacion.tipo_nhi', '{"es": "Tipo NHI", "en": "Nhi Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_nhi_rotation_policy_nhi_type_check] — bauth.idn_nhi_rotation_policy.nhi_type', true, 2310),
  ('d15.svid.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_nhi_svid_status_check] — bauth.idn_nhi_svid.status', true, 2320),
  ('d15.svid.tipo_svid', '{"es": "Tipo de SVID", "en": "Svid Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_nhi_svid_svid_type_check] — bauth.idn_nhi_svid.svid_type', true, 2330),
  ('d02.credencial_fisica.tipo_credencial', '{"es": "Tipo de credencial", "en": "Credential Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_credential_credential_type_check] — bauth.idn_physical_access_credential.credential_type', true, 2340),
  ('d02.emergencia.modo_puerta', '{"es": "Modo de puerta de emergencia", "en": "Door Mode"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_emergency_door_mode_check] — bauth.idn_physical_access_emergency.door_mode', true, 2350),
  ('d02.emergencia.tipo_emergencia', '{"es": "Tipo de emergencia física", "en": "Emergency Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_emergency_emergency_type_check] — bauth.idn_physical_access_emergency.emergency_type', true, 2360),
  ('d02.evento_fisico.tipo_credencial', '{"es": "Tipo de credencial", "en": "Credential Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_event_log_credential_type_check] — bauth.idn_physical_access_event_log.credential_type; bauth.idn_physical_access_event_log_2026_07.credential_type; bauth.idn_physical_access_event_log_2026_08.credential_type; bauth.idn_physical_access_event_log_default.credential_type', true, 2370),
  ('d02.evento_fisico.tipo_evento', '{"es": "Tipo de evento", "en": "Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_event_log_event_type_check] — bauth.idn_physical_access_event_log.event_type; bauth.idn_physical_access_event_log_2026_07.event_type; bauth.idn_physical_access_event_log_2026_08.event_type; bauth.idn_physical_access_event_log_default.event_type', true, 2380),
  ('d02.evento_fisico.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_event_log_outcome_check] — bauth.idn_physical_access_event_log.outcome; bauth.idn_physical_access_event_log_2026_07.outcome; bauth.idn_physical_access_event_log_2026_08.outcome; bauth.idn_physical_access_event_log_default.outcome', true, 2390),
  ('d02.ubicacion_fisica.tipo_ubicacion', '{"es": "Tipo de ubicación", "en": "Location Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_location_location_type_check] — bauth.idn_physical_access_location.location_type', true, 2400),
  ('d02.ubicacion_fisica.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_location_status_check] — bauth.idn_physical_access_location.status', true, 2410),
  ('d02.lector.direccion', '{"es": "Dirección", "en": "Direction"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_reader_direction_check] — bauth.idn_physical_access_reader.direction', true, 2420),
  ('d02.lector.protocolo', '{"es": "Protocolo", "en": "Protocol"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_reader_protocol_check] — bauth.idn_physical_access_reader.protocol', true, 2430),
  ('d02.lector.tipo_lector', '{"es": "Tipo de lector", "en": "Reader Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_reader_reader_type_check] — bauth.idn_physical_access_reader.reader_type', true, 2440),
  ('d02.lector.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_reader_status_check] — bauth.idn_physical_access_reader.status', true, 2450),
  ('d02.visita.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_physical_access_visit_status_check] — bauth.idn_physical_access_visit.status', true, 2460),
  ('cfg.nodo_politica.tamano_fuente', '{"es": "Token de tamaño de fuente", "en": "Font Size Token"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_itn_font_size_token] — bauth.idn_policy_node_type.font_size_token', true, 2470),
  ('registry.schema_attr.categoria', '{"es": "Categoría", "en": "Category"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_registry_attribute_schema_category_check] — bauth.idn_registry_attribute_schema.category', true, 2480),
  ('registry.schema_attr.clasificacion', '{"es": "Clasificación", "en": "Classification"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_registry_attribute_schema_classification_check] — bauth.idn_registry_attribute_schema.classification', true, 2490),
  ('registry.schema_attr.tipo_dato', '{"es": "Tipo de dato", "en": "Data Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_registry_attribute_schema_data_type_check] — bauth.idn_registry_attribute_schema.data_type', true, 2500),
  ('registry.schema_attr.mutabilidad', '{"es": "Mutabilidad", "en": "Mutability"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_registry_attribute_schema_mutability_check] — bauth.idn_registry_attribute_schema.mutability', true, 2510),
  ('registry.schema_attr.fuente', '{"es": "Fuente", "en": "Source"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_registry_attribute_schema_source_check] — bauth.idn_registry_attribute_schema.source', true, 2520),
  ('d15.nhi_agente.tipo_sesion', '{"es": "Tipo de sesión", "en": "Session Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iai_session] — bauth.idn_roles_nhi_agent_identity.session_type', true, 2530),
  ('d15.nhi_cert.decision', '{"es": "Decisión", "en": "Decision"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_inc_decision] — bauth.idn_roles_nhi_certification.decision', true, 2540),
  ('d15.nhi_identidad.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_inhi_status] — bauth.idn_roles_nhi_identity.status', true, 2550),
  ('d15.nhi_identidad.tipo_nhi', '{"es": "Tipo NHI", "en": "Nhi Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_inhi_type] — bauth.idn_roles_nhi_identity.nhi_type', true, 2560),
  ('d15.nhi_ciclo.tipo_evento', '{"es": "Tipo de evento", "en": "Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_inle_type] — bauth.idn_roles_nhi_lifecycle_event.event_type', true, 2570),
  ('rol.ciclo_vida.tipo_disparador', '{"es": "Tipo de disparador del ciclo de vida", "en": "Trigger Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_irle_trigger] — bauth.idn_roles_rol_lifecycle_event.trigger_type', true, 2580),
  ('rol.template.operacion', '{"es": "Operación", "en": "Operation"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_roles_template_history_operation_check] — bauth.idn_roles_template_history.operation', true, 2590),
  ('rol.ver_retencion.clase_info', '{"es": "Clase de información", "en": "Info Class"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_irvb01rp_class] — bauth.idn_roles_ver_b01_retention_policy.info_class', true, 2600),
  ('rol.ver_contrato.compatibilidad', '{"es": "Compatibilidad", "en": "Compatibility"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_irvcrl_compat] — bauth.idn_roles_ver_contract_revision_log.compatibility', true, 2610),
  ('scim.mapeo_attr.mutabilidad_scim', '{"es": "Mutabilidad SCIM", "en": "Scim Mutability"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_isam_mutability] — bauth.idn_scim_attribute_map.scim_mutability', true, 2620),
  ('scim.mapeo_attr.recurso_scim', '{"es": "Recurso SCIM", "en": "Scim Resource"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_isam_resource] — bauth.idn_scim_attribute_map.scim_resource', true, 2630),
  ('scim.mapeo_attr.retorno_scim', '{"es": "Retorno SCIM", "en": "Scim Returned"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_isam_returned] — bauth.idn_scim_attribute_map.scim_returned', true, 2640),
  ('scim.mapeo_attr.tabla_local', '{"es": "Tabla local", "en": "Local Table"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_isam_table] — bauth.idn_scim_attribute_map.local_table', true, 2650),
  ('d13.cadena_ca.tipo_ca', '{"es": "Tipo de CA", "en": "Ca Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_ca_chain_ca_type_check] — bauth.idn_signature_ca_chain.ca_type', true, 2660),
  ('d13.eudi_wallet.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_eudi_wallet_status_check] — bauth.idn_signature_eudi_wallet.status', true, 2670),
  ('d13.solicitud_firma.tipo_documento', '{"es": "Tipo de documento", "en": "Document Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_request_document_type_check] — bauth.idn_signature_request.document_type', true, 2680),
  ('d13.solicitud_firma.motor', '{"es": "Motor", "en": "Engine"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_request_engine_check] — bauth.idn_signature_request.engine', true, 2690),
  ('d13.solicitud_firma.formato_firma', '{"es": "Formato de firma", "en": "Signature Format"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_request_signature_format_check] — bauth.idn_signature_request.signature_format', true, 2700),
  ('d13.solicitud_firma.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_request_status_check] — bauth.idn_signature_request.status', true, 2710),
  ('d13.revocacion_cert.fuente_verificacion', '{"es": "Fuente de verificación CRL/OCSP", "en": "Check Source"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_revocation_cache_check_source_check] — bauth.idn_signature_revocation_cache.check_source', true, 2720),
  ('d13.revocacion_cert.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_revocation_cache_status_check] — bauth.idn_signature_revocation_cache.status', true, 2730),
  ('d13.verificacion_firma.estado_cert', '{"es": "Estado del certificado", "en": "Cert Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_verification_log_cert_status_check] — bauth.idn_signature_verification_log.cert_status', true, 2740),
  ('d13.verificacion_firma.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_signature_verification_log_outcome_check] — bauth.idn_signature_verification_log.outcome', true, 2750),
  ('d04.excepcion_temp.tipo_excepcion', '{"es": "Tipo de excepción", "en": "Exception Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_temporal_exception_exception_type_check] — bauth.idn_temporal_exception.exception_type', true, 2760),
  ('d04.turno.tipo_rotacion', '{"es": "Tipo de rotación", "en": "Rotation Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_temporal_shift_rotation_type_check] — bauth.idn_temporal_shift.rotation_type', true, 2770),
  ('d04.ventana_temporal.tipo_ventana', '{"es": "Tipo de ventana temporal", "en": "Window Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [idn_temporal_window_window_type_check] — bauth.idn_temporal_window.window_type', true, 2780),
  ('identidad.usuario.metodo_registro', '{"es": "Método de registro", "en": "Registration Method"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iu_reg_method] — bauth.idn_user.registration_method', true, 2790),
  ('identidad.usuario.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iu_status] — bauth.idn_user.status', true, 2800),
  ('identidad.recuperacion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iur_status] — bauth.idn_user_recovery.status', true, 2810),
  ('identidad.recuperacion.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_iur_type] — bauth.idn_user_recovery.type', true, 2820),
  ('d14.breakglass.metodo_auth', '{"es": "Método de autenticación privilegiada", "en": "Auth Method"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pbga_auth_method] — bauth.pam_breakglass_activation.auth_method', true, 2830),
  ('d14.breakglass.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pbga_deactivation] — bauth.pam_breakglass_activation.status', true, 2840),
  ('d14.breakglass.estado._control', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pbga_dual_control] — bauth.pam_breakglass_activation.status', true, 2850),
  ('d14.credencial_priv.politica_rotacion', '{"es": "Política de rotación", "en": "Rotation Policy"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pcref_rot] — bauth.pam_credential_ref.rotation_policy', true, 2860),
  ('d14.credencial_priv.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pcref_status] — bauth.pam_credential_ref.status; bauth.pam_nhi_secret_ref.status', true, 2870),
  ('d14.credencial_priv.tipo_credencial', '{"es": "Tipo de credencial", "en": "Credential Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pcref_type] — bauth.pam_credential_ref.credential_type; bauth.pam_nhi_secret_ref.secret_type', true, 2880),
  ('d14.cuenta_priv.estado', '{"es": "Estado", "en": "Estado"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pcp_estado] — bauth.pam_cuenta_privilegiada.estado', true, 2890),
  ('d14.cuenta_priv.tipo', '{"es": "Tipo", "en": "Tipo"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pcp_tipo] — bauth.pam_cuenta_privilegiada.tipo', true, 2900),
  ('d14.jit.decision', '{"es": "Decisión", "en": "Decision"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pja_decision] — bauth.pam_jit_approval.decision', true, 2910),
  ('d14.nhi_secreto.politica_rotacion', '{"es": "Política de rotación", "en": "Rotation Policy"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pnsr_rotation] — bauth.pam_nhi_secret_ref.rotation_policy', true, 2920),
  ('d14.sesion_priv.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_psr_status] — bauth.pam_session_record.status', true, 2930),
  ('d14.grabacion.storage.type', '{"es": "Tipo de almacenamiento", "en": "Storage Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [pam_session_recording_storage_type_check] — bauth.pam_session_recording.storage_type', true, 2940),
  ('priv.aseguramiento.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [privilege_assurance_audit_outcome_check] — bauth.privilege_assurance_audit.outcome', true, 2950),
  ('priv.atom.operacion', '{"es": "Operación", "en": "Operation"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [privilege_atom_audit_operation_check] — bauth.privilege_atom_audit.operation; bauth.privilege_atom_audit_2026_07.operation; bauth.privilege_atom_audit_2026_08.operation; bauth.privilege_atom_audit_2026_09.operation', true, 2960),
  ('priv.delegacion.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pd_status] — bauth.privilege_delegation.status; bauth.privilege_exception_record.status; bauth.privilege_override.status', true, 2970),
  ('priv.excepcion_reg.tipo_excepcion', '{"es": "Tipo de excepción", "en": "Exception Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_per_type] — bauth.privilege_exception_record.exception_type', true, 2980),
  ('priv.anulacion.tipo_anulacion', '{"es": "Tipo de anulación", "en": "Override Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_po_override_type] — bauth.privilege_override.override_type', true, 2990),
  ('priv.recurso.ruta_eval', '{"es": "Ruta de evaluación", "en": "Evaluation Path"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pra_eval_path] — bauth.privilege_resource_atom.evaluation_path', true, 3000),
  ('priv.recurso.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pra_status] — bauth.privilege_resource_atom.status', true, 3010),
  ('priv.recurso.alcance_tenant', '{"es": "Alcance de tenant", "en": "Tenant Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pra_tenant_scope] — bauth.privilege_resource_atom.tenant_scope', true, 3020),
  ('priv.recurso.tipo_protocolo', '{"es": "Tipo de protocolo", "en": "Protocol Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pra_tipo_protocolo] — bauth.privilege_resource_atom.protocol_type', true, 3030),
  ('priv.verbo_conflicto.tipo_conflicto', '{"es": "Tipo de conflicto", "en": "Conflict Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_pvc_conflict_type] — bauth.privilege_verb_conflict.conflict_type', true, 3040),
  ('ses.caep.tipo_evento', '{"es": "Tipo de evento", "en": "Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_scel_event_type] — bauth.ses_caep_event_log.event_type; bauth.ses_risk_policy.trigger_event', true, 3050),
  ('ses.caep.tipo_sujeto', '{"es": "Tipo de sujeto", "en": "Subject Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_scel_subject_type] — bauth.ses_caep_event_log.subject_type', true, 3060),
  ('ses.sesion.motivo_fin', '{"es": "Motivo de terminación", "en": "Termination Reason"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ssl_reason] — bauth.ses_session_log.termination_reason', true, 3070),
  ('ses.ssf.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sss_status] — bauth.ses_ssf_stream.status', true, 3080),
  ('sig.adsib_ciclo.event', '{"es": "Tipo de evento", "en": "Event"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sal_event] — bauth.sig_adsib_lifecycle.event', true, 3090),
  ('sig.certificado.tipo_adsib', '{"es": "Tipo ADSIB", "en": "Adsib Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sc_adsib] — bauth.sig_certificate.adsib_type', true, 3100),
  ('sig.certificado.motor', '{"es": "Motor", "en": "Engine"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sc_engine] — bauth.sig_certificate.engine', true, 3110),
  ('sig.crl.motor', '{"es": "Motor", "en": "Engine"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_scrl_engine] — bauth.sig_crl.engine; bauth.sig_key.engine; bauth.sig_operation_log.engine', true, 3120),
  ('sig.doc_politica.engine.required', '{"es": "Motor de firma requerido", "en": "Engine Required"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sdp_eng] — bauth.sig_document_policy.engine_required', true, 3130),
  ('sig.doc_politica.external.profile', '{"es": "Perfil de firma externo", "en": "External Profile"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sdp_ext] — bauth.sig_document_policy.external_profile', true, 3140),
  ('sig.doc_politica.internal.profile', '{"es": "Perfil de firma interno", "en": "Internal Profile"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sdp_int] — bauth.sig_document_policy.internal_profile', true, 3150),
  ('sig.llave.purpose', '{"es": "Propósito de la llave", "en": "Purpose"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sk_purpose] — bauth.sig_key.purpose', true, 3160),
  ('sig.llave.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sk_status] — bauth.sig_key.status', true, 3170),
  ('sig.operacion.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sol_outcome] — bauth.sig_operation_log.outcome', true, 3180),
  ('sig.operacion.tipo_firmante', '{"es": "Tipo de firmante", "en": "Signer Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_sol_stype] — bauth.sig_operation_log.signer_type', true, 3190),
  ('vc.wallet.metodo_respaldo', '{"es": "Método de respaldo", "en": "Backup Method"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_w_backup] — bauth.wallet.backup_method', true, 3200),
  ('vc.wallet.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_w_status] — bauth.wallet.status', true, 3210),
  ('vc.emision.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wil_outcome] — bauth.wallet_issuance_log.outcome', true, 3220),
  ('vc.emision.protocolo', '{"es": "Protocolo", "en": "Protocol"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wil_proto] — bauth.wallet_issuance_log.protocol', true, 3230),
  ('vc.item.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wi_status] — bauth.wallet_item.status', true, 3240),
  ('vc.item.tipo', '{"es": "Tipo", "en": "Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wi_type] — bauth.wallet_item.type', true, 3250),
  ('vc.presentacion.resultado', '{"es": "Resultado", "en": "Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wpl_outcome] — bauth.wallet_presentation_log.outcome; bauth.wallet_presentation_log_2026_07.outcome; bauth.wallet_presentation_log_2026_08.outcome', true, 3260),
  ('vc.presentacion.protocolo', '{"es": "Protocolo", "en": "Protocol"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wpl_proto] — bauth.wallet_presentation_log.protocol; bauth.wallet_presentation_log_2026_07.protocol; bauth.wallet_presentation_log_2026_08.protocol', true, 3270),
  ('menu.atom.efecto_requerido', '{"es": "Efecto requerido", "en": "Required Effect"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [menu_item_atom_required_effect_check] — bglobal.menu_item_atom.required_effect', true, 3280),
  ('bos.snapshot.alcance', '{"es": "Alcance", "en": "Scope"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_cap_sn_scope] — bos.cap_sistema_snapshot.scope; bos.cap_sistema_snapshot_2026_07.scope', true, 3290),
  ('bos.tenant_politica.modo_politica', '{"es": "Modo de política", "en": "Policy Mode"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_cap_tp_mode] — bos.cap_tenant_policy.policy_mode', true, 3300),
  ('bos.audit.operacion', '{"es": "Operación", "en": "Operation"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ca_operation] — bos.ctx_context_audit.operation', true, 3310),
  ('bos.audit.estado_anterior', '{"es": "Estado anterior", "en": "Old State"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ca_state] — bos.ctx_context_audit.old_state; bos.ctx_context_session.state; bos.ctx_registered_device.state', true, 3320),
  ('bos.emergencia.resultado_revision', '{"es": "Resultado de revisión", "en": "Review Outcome"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_cem_review] — bos.ctx_context_emergency.review_outcome', true, 3330),
  ('bos.emergencia.estado', '{"es": "Estado interno", "en": "State"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_cem_state] — bos.ctx_context_emergency.state', true, 3340),
  ('bos.transferencia.tipo_transferencia', '{"es": "Tipo de transferencia", "en": "Transfer Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ct_type] — bos.ctx_context_transfer.transfer_type', true, 3350),
  ('bos.ficha_evento.resultado', '{"es": "Resultado", "en": "Result"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fch_e_result] — bos.fch_ficha_event.result; bos.ins_bootstrap_event.result', true, 3360),
  ('bos.ficha_estado.backend', '{"es": "Backend de ejecución", "en": "Backend"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fch_s_backend] — bos.fch_ficha_state.backend', true, 3370),
  ('bos.ficha_estado.estado', '{"es": "Estado interno", "en": "State"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_fch_s_state] — bos.fch_ficha_state.state', true, 3380),
  ('bos.bootstrap.estado', '{"es": "Estado interno", "en": "State"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ins_be_state] — bos.ins_bootstrap_event.state', true, 3390),
  ('bos.saga.estado', '{"es": "Estado interno", "en": "State"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ins_se_state] — bos.ins_saga_execution.state', true, 3400),
  ('bos.saga.tipo_saga', '{"es": "Tipo de saga", "en": "Saga Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_ins_se_type] — bos.ins_saga_execution.saga_type', true, 3410),
  ('bos.inventario_cert.tipo_cert', '{"es": "Tipo de certificado", "en": "Cert Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_ci_cert_type] — bos.net_cert_inventory.cert_type', true, 3420),
  ('bos.inventario_cert.motor_emisor', '{"es": "Motor emisor de certificado", "en": "Issuer Engine"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_ci_issuer_engine] — bos.net_cert_inventory.issuer_engine', true, 3430),
  ('bos.inventario_cert.algoritmo_llave', '{"es": "Algoritmo de llave", "en": "Key Algorithm"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_ci_key_algo] — bos.net_cert_inventory.key_algorithm', true, 3440),
  ('bos.inventario_cert.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_ci_status] — bos.net_cert_inventory.status', true, 3450),
  ('bos.evento_seg.severidad', '{"es": "Severidad", "en": "Severity"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_se_severity] — bos.net_security_events.severity; bos.net_security_events_default.severity', true, 3460),
  ('bos.evento_seg.fuente', '{"es": "Fuente", "en": "Source"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_se_source] — bos.net_security_events.source; bos.net_security_events_default.source', true, 3470),
  ('bos.evento_seg.tipo_evento', '{"es": "Tipo de evento", "en": "Event Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_net_se_type] — bos.net_security_events.event_type; bos.net_security_events_default.event_type', true, 3480),
  ('bos.puerto.tipo_activo', '{"es": "Tipo de activo de red", "en": "Asset Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_prt_pa_asset] — bos.prt_port_assignment.asset_type', true, 3490),
  ('bos.puerto.tipo_puerto', '{"es": "Tipo de puerto", "en": "Port Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_prt_pa_port_type] — bos.prt_port_assignment.port_type', true, 3500),
  ('bos.puerto.estado', '{"es": "Estado", "en": "Status"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_prt_pa_status] — bos.prt_port_assignment.status', true, 3510),
  ('bos.puerto.transporte', '{"es": "Protocolo de transporte", "en": "Transport"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_prt_pa_transport] — bos.prt_port_assignment.transport', true, 3520),
  ('bos.release.channel', '{"es": "Canal de liberación", "en": "Channel"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_rel_re_channel] — bos.rel_release_event.channel; bos.rel_release_manifest.channel', true, 3530),
  ('bos.release.operacion', '{"es": "Operación", "en": "Operation"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_rel_re_op] — bos.rel_release_event.operation', true, 3540),
  ('bos.release.resultado', '{"es": "Resultado", "en": "Result"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_rel_re_result] — bos.rel_release_event.result', true, 3550),
  ('bos.release.disparado_por', '{"es": "Disparado por", "en": "Triggered By"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_rel_re_trigger] — bos.rel_release_event.triggered_by', true, 3560),
  ('bos.watchdog.accion_tomada', '{"es": "Acción tomada", "en": "Action Taken"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wdg_we_action] — bos.wdg_watchdog_event.action_taken', true, 3570),
  ('bos.watchdog.capa_verificacion', '{"es": "Capa de verificación (watchdog)", "en": "Check Layer"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wdg_we_layer] — bos.wdg_watchdog_event.check_layer', true, 3580),
  ('bos.watchdog.tipo_recurso', '{"es": "Tipo de recurso", "en": "Resource Type"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wdg_we_resource] — bos.wdg_watchdog_event.resource_type', true, 3590),
  ('bos.watchdog.resultado_accion', '{"es": "Resultado de la acción", "en": "Action Result"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wdg_we_result] — bos.wdg_watchdog_event.action_result', true, 3600),
  ('bos.watchdog.severidad', '{"es": "Severidad", "en": "Severity"}'::jsonb, 'CONTEXTUAL'::menu_type_enum,
   'CHECK [chk_wdg_we_severity] — bos.wdg_watchdog_event.severity', true, 3610);

-- ── Bloque 1/11 ───────────────────────────────
DO $$
DECLARE
    v_auth_intento_resultado UUID;
    v_auth_cumplimiento_nivel_cobertura UUID;
    v_auth_credencial_nivel_aal UUID;
    v_auth_credencial_estado UUID;
    v_auth_fido2_formato_atestacion UUID;
    v_auth_secreto_tipo UUID;
    v_auth_x509_origen UUID;
    v_auth_cripto_estado UUID;
    v_auth_cripto_tipo UUID;
    v_auth_dispositivo_categoria UUID;
    v_auth_dispositivo_version_osdp UUID;
    v_auth_dispositivo_plataforma UUID;
    v_auth_dispositivo_estado UUID;
    v_auth_dispositivo_confianza UUID;
    v_auth_vinculo_disp_tipo_vinculo UUID;
    v_auth_postura_disp_cumplimiento UUID;
    v_auth_postura_disp_mdm UUID;
    v_auth_postura_disp_fuente_postura UUID;
    v_auth_federacion_estado UUID;
    v_auth_metodo_categoria UUID;
    v_auth_metodo_estado UUID;
    v_auth_saga_estado UUID;
    v_blk_cuenta_estado UUID;
    v_blk_ancla_cadena UUID;
    v_blk_ancla_estado UUID;
BEGIN

    -- chk_aal_outcome [bauth.auth_attempt_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.intento.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "chk_aal_outcome", "columns": ["bauth.auth_attempt_log.outcome", "bauth.auth_attempt_log_2026_07.outcome", "bauth.auth_attempt_log_2026_08.outcome", "bauth.auth_attempt_log_2026_09.outcome"]}$j$)
    RETURNING item_id INTO v_auth_intento_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_intento_resultado, 'auth.intento.resultado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 10, $j${"value": "EXPIRED"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.FAILURE', $j${"es": "FAILURE", "en": "FAILURE"}$j$, 1, true, 20, $j${"value": "FAILURE"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.INVALID_USER', $j${"es": "INVALID_USER", "en": "INVALID_USER"}$j$, 1, true, 30, $j${"value": "INVALID_USER"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.LOCKED', $j${"es": "LOCKED", "en": "LOCKED"}$j$, 1, true, 40, $j${"value": "LOCKED"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.REVOKED_CREDENTIAL', $j${"es": "REVOKED_CREDENTIAL", "en": "REVOKED_CREDENTIAL"}$j$, 1, true, 50, $j${"value": "REVOKED_CREDENTIAL"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.STEP_UP_REQUIRED', $j${"es": "STEP_UP_REQUIRED", "en": "STEP_UP_REQUIRED"}$j$, 1, true, 60, $j${"value": "STEP_UP_REQUIRED"}$j$),
        (v_auth_intento_resultado, 'auth.intento.resultado.SUCCESS', $j${"es": "SUCCESS", "en": "SUCCESS"}$j$, 1, true, 70, $j${"value": "SUCCESS"}$j$);

    -- chk_acm_cov [bauth.auth_compliance_map]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.cumplimiento.nivel_cobertura', $j${"es": "Nivel de cobertura", "en": "Coverage Level"}$j$, 0, false, $j${"constraint": "chk_acm_cov", "columns": ["bauth.auth_compliance_map.coverage_level"]}$j$)
    RETURNING item_id INTO v_auth_cumplimiento_nivel_cobertura;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_cumplimiento_nivel_cobertura, 'auth.cumplimiento.nivel_cobertura.FULL', $j${"es": "FULL", "en": "FULL"}$j$, 1, true, 10, $j${"value": "FULL"}$j$),
        (v_auth_cumplimiento_nivel_cobertura, 'auth.cumplimiento.nivel_cobertura.NOT_COVERED', $j${"es": "NOT_COVERED", "en": "NOT_COVERED"}$j$, 1, true, 20, $j${"value": "NOT_COVERED"}$j$),
        (v_auth_cumplimiento_nivel_cobertura, 'auth.cumplimiento.nivel_cobertura.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 30, $j${"value": "PARTIAL"}$j$);

    -- chk_ac_loa [bauth.auth_credential]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.credencial.nivel_aal', $j${"es": "Nivel de garantía (AAL)", "en": "Loa Provided"}$j$, 0, false, $j${"constraint": "chk_ac_loa", "columns": ["bauth.auth_credential.loa_provided", "bauth.auth_federation_protocol.aal_max", "bauth.auth_method.loa_provided", "bauth.auth_policy.loa_required", "bauth.auth_saga_catalog.aal_produced", "bauth.auth_saga_catalog.aal_required"]}$j$)
    RETURNING item_id INTO v_auth_credencial_nivel_aal;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_credencial_nivel_aal, 'auth.credencial.nivel_aal.AAL1', $j${"es": "AAL1", "en": "AAL1"}$j$, 1, true, 10, $j${"value": "AAL1"}$j$),
        (v_auth_credencial_nivel_aal, 'auth.credencial.nivel_aal.AAL2', $j${"es": "AAL2", "en": "AAL2"}$j$, 1, true, 20, $j${"value": "AAL2"}$j$),
        (v_auth_credencial_nivel_aal, 'auth.credencial.nivel_aal.AAL3', $j${"es": "AAL3", "en": "AAL3"}$j$, 1, true, 30, $j${"value": "AAL3"}$j$);

    -- chk_ac_status [bauth.auth_credential]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.credencial.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_ac_status", "columns": ["bauth.auth_credential.status"]}$j$)
    RETURNING item_id INTO v_auth_credencial_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_credencial_estado, 'auth.credencial.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_auth_credencial_estado, 'auth.credencial.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_auth_credencial_estado, 'auth.credencial.estado.PENDING_ACTIVATION', $j${"es": "PENDING_ACTIVATION", "en": "PENDING_ACTIVATION"}$j$, 1, true, 30, $j${"value": "PENDING_ACTIVATION"}$j$),
        (v_auth_credencial_estado, 'auth.credencial.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 40, $j${"value": "REVOKED"}$j$),
        (v_auth_credencial_estado, 'auth.credencial.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 50, $j${"value": "SUSPENDED"}$j$);

    -- chk_af2_fmt [bauth.auth_credential_fido2]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.fido2.formato_atestacion', $j${"es": "Formato de atestación", "en": "Attestation Fmt"}$j$, 0, false, $j${"constraint": "chk_af2_fmt", "columns": ["bauth.auth_credential_fido2.attestation_fmt"]}$j$)
    RETURNING item_id INTO v_auth_fido2_formato_atestacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.android-key', $j${"es": "android-key", "en": "android-key"}$j$, 1, true, 10, $j${"value": "android-key"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.android-safetynet', $j${"es": "android-safetynet", "en": "android-safetynet"}$j$, 1, true, 20, $j${"value": "android-safetynet"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.apple', $j${"es": "apple", "en": "apple"}$j$, 1, true, 30, $j${"value": "apple"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.fido-u2f', $j${"es": "fido-u2f", "en": "fido-u2f"}$j$, 1, true, 40, $j${"value": "fido-u2f"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.none', $j${"es": "none", "en": "none"}$j$, 1, true, 50, $j${"value": "none"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.packed', $j${"es": "packed", "en": "packed"}$j$, 1, true, 60, $j${"value": "packed"}$j$),
        (v_auth_fido2_formato_atestacion, 'auth.fido2.formato_atestacion.tpm', $j${"es": "tpm", "en": "tpm"}$j$, 1, true, 70, $j${"value": "tpm"}$j$);

    -- chk_acs_type [bauth.auth_credential_secret]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.secreto.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_acs_type", "columns": ["bauth.auth_credential_secret.type"]}$j$)
    RETURNING item_id INTO v_auth_secreto_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_secreto_tipo, 'auth.secreto.tipo.ARGON2ID_HASH', $j${"es": "ARGON2ID_HASH", "en": "ARGON2ID_HASH"}$j$, 1, true, 10, $j${"value": "ARGON2ID_HASH"}$j$),
        (v_auth_secreto_tipo, 'auth.secreto.tipo.HOTP_SEED_ENC', $j${"es": "HOTP_SEED_ENC", "en": "HOTP_SEED_ENC"}$j$, 1, true, 20, $j${"value": "HOTP_SEED_ENC"}$j$),
        (v_auth_secreto_tipo, 'auth.secreto.tipo.PUSH_PUBKEY_ED25519', $j${"es": "PUSH_PUBKEY_ED25519", "en": "PUSH_PUBKEY_ED25519"}$j$, 1, true, 30, $j${"value": "PUSH_PUBKEY_ED25519"}$j$),
        (v_auth_secreto_tipo, 'auth.secreto.tipo.RECOVERY_CODE_HASH', $j${"es": "RECOVERY_CODE_HASH", "en": "RECOVERY_CODE_HASH"}$j$, 1, true, 40, $j${"value": "RECOVERY_CODE_HASH"}$j$),
        (v_auth_secreto_tipo, 'auth.secreto.tipo.TOTP_SEED_ENC', $j${"es": "TOTP_SEED_ENC", "en": "TOTP_SEED_ENC"}$j$, 1, true, 50, $j${"value": "TOTP_SEED_ENC"}$j$);

    -- chk_ax509_origin [bauth.auth_credential_x509]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.x509.origen', $j${"es": "Origen", "en": "Origin"}$j$, 0, false, $j${"constraint": "chk_ax509_origin", "columns": ["bauth.auth_credential_x509.origin"]}$j$)
    RETURNING item_id INTO v_auth_x509_origen;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_x509_origen, 'auth.x509.origen.ADSIB_EXTERNA', $j${"es": "ADSIB_EXTERNA", "en": "ADSIB_EXTERNA"}$j$, 1, true, 10, $j${"value": "ADSIB_EXTERNA"}$j$),
        (v_auth_x509_origen, 'auth.x509.origen.ENTERPRISE_PKI', $j${"es": "ENTERPRISE_PKI", "en": "ENTERPRISE_PKI"}$j$, 1, true, 20, $j${"value": "ENTERPRISE_PKI"}$j$),
        (v_auth_x509_origen, 'auth.x509.origen.SELF_SIGNED', $j${"es": "SELF_SIGNED", "en": "SELF_SIGNED"}$j$, 1, true, 30, $j${"value": "SELF_SIGNED"}$j$),
        (v_auth_x509_origen, 'auth.x509.origen.VAULT_INTERNAL', $j${"es": "VAULT_INTERNAL", "en": "VAULT_INTERNAL"}$j$, 1, true, 40, $j${"value": "VAULT_INTERNAL"}$j$);

    -- chk_aca_status [bauth.auth_crypto_algorithm]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.cripto.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_aca_status", "columns": ["bauth.auth_crypto_algorithm.status"]}$j$)
    RETURNING item_id INTO v_auth_cripto_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_cripto_estado, 'auth.cripto.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_auth_cripto_estado, 'auth.cripto.estado.DEPRECATED', $j${"es": "DEPRECATED", "en": "DEPRECATED"}$j$, 1, true, 20, $j${"value": "DEPRECATED"}$j$),
        (v_auth_cripto_estado, 'auth.cripto.estado.FORBIDDEN', $j${"es": "FORBIDDEN", "en": "FORBIDDEN"}$j$, 1, true, 30, $j${"value": "FORBIDDEN"}$j$);

    -- chk_aca_type [bauth.auth_crypto_algorithm]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.cripto.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_aca_type", "columns": ["bauth.auth_crypto_algorithm.type"]}$j$)
    RETURNING item_id INTO v_auth_cripto_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_cripto_tipo, 'auth.cripto.tipo.ASYMMETRIC_KEM', $j${"es": "ASYMMETRIC_KEM", "en": "ASYMMETRIC_KEM"}$j$, 1, true, 10, $j${"value": "ASYMMETRIC_KEM"}$j$),
        (v_auth_cripto_tipo, 'auth.cripto.tipo.ASYMMETRIC_SIG', $j${"es": "ASYMMETRIC_SIG", "en": "ASYMMETRIC_SIG"}$j$, 1, true, 20, $j${"value": "ASYMMETRIC_SIG"}$j$),
        (v_auth_cripto_tipo, 'auth.cripto.tipo.HASH', $j${"es": "HASH", "en": "HASH"}$j$, 1, true, 30, $j${"value": "HASH"}$j$),
        (v_auth_cripto_tipo, 'auth.cripto.tipo.KDF', $j${"es": "KDF", "en": "KDF"}$j$, 1, true, 40, $j${"value": "KDF"}$j$),
        (v_auth_cripto_tipo, 'auth.cripto.tipo.PQC', $j${"es": "PQC", "en": "PQC"}$j$, 1, true, 50, $j${"value": "PQC"}$j$),
        (v_auth_cripto_tipo, 'auth.cripto.tipo.SYMMETRIC', $j${"es": "SYMMETRIC", "en": "SYMMETRIC"}$j$, 1, true, 60, $j${"value": "SYMMETRIC"}$j$);

    -- chk_ad_cat [bauth.auth_device]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.dispositivo.categoria', $j${"es": "Categoría", "en": "Category"}$j$, 0, false, $j${"constraint": "chk_ad_cat", "columns": ["bauth.auth_device.category"]}$j$)
    RETURNING item_id INTO v_auth_dispositivo_categoria;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.DESKTOP', $j${"es": "DESKTOP", "en": "DESKTOP"}$j$, 1, true, 10, $j${"value": "DESKTOP"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.IOT', $j${"es": "IOT", "en": "IOT"}$j$, 1, true, 20, $j${"value": "IOT"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.MOBILE', $j${"es": "MOBILE", "en": "MOBILE"}$j$, 1, true, 30, $j${"value": "MOBILE"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.NFC_READER', $j${"es": "NFC_READER", "en": "NFC_READER"}$j$, 1, true, 40, $j${"value": "NFC_READER"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.OSDP_READER', $j${"es": "OSDP_READER", "en": "OSDP_READER"}$j$, 1, true, 50, $j${"value": "OSDP_READER"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.SECURITY_KEY', $j${"es": "SECURITY_KEY", "en": "SECURITY_KEY"}$j$, 1, true, 60, $j${"value": "SECURITY_KEY"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.SERVER', $j${"es": "SERVER", "en": "SERVER"}$j$, 1, true, 70, $j${"value": "SERVER"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.SMART_CARD', $j${"es": "SMART_CARD", "en": "SMART_CARD"}$j$, 1, true, 80, $j${"value": "SMART_CARD"}$j$),
        (v_auth_dispositivo_categoria, 'auth.dispositivo.categoria.TABLET', $j${"es": "TABLET", "en": "TABLET"}$j$, 1, true, 90, $j${"value": "TABLET"}$j$);

    -- chk_ad_osdp [bauth.auth_device]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.dispositivo.version_osdp', $j${"es": "Versión OSDP (protocolo lector físico)", "en": "Osdp Version"}$j$, 0, false, $j${"constraint": "chk_ad_osdp", "columns": ["bauth.auth_device.osdp_version"]}$j$)
    RETURNING item_id INTO v_auth_dispositivo_version_osdp;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_dispositivo_version_osdp, 'auth.dispositivo.version_osdp.v1.0', $j${"es": "v1.0", "en": "v1.0"}$j$, 1, true, 10, $j${"value": "v1.0"}$j$),
        (v_auth_dispositivo_version_osdp, 'auth.dispositivo.version_osdp.v2.1', $j${"es": "v2.1", "en": "v2.1"}$j$, 1, true, 20, $j${"value": "v2.1"}$j$),
        (v_auth_dispositivo_version_osdp, 'auth.dispositivo.version_osdp.v2.2', $j${"es": "v2.2", "en": "v2.2"}$j$, 1, true, 30, $j${"value": "v2.2"}$j$);

    -- chk_ad_plat [bauth.auth_device]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.dispositivo.plataforma', $j${"es": "Plataforma", "en": "Platform"}$j$, 0, false, $j${"constraint": "chk_ad_plat", "columns": ["bauth.auth_device.platform"]}$j$)
    RETURNING item_id INTO v_auth_dispositivo_plataforma;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.ANDROID', $j${"es": "ANDROID", "en": "ANDROID"}$j$, 1, true, 10, $j${"value": "ANDROID"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.EMBEDDED', $j${"es": "EMBEDDED", "en": "EMBEDDED"}$j$, 1, true, 20, $j${"value": "EMBEDDED"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.FIDO2_HW', $j${"es": "FIDO2_HW", "en": "FIDO2_HW"}$j$, 1, true, 30, $j${"value": "FIDO2_HW"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.IOS', $j${"es": "IOS", "en": "IOS"}$j$, 1, true, 40, $j${"value": "IOS"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.LINUX', $j${"es": "LINUX", "en": "LINUX"}$j$, 1, true, 50, $j${"value": "LINUX"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.MACOS', $j${"es": "MACOS", "en": "MACOS"}$j$, 1, true, 60, $j${"value": "MACOS"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.OSDP_HW', $j${"es": "OSDP_HW", "en": "OSDP_HW"}$j$, 1, true, 70, $j${"value": "OSDP_HW"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 80, $j${"value": "UNKNOWN"}$j$),
        (v_auth_dispositivo_plataforma, 'auth.dispositivo.plataforma.WINDOWS', $j${"es": "WINDOWS", "en": "WINDOWS"}$j$, 1, true, 90, $j${"value": "WINDOWS"}$j$);

    -- chk_ad_status [bauth.auth_device]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.dispositivo.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_ad_status", "columns": ["bauth.auth_device.status"]}$j$)
    RETURNING item_id INTO v_auth_dispositivo_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.LOST', $j${"es": "LOST", "en": "LOST"}$j$, 1, true, 30, $j${"value": "LOST"}$j$),
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 40, $j${"value": "PENDING"}$j$),
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 50, $j${"value": "REVOKED"}$j$),
        (v_auth_dispositivo_estado, 'auth.dispositivo.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 60, $j${"value": "SUSPENDED"}$j$);

    -- chk_ad_trust [bauth.auth_device]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.dispositivo.confianza', $j${"es": "Nivel de confianza", "en": "Trust Level"}$j$, 0, false, $j${"constraint": "chk_ad_trust", "columns": ["bauth.auth_device.trust_level"]}$j$)
    RETURNING item_id INTO v_auth_dispositivo_confianza;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_dispositivo_confianza, 'auth.dispositivo.confianza.CONDITIONALLY_TRUSTED', $j${"es": "CONDITIONALLY_TRUSTED", "en": "CONDITIONALLY_TRUSTED"}$j$, 1, true, 10, $j${"value": "CONDITIONALLY_TRUSTED"}$j$),
        (v_auth_dispositivo_confianza, 'auth.dispositivo.confianza.QUARANTINE', $j${"es": "QUARANTINE", "en": "QUARANTINE"}$j$, 1, true, 20, $j${"value": "QUARANTINE"}$j$),
        (v_auth_dispositivo_confianza, 'auth.dispositivo.confianza.TRUSTED', $j${"es": "TRUSTED", "en": "TRUSTED"}$j$, 1, true, 30, $j${"value": "TRUSTED"}$j$),
        (v_auth_dispositivo_confianza, 'auth.dispositivo.confianza.UNTRUSTED', $j${"es": "UNTRUSTED", "en": "UNTRUSTED"}$j$, 1, true, 40, $j${"value": "UNTRUSTED"}$j$);

    -- chk_adcb_type [bauth.auth_device_credential_binding]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.vinculo_disp.tipo_vinculo', $j${"es": "Tipo de vínculo", "en": "Binding Type"}$j$, 0, false, $j${"constraint": "chk_adcb_type", "columns": ["bauth.auth_device_credential_binding.binding_type"]}$j$)
    RETURNING item_id INTO v_auth_vinculo_disp_tipo_vinculo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.FIDO2_CROSS_PLATFORM', $j${"es": "FIDO2_CROSS_PLATFORM", "en": "FIDO2_CROSS_PLATFORM"}$j$, 1, true, 10, $j${"value": "FIDO2_CROSS_PLATFORM"}$j$),
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.FIDO2_RESIDENT', $j${"es": "FIDO2_RESIDENT", "en": "FIDO2_RESIDENT"}$j$, 1, true, 20, $j${"value": "FIDO2_RESIDENT"}$j$),
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.OSDP_CARD', $j${"es": "OSDP_CARD", "en": "OSDP_CARD"}$j$, 1, true, 30, $j${"value": "OSDP_CARD"}$j$),
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.PUSH_NOTIFICATION', $j${"es": "PUSH_NOTIFICATION", "en": "PUSH_NOTIFICATION"}$j$, 1, true, 40, $j${"value": "PUSH_NOTIFICATION"}$j$),
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.SOFT_TOTP', $j${"es": "SOFT_TOTP", "en": "SOFT_TOTP"}$j$, 1, true, 50, $j${"value": "SOFT_TOTP"}$j$),
        (v_auth_vinculo_disp_tipo_vinculo, 'auth.vinculo_disp.tipo_vinculo.X509_MTLS', $j${"es": "X509_MTLS", "en": "X509_MTLS"}$j$, 1, true, 60, $j${"value": "X509_MTLS"}$j$);

    -- chk_adp_comp [bauth.auth_device_posture]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.postura_disp.cumplimiento', $j${"es": "Estado de cumplimiento", "en": "Compliance Status"}$j$, 0, false, $j${"constraint": "chk_adp_comp", "columns": ["bauth.auth_device_posture.compliance_status"]}$j$)
    RETURNING item_id INTO v_auth_postura_disp_cumplimiento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_postura_disp_cumplimiento, 'auth.postura_disp.cumplimiento.COMPLIANT', $j${"es": "COMPLIANT", "en": "COMPLIANT"}$j$, 1, true, 10, $j${"value": "COMPLIANT"}$j$),
        (v_auth_postura_disp_cumplimiento, 'auth.postura_disp.cumplimiento.EXEMPTED', $j${"es": "EXEMPTED", "en": "EXEMPTED"}$j$, 1, true, 20, $j${"value": "EXEMPTED"}$j$),
        (v_auth_postura_disp_cumplimiento, 'auth.postura_disp.cumplimiento.NON_COMPLIANT', $j${"es": "NON_COMPLIANT", "en": "NON_COMPLIANT"}$j$, 1, true, 30, $j${"value": "NON_COMPLIANT"}$j$),
        (v_auth_postura_disp_cumplimiento, 'auth.postura_disp.cumplimiento.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 40, $j${"value": "UNKNOWN"}$j$);

    -- chk_adp_mdm [bauth.auth_device_posture]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.postura_disp.mdm', $j${"es": "Cumplimiento MDM", "en": "Mdm Compliance"}$j$, 0, false, $j${"constraint": "chk_adp_mdm", "columns": ["bauth.auth_device_posture.mdm_compliance"]}$j$)
    RETURNING item_id INTO v_auth_postura_disp_mdm;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_postura_disp_mdm, 'auth.postura_disp.mdm.COMPLIANT', $j${"es": "COMPLIANT", "en": "COMPLIANT"}$j$, 1, true, 10, $j${"value": "COMPLIANT"}$j$),
        (v_auth_postura_disp_mdm, 'auth.postura_disp.mdm.NON_COMPLIANT', $j${"es": "NON_COMPLIANT", "en": "NON_COMPLIANT"}$j$, 1, true, 20, $j${"value": "NON_COMPLIANT"}$j$),
        (v_auth_postura_disp_mdm, 'auth.postura_disp.mdm.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 30, $j${"value": "UNKNOWN"}$j$);

    -- chk_adp_src [bauth.auth_device_posture]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.postura_disp.fuente_postura', $j${"es": "Fuente de postura", "en": "Posture Source"}$j$, 0, false, $j${"constraint": "chk_adp_src", "columns": ["bauth.auth_device_posture.posture_source"]}$j$)
    RETURNING item_id INTO v_auth_postura_disp_fuente_postura;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_postura_disp_fuente_postura, 'auth.postura_disp.fuente_postura.AGENT', $j${"es": "AGENT", "en": "AGENT"}$j$, 1, true, 10, $j${"value": "AGENT"}$j$),
        (v_auth_postura_disp_fuente_postura, 'auth.postura_disp.fuente_postura.EDR', $j${"es": "EDR", "en": "EDR"}$j$, 1, true, 20, $j${"value": "EDR"}$j$),
        (v_auth_postura_disp_fuente_postura, 'auth.postura_disp.fuente_postura.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 30, $j${"value": "MANUAL"}$j$),
        (v_auth_postura_disp_fuente_postura, 'auth.postura_disp.fuente_postura.MDM', $j${"es": "MDM", "en": "MDM"}$j$, 1, true, 40, $j${"value": "MDM"}$j$),
        (v_auth_postura_disp_fuente_postura, 'auth.postura_disp.fuente_postura.SELF_REPORTED', $j${"es": "SELF_REPORTED", "en": "SELF_REPORTED"}$j$, 1, true, 50, $j${"value": "SELF_REPORTED"}$j$);

    -- chk_afp_status [bauth.auth_federation_protocol]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.federacion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_afp_status", "columns": ["bauth.auth_federation_protocol.status"]}$j$)
    RETURNING item_id INTO v_auth_federacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_federacion_estado, 'auth.federacion.estado.DEPRECATED', $j${"es": "DEPRECATED", "en": "DEPRECATED"}$j$, 1, true, 10, $j${"value": "DEPRECATED"}$j$),
        (v_auth_federacion_estado, 'auth.federacion.estado.PLANNED', $j${"es": "PLANNED", "en": "PLANNED"}$j$, 1, true, 20, $j${"value": "PLANNED"}$j$),
        (v_auth_federacion_estado, 'auth.federacion.estado.SUPPORTED', $j${"es": "SUPPORTED", "en": "SUPPORTED"}$j$, 1, true, 30, $j${"value": "SUPPORTED"}$j$);

    -- chk_am_cat [bauth.auth_method]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.metodo.categoria', $j${"es": "Categoría", "en": "Category"}$j$, 0, false, $j${"constraint": "chk_am_cat", "columns": ["bauth.auth_method.category"]}$j$)
    RETURNING item_id INTO v_auth_metodo_categoria;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_metodo_categoria, 'auth.metodo.categoria.A', $j${"es": "A", "en": "A"}$j$, 1, true, 10, $j${"value": "A"}$j$),
        (v_auth_metodo_categoria, 'auth.metodo.categoria.B', $j${"es": "B", "en": "B"}$j$, 1, true, 20, $j${"value": "B"}$j$),
        (v_auth_metodo_categoria, 'auth.metodo.categoria.C', $j${"es": "C", "en": "C"}$j$, 1, true, 30, $j${"value": "C"}$j$),
        (v_auth_metodo_categoria, 'auth.metodo.categoria.D', $j${"es": "D", "en": "D"}$j$, 1, true, 40, $j${"value": "D"}$j$),
        (v_auth_metodo_categoria, 'auth.metodo.categoria.E', $j${"es": "E", "en": "E"}$j$, 1, true, 50, $j${"value": "E"}$j$),
        (v_auth_metodo_categoria, 'auth.metodo.categoria.F', $j${"es": "F", "en": "F"}$j$, 1, true, 60, $j${"value": "F"}$j$);

    -- chk_am_status [bauth.auth_method]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.metodo.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_am_status", "columns": ["bauth.auth_method.status"]}$j$)
    RETURNING item_id INTO v_auth_metodo_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_metodo_estado, 'auth.metodo.estado.DEPRECATED', $j${"es": "DEPRECATED", "en": "DEPRECATED"}$j$, 1, true, 10, $j${"value": "DEPRECATED"}$j$),
        (v_auth_metodo_estado, 'auth.metodo.estado.IMPLEMENTED', $j${"es": "IMPLEMENTED", "en": "IMPLEMENTED"}$j$, 1, true, 20, $j${"value": "IMPLEMENTED"}$j$),
        (v_auth_metodo_estado, 'auth.metodo.estado.PLANNED', $j${"es": "PLANNED", "en": "PLANNED"}$j$, 1, true, 30, $j${"value": "PLANNED"}$j$),
        (v_auth_metodo_estado, 'auth.metodo.estado.REMOVED', $j${"es": "REMOVED", "en": "REMOVED"}$j$, 1, true, 40, $j${"value": "REMOVED"}$j$);

    -- chk_asc_status [bauth.auth_saga_catalog]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('auth.saga.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_asc_status", "columns": ["bauth.auth_saga_catalog.status"]}$j$)
    RETURNING item_id INTO v_auth_saga_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_auth_saga_estado, 'auth.saga.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_auth_saga_estado, 'auth.saga.estado.DEPRECATED', $j${"es": "DEPRECATED", "en": "DEPRECATED"}$j$, 1, true, 20, $j${"value": "DEPRECATED"}$j$),
        (v_auth_saga_estado, 'auth.saga.estado.PLANNED', $j${"es": "PLANNED", "en": "PLANNED"}$j$, 1, true, 30, $j${"value": "PLANNED"}$j$);

    -- chk_bac_status [bauth.blk_account]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('blk.cuenta.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_bac_status", "columns": ["bauth.blk_account.status"]}$j$)
    RETURNING item_id INTO v_blk_cuenta_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_blk_cuenta_estado, 'blk.cuenta.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_blk_cuenta_estado, 'blk.cuenta.estado.CLOSED', $j${"es": "CLOSED", "en": "CLOSED"}$j$, 1, true, 20, $j${"value": "CLOSED"}$j$),
        (v_blk_cuenta_estado, 'blk.cuenta.estado.FROZEN', $j${"es": "FROZEN", "en": "FROZEN"}$j$, 1, true, 30, $j${"value": "FROZEN"}$j$);

    -- chk_ba_chain [bauth.blk_anchor]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('blk.ancla.cadena', $j${"es": "Cadena", "en": "Chain"}$j$, 0, false, $j${"constraint": "chk_ba_chain", "columns": ["bauth.blk_anchor.chain"]}$j$)
    RETURNING item_id INTO v_blk_ancla_cadena;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_blk_ancla_cadena, 'blk.ancla.cadena.ARBITRUM_ONE', $j${"es": "ARBITRUM_ONE", "en": "ARBITRUM_ONE"}$j$, 1, true, 10, $j${"value": "ARBITRUM_ONE"}$j$),
        (v_blk_ancla_cadena, 'blk.ancla.cadena.BESU_QBFT', $j${"es": "BESU_QBFT", "en": "BESU_QBFT"}$j$, 1, true, 20, $j${"value": "BESU_QBFT"}$j$);

    -- chk_ba_status [bauth.blk_anchor]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('blk.ancla.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_ba_status", "columns": ["bauth.blk_anchor.status"]}$j$)
    RETURNING item_id INTO v_blk_ancla_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_blk_ancla_estado, 'blk.ancla.estado.ANCHORED', $j${"es": "ANCHORED", "en": "ANCHORED"}$j$, 1, true, 10, $j${"value": "ANCHORED"}$j$),
        (v_blk_ancla_estado, 'blk.ancla.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_blk_ancla_estado, 'blk.ancla.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$),
        (v_blk_ancla_estado, 'blk.ancla.estado.SENT', $j${"es": "SENT", "en": "SENT"}$j$, 1, true, 40, $j${"value": "SENT"}$j$);

END $$;

-- ── Bloque 2/11 ───────────────────────────────
DO $$
DECLARE
    v_blk_merkle_estado UUID;
    v_blk_reconciliacion_estado UUID;
    v_cfg_politica_factor_auth UUID;
    v_cfg_politica_aplicacion UUID;
    v_cfg_politica_ciclo_vida UUID;
    v_cfg_politica_tipo_nodo UUID;
    v_cfg_politica_nivel_riesgo UUID;
    v_cfg_politica_tipo_semantico UUID;
    v_fed_cliente_perfil_fapi UUID;
    v_fed_cliente_estado UUID;
    v_fed_cliente_tipo UUID;
    v_fed_proveedor_nivel_fal UUID;
    v_fed_proveedor_protocolo UUID;
    v_fed_token_tipo UUID;
    v_acceso_contrato_tipo_acceso UUID;
    v_acceso_contrato_estado UUID;
    v_registry_attr_schema_clasificacion UUID;
    v_registry_attr_schema_mutabilidad UUID;
    v_registry_attr_schema_campo_retorno UUID;
    v_registry_attr_schema_tipo_dato UUID;
    v_d11_auditoria_codigo_dominio UUID;
    v_d11_auditoria_resultado UUID;
    v_d11_auditoria_tipo_sujeto UUID;
    v_d11_retencion_accion_expiracion UUID;
    v_d11_siem_formato_log UUID;
BEGIN

    -- chk_bmb_status [bauth.blk_merkle_batch]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('blk.merkle.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_bmb_status", "columns": ["bauth.blk_merkle_batch.status"]}$j$)
    RETURNING item_id INTO v_blk_merkle_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_blk_merkle_estado, 'blk.merkle.estado.ANCHORED', $j${"es": "ANCHORED", "en": "ANCHORED"}$j$, 1, true, 10, $j${"value": "ANCHORED"}$j$),
        (v_blk_merkle_estado, 'blk.merkle.estado.CLOSED', $j${"es": "CLOSED", "en": "CLOSED"}$j$, 1, true, 20, $j${"value": "CLOSED"}$j$),
        (v_blk_merkle_estado, 'blk.merkle.estado.COMPUTING', $j${"es": "COMPUTING", "en": "COMPUTING"}$j$, 1, true, 30, $j${"value": "COMPUTING"}$j$),
        (v_blk_merkle_estado, 'blk.merkle.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 40, $j${"value": "FAILED"}$j$),
        (v_blk_merkle_estado, 'blk.merkle.estado.OPEN', $j${"es": "OPEN", "en": "OPEN"}$j$, 1, true, 50, $j${"value": "OPEN"}$j$);

    -- chk_br_status [bauth.blk_reconciliation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('blk.reconciliacion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_br_status", "columns": ["bauth.blk_reconciliation.status"]}$j$)
    RETURNING item_id INTO v_blk_reconciliacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_blk_reconciliacion_estado, 'blk.reconciliacion.estado.CORRECTED', $j${"es": "CORRECTED", "en": "CORRECTED"}$j$, 1, true, 10, $j${"value": "CORRECTED"}$j$),
        (v_blk_reconciliacion_estado, 'blk.reconciliacion.estado.DISCREPANCY', $j${"es": "DISCREPANCY", "en": "DISCREPANCY"}$j$, 1, true, 20, $j${"value": "DISCREPANCY"}$j$),
        (v_blk_reconciliacion_estado, 'blk.reconciliacion.estado.OK', $j${"es": "OK", "en": "OK"}$j$, 1, true, 30, $j${"value": "OK"}$j$);

    -- cfg_policy_library_auth_factor_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.factor_auth', $j${"es": "Factor de autenticación", "en": "Auth Factor"}$j$, 0, false, $j${"constraint": "cfg_policy_library_auth_factor_check", "columns": ["bauth.cfg_policy_library.auth_factor"]}$j$)
    RETURNING item_id INTO v_cfg_politica_factor_auth;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_factor_auth, 'cfg.politica.factor_auth.context', $j${"es": "context", "en": "context"}$j$, 1, true, 10, $j${"value": "context"}$j$),
        (v_cfg_politica_factor_auth, 'cfg.politica.factor_auth.inherence', $j${"es": "inherence", "en": "inherence"}$j$, 1, true, 20, $j${"value": "inherence"}$j$),
        (v_cfg_politica_factor_auth, 'cfg.politica.factor_auth.knowledge', $j${"es": "knowledge", "en": "knowledge"}$j$, 1, true, 30, $j${"value": "knowledge"}$j$),
        (v_cfg_politica_factor_auth, 'cfg.politica.factor_auth.multi', $j${"es": "multi", "en": "multi"}$j$, 1, true, 40, $j${"value": "multi"}$j$),
        (v_cfg_politica_factor_auth, 'cfg.politica.factor_auth.possession', $j${"es": "possession", "en": "possession"}$j$, 1, true, 50, $j${"value": "possession"}$j$);

    -- cfg_policy_library_enforcement_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.aplicacion', $j${"es": "Modo de aplicación", "en": "Enforcement"}$j$, 0, false, $j${"constraint": "cfg_policy_library_enforcement_check", "columns": ["bauth.cfg_policy_library.enforcement"]}$j$)
    RETURNING item_id INTO v_cfg_politica_aplicacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_aplicacion, 'cfg.politica.aplicacion.mandatory', $j${"es": "mandatory", "en": "mandatory"}$j$, 1, true, 10, $j${"value": "mandatory"}$j$),
        (v_cfg_politica_aplicacion, 'cfg.politica.aplicacion.optional', $j${"es": "optional", "en": "optional"}$j$, 1, true, 20, $j${"value": "optional"}$j$),
        (v_cfg_politica_aplicacion, 'cfg.politica.aplicacion.recommended', $j${"es": "recommended", "en": "recommended"}$j$, 1, true, 30, $j${"value": "recommended"}$j$);

    -- cfg_policy_library_lifecycle_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.ciclo_vida', $j${"es": "Ciclo de vida", "en": "Lifecycle"}$j$, 0, false, $j${"constraint": "cfg_policy_library_lifecycle_check", "columns": ["bauth.cfg_policy_library.lifecycle"]}$j$)
    RETURNING item_id INTO v_cfg_politica_ciclo_vida;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_ciclo_vida, 'cfg.politica.ciclo_vida.active', $j${"es": "active", "en": "active"}$j$, 1, true, 10, $j${"value": "active"}$j$),
        (v_cfg_politica_ciclo_vida, 'cfg.politica.ciclo_vida.deprecated', $j${"es": "deprecated", "en": "deprecated"}$j$, 1, true, 20, $j${"value": "deprecated"}$j$),
        (v_cfg_politica_ciclo_vida, 'cfg.politica.ciclo_vida.draft', $j${"es": "draft", "en": "draft"}$j$, 1, true, 30, $j${"value": "draft"}$j$),
        (v_cfg_politica_ciclo_vida, 'cfg.politica.ciclo_vida.proposed', $j${"es": "proposed", "en": "proposed"}$j$, 1, true, 40, $j${"value": "proposed"}$j$);

    -- cfg_policy_library_node_type_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.tipo_nodo', $j${"es": "Tipo de nodo", "en": "Node Type"}$j$, 0, false, $j${"constraint": "cfg_policy_library_node_type_check", "columns": ["bauth.cfg_policy_library.node_type"]}$j$)
    RETURNING item_id INTO v_cfg_politica_tipo_nodo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_tipo_nodo, 'cfg.politica.tipo_nodo.config', $j${"es": "config", "en": "config"}$j$, 1, true, 10, $j${"value": "config"}$j$),
        (v_cfg_politica_tipo_nodo, 'cfg.politica.tipo_nodo.group', $j${"es": "group", "en": "group"}$j$, 1, true, 20, $j${"value": "group"}$j$),
        (v_cfg_politica_tipo_nodo, 'cfg.politica.tipo_nodo.policy', $j${"es": "policy", "en": "policy"}$j$, 1, true, 30, $j${"value": "policy"}$j$),
        (v_cfg_politica_tipo_nodo, 'cfg.politica.tipo_nodo.section', $j${"es": "section", "en": "section"}$j$, 1, true, 40, $j${"value": "section"}$j$);

    -- cfg_policy_library_risk_level_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.nivel_riesgo', $j${"es": "Nivel de riesgo", "en": "Risk Level"}$j$, 0, false, $j${"constraint": "cfg_policy_library_risk_level_check", "columns": ["bauth.cfg_policy_library.risk_level"]}$j$)
    RETURNING item_id INTO v_cfg_politica_nivel_riesgo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_nivel_riesgo, 'cfg.politica.nivel_riesgo.critical', $j${"es": "critical", "en": "critical"}$j$, 1, true, 10, $j${"value": "critical"}$j$),
        (v_cfg_politica_nivel_riesgo, 'cfg.politica.nivel_riesgo.high', $j${"es": "high", "en": "high"}$j$, 1, true, 20, $j${"value": "high"}$j$),
        (v_cfg_politica_nivel_riesgo, 'cfg.politica.nivel_riesgo.low', $j${"es": "low", "en": "low"}$j$, 1, true, 30, $j${"value": "low"}$j$),
        (v_cfg_politica_nivel_riesgo, 'cfg.politica.nivel_riesgo.medium', $j${"es": "medium", "en": "medium"}$j$, 1, true, 40, $j${"value": "medium"}$j$);

    -- cfg_policy_library_semantic_type_check [bauth.cfg_policy_library]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.politica.tipo_semantico', $j${"es": "Tipo semántico", "en": "Semantic Type"}$j$, 0, false, $j${"constraint": "cfg_policy_library_semantic_type_check", "columns": ["bauth.cfg_policy_library.semantic_type"]}$j$)
    RETURNING item_id INTO v_cfg_politica_tipo_semantico;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.configuration', $j${"es": "configuration", "en": "configuration"}$j$, 1, true, 10, $j${"value": "configuration"}$j$),
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.group', $j${"es": "group", "en": "group"}$j$, 1, true, 20, $j${"value": "group"}$j$),
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.guideline', $j${"es": "guideline", "en": "guideline"}$j$, 1, true, 30, $j${"value": "guideline"}$j$),
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.method', $j${"es": "method", "en": "method"}$j$, 1, true, 40, $j${"value": "method"}$j$),
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.policy', $j${"es": "policy", "en": "policy"}$j$, 1, true, 50, $j${"value": "policy"}$j$),
        (v_cfg_politica_tipo_semantico, 'cfg.politica.tipo_semantico.standard', $j${"es": "standard", "en": "standard"}$j$, 1, true, 60, $j${"value": "standard"}$j$);

    -- chk_fc_fapi [bauth.fed_client]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.cliente.perfil_fapi', $j${"es": "Perfil FAPI", "en": "Fapi Profile"}$j$, 0, false, $j${"constraint": "chk_fc_fapi", "columns": ["bauth.fed_client.fapi_profile"]}$j$)
    RETURNING item_id INTO v_fed_cliente_perfil_fapi;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_cliente_perfil_fapi, 'fed.cliente.perfil_fapi.ADVANCED', $j${"es": "ADVANCED", "en": "ADVANCED"}$j$, 1, true, 10, $j${"value": "ADVANCED"}$j$),
        (v_fed_cliente_perfil_fapi, 'fed.cliente.perfil_fapi.BASELINE', $j${"es": "BASELINE", "en": "BASELINE"}$j$, 1, true, 20, $j${"value": "BASELINE"}$j$),
        (v_fed_cliente_perfil_fapi, 'fed.cliente.perfil_fapi.FAPI2', $j${"es": "FAPI2", "en": "FAPI2"}$j$, 1, true, 30, $j${"value": "FAPI2"}$j$);

    -- chk_fc_status [bauth.fed_client]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.cliente.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_fc_status", "columns": ["bauth.fed_client.status", "bauth.idn_global_admin.status"]}$j$)
    RETURNING item_id INTO v_fed_cliente_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_cliente_estado, 'fed.cliente.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_fed_cliente_estado, 'fed.cliente.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 20, $j${"value": "REVOKED"}$j$),
        (v_fed_cliente_estado, 'fed.cliente.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 30, $j${"value": "SUSPENDED"}$j$);

    -- chk_fc_type [bauth.fed_client]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.cliente.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_fc_type", "columns": ["bauth.fed_client.type"]}$j$)
    RETURNING item_id INTO v_fed_cliente_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_cliente_tipo, 'fed.cliente.tipo.CONFIDENTIAL', $j${"es": "CONFIDENTIAL", "en": "CONFIDENTIAL"}$j$, 1, true, 10, $j${"value": "CONFIDENTIAL"}$j$),
        (v_fed_cliente_tipo, 'fed.cliente.tipo.M2M', $j${"es": "M2M", "en": "M2M"}$j$, 1, true, 20, $j${"value": "M2M"}$j$),
        (v_fed_cliente_tipo, 'fed.cliente.tipo.PUBLIC', $j${"es": "PUBLIC", "en": "PUBLIC"}$j$, 1, true, 30, $j${"value": "PUBLIC"}$j$);

    -- chk_fpe_fal [bauth.fed_provider_ext]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.proveedor.nivel_fal', $j${"es": "Nivel FAL", "en": "Fal"}$j$, 0, false, $j${"constraint": "chk_fpe_fal", "columns": ["bauth.fed_provider_ext.fal", "bauth.idn_tenant_fal_config.fal_level"]}$j$)
    RETURNING item_id INTO v_fed_proveedor_nivel_fal;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_proveedor_nivel_fal, 'fed.proveedor.nivel_fal.FAL1', $j${"es": "FAL1", "en": "FAL1"}$j$, 1, true, 10, $j${"value": "FAL1"}$j$),
        (v_fed_proveedor_nivel_fal, 'fed.proveedor.nivel_fal.FAL2', $j${"es": "FAL2", "en": "FAL2"}$j$, 1, true, 20, $j${"value": "FAL2"}$j$),
        (v_fed_proveedor_nivel_fal, 'fed.proveedor.nivel_fal.FAL3', $j${"es": "FAL3", "en": "FAL3"}$j$, 1, true, 30, $j${"value": "FAL3"}$j$);

    -- chk_fpe_proto [bauth.fed_provider_ext]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.proveedor.protocolo', $j${"es": "Protocolo", "en": "Protocol"}$j$, 0, false, $j${"constraint": "chk_fpe_proto", "columns": ["bauth.fed_provider_ext.protocol"]}$j$)
    RETURNING item_id INTO v_fed_proveedor_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.GITHUB', $j${"es": "GITHUB", "en": "GITHUB"}$j$, 1, true, 10, $j${"value": "GITHUB"}$j$),
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.GOOGLE', $j${"es": "GOOGLE", "en": "GOOGLE"}$j$, 1, true, 20, $j${"value": "GOOGLE"}$j$),
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.LINKEDIN', $j${"es": "LINKEDIN", "en": "LINKEDIN"}$j$, 1, true, 30, $j${"value": "LINKEDIN"}$j$),
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.MICROSOFT_ENTRA', $j${"es": "MICROSOFT_ENTRA", "en": "MICROSOFT_ENTRA"}$j$, 1, true, 40, $j${"value": "MICROSOFT_ENTRA"}$j$),
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.OIDC', $j${"es": "OIDC", "en": "OIDC"}$j$, 1, true, 50, $j${"value": "OIDC"}$j$),
        (v_fed_proveedor_protocolo, 'fed.proveedor.protocolo.SAML2', $j${"es": "SAML2", "en": "SAML2"}$j$, 1, true, 60, $j${"value": "SAML2"}$j$);

    -- chk_fti_type [bauth.fed_token_issued]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('fed.token.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_fti_type", "columns": ["bauth.fed_token_issued.type", "bauth.fed_token_issued_2026_07.type", "bauth.fed_token_issued_2026_08.type", "bauth.fed_token_issued_2026_09.type"]}$j$)
    RETURNING item_id INTO v_fed_token_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_fed_token_tipo, 'fed.token.tipo.ACCESS_TOKEN', $j${"es": "ACCESS_TOKEN", "en": "ACCESS_TOKEN"}$j$, 1, true, 10, $j${"value": "ACCESS_TOKEN"}$j$),
        (v_fed_token_tipo, 'fed.token.tipo.EXCHANGE_TOKEN', $j${"es": "EXCHANGE_TOKEN", "en": "EXCHANGE_TOKEN"}$j$, 1, true, 20, $j${"value": "EXCHANGE_TOKEN"}$j$),
        (v_fed_token_tipo, 'fed.token.tipo.ID_TOKEN', $j${"es": "ID_TOKEN", "en": "ID_TOKEN"}$j$, 1, true, 30, $j${"value": "ID_TOKEN"}$j$),
        (v_fed_token_tipo, 'fed.token.tipo.REFRESH_TOKEN', $j${"es": "REFRESH_TOKEN", "en": "REFRESH_TOKEN"}$j$, 1, true, 40, $j${"value": "REFRESH_TOKEN"}$j$);

    -- chk_iac_access_type [bauth.idn_access_contract]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('acceso.contrato.tipo_acceso', $j${"es": "Tipo de acceso", "en": "Access Type"}$j$, 0, false, $j${"constraint": "chk_iac_access_type", "columns": ["bauth.idn_access_contract.access_type"]}$j$)
    RETURNING item_id INTO v_acceso_contrato_tipo_acceso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_acceso_contrato_tipo_acceso, 'acceso.contrato.tipo_acceso.ATOM_ACCESS', $j${"es": "ATOM_ACCESS", "en": "ATOM_ACCESS"}$j$, 1, true, 10, $j${"value": "ATOM_ACCESS"}$j$),
        (v_acceso_contrato_tipo_acceso, 'acceso.contrato.tipo_acceso.DELEGATED_ACCESS', $j${"es": "DELEGATED_ACCESS", "en": "DELEGATED_ACCESS"}$j$, 1, true, 20, $j${"value": "DELEGATED_ACCESS"}$j$),
        (v_acceso_contrato_tipo_acceso, 'acceso.contrato.tipo_acceso.EMERGENCY_ACCESS', $j${"es": "EMERGENCY_ACCESS", "en": "EMERGENCY_ACCESS"}$j$, 1, true, 30, $j${"value": "EMERGENCY_ACCESS"}$j$),
        (v_acceso_contrato_tipo_acceso, 'acceso.contrato.tipo_acceso.ROLE_ACCESS', $j${"es": "ROLE_ACCESS", "en": "ROLE_ACCESS"}$j$, 1, true, 40, $j${"value": "ROLE_ACCESS"}$j$),
        (v_acceso_contrato_tipo_acceso, 'acceso.contrato.tipo_acceso.TEMP_ACCESS', $j${"es": "TEMP_ACCESS", "en": "TEMP_ACCESS"}$j$, 1, true, 50, $j${"value": "TEMP_ACCESS"}$j$);

    -- chk_iac_status [bauth.idn_access_contract]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('acceso.contrato.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_iac_status", "columns": ["bauth.idn_access_contract.status"]}$j$)
    RETURNING item_id INTO v_acceso_contrato_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_acceso_contrato_estado, 'acceso.contrato.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_acceso_contrato_estado, 'acceso.contrato.estado.DRAFT', $j${"es": "DRAFT", "en": "DRAFT"}$j$, 1, true, 20, $j${"value": "DRAFT"}$j$),
        (v_acceso_contrato_estado, 'acceso.contrato.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 30, $j${"value": "EXPIRED"}$j$),
        (v_acceso_contrato_estado, 'acceso.contrato.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 40, $j${"value": "REVOKED"}$j$),
        (v_acceso_contrato_estado, 'acceso.contrato.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 50, $j${"value": "SUSPENDED"}$j$);

    -- chk_idras_clas [bauth.idn_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.attr_schema.clasificacion', $j${"es": "Clasificación", "en": "Classification"}$j$, 0, false, $j${"constraint": "chk_idras_clas", "columns": ["bauth.idn_attribute_schema.classification", "bauth.idn_identity_attribute.classification"]}$j$)
    RETURNING item_id INTO v_registry_attr_schema_clasificacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_attr_schema_clasificacion, 'registry.attr_schema.clasificacion.CONFIDENTIAL', $j${"es": "CONFIDENTIAL", "en": "CONFIDENTIAL"}$j$, 1, true, 10, $j${"value": "CONFIDENTIAL"}$j$),
        (v_registry_attr_schema_clasificacion, 'registry.attr_schema.clasificacion.INTERNAL', $j${"es": "INTERNAL", "en": "INTERNAL"}$j$, 1, true, 20, $j${"value": "INTERNAL"}$j$),
        (v_registry_attr_schema_clasificacion, 'registry.attr_schema.clasificacion.PII', $j${"es": "PII", "en": "PII"}$j$, 1, true, 30, $j${"value": "PII"}$j$),
        (v_registry_attr_schema_clasificacion, 'registry.attr_schema.clasificacion.PUBLIC', $j${"es": "PUBLIC", "en": "PUBLIC"}$j$, 1, true, 40, $j${"value": "PUBLIC"}$j$),
        (v_registry_attr_schema_clasificacion, 'registry.attr_schema.clasificacion.SENSITIVE_PII', $j${"es": "SENSITIVE_PII", "en": "SENSITIVE_PII"}$j$, 1, true, 50, $j${"value": "SENSITIVE_PII"}$j$);

    -- chk_idras_mut [bauth.idn_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.attr_schema.mutabilidad', $j${"es": "Mutabilidad", "en": "Mutability"}$j$, 0, false, $j${"constraint": "chk_idras_mut", "columns": ["bauth.idn_attribute_schema.mutability"]}$j$)
    RETURNING item_id INTO v_registry_attr_schema_mutabilidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_attr_schema_mutabilidad, 'registry.attr_schema.mutabilidad.IMMUTABLE', $j${"es": "IMMUTABLE", "en": "IMMUTABLE"}$j$, 1, true, 10, $j${"value": "IMMUTABLE"}$j$),
        (v_registry_attr_schema_mutabilidad, 'registry.attr_schema.mutabilidad.READ_ONLY', $j${"es": "READ_ONLY", "en": "READ_ONLY"}$j$, 1, true, 20, $j${"value": "READ_ONLY"}$j$),
        (v_registry_attr_schema_mutabilidad, 'registry.attr_schema.mutabilidad.READ_WRITE', $j${"es": "READ_WRITE", "en": "READ_WRITE"}$j$, 1, true, 30, $j${"value": "READ_WRITE"}$j$),
        (v_registry_attr_schema_mutabilidad, 'registry.attr_schema.mutabilidad.WRITE_ONLY', $j${"es": "WRITE_ONLY", "en": "WRITE_ONLY"}$j$, 1, true, 40, $j${"value": "WRITE_ONLY"}$j$);

    -- chk_idras_ret [bauth.idn_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.attr_schema.campo_retorno', $j${"es": "Campo retornado", "en": "Returned"}$j$, 0, false, $j${"constraint": "chk_idras_ret", "columns": ["bauth.idn_attribute_schema.returned", "bauth.idn_identity_attribute.returned", "bauth.idn_registry_attribute_schema.returned"]}$j$)
    RETURNING item_id INTO v_registry_attr_schema_campo_retorno;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_attr_schema_campo_retorno, 'registry.attr_schema.campo_retorno.ALWAYS', $j${"es": "ALWAYS", "en": "ALWAYS"}$j$, 1, true, 10, $j${"value": "ALWAYS"}$j$),
        (v_registry_attr_schema_campo_retorno, 'registry.attr_schema.campo_retorno.DEFAULT', $j${"es": "DEFAULT", "en": "DEFAULT"}$j$, 1, true, 20, $j${"value": "DEFAULT"}$j$),
        (v_registry_attr_schema_campo_retorno, 'registry.attr_schema.campo_retorno.NEVER', $j${"es": "NEVER", "en": "NEVER"}$j$, 1, true, 30, $j${"value": "NEVER"}$j$),
        (v_registry_attr_schema_campo_retorno, 'registry.attr_schema.campo_retorno.REQUEST', $j${"es": "REQUEST", "en": "REQUEST"}$j$, 1, true, 40, $j${"value": "REQUEST"}$j$);

    -- chk_idras_tipo [bauth.idn_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.attr_schema.tipo_dato', $j${"es": "Tipo de dato", "en": "Data Type"}$j$, 0, false, $j${"constraint": "chk_idras_tipo", "columns": ["bauth.idn_attribute_schema.data_type"]}$j$)
    RETURNING item_id INTO v_registry_attr_schema_tipo_dato;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.BINARY', $j${"es": "BINARY", "en": "BINARY"}$j$, 1, true, 10, $j${"value": "BINARY"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.BOOLEAN', $j${"es": "BOOLEAN", "en": "BOOLEAN"}$j$, 1, true, 20, $j${"value": "BOOLEAN"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.DATE', $j${"es": "DATE", "en": "DATE"}$j$, 1, true, 30, $j${"value": "DATE"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.DATETIME', $j${"es": "DATETIME", "en": "DATETIME"}$j$, 1, true, 40, $j${"value": "DATETIME"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.DECIMAL', $j${"es": "DECIMAL", "en": "DECIMAL"}$j$, 1, true, 50, $j${"value": "DECIMAL"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.INTEGER', $j${"es": "INTEGER", "en": "INTEGER"}$j$, 1, true, 60, $j${"value": "INTEGER"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.JSON', $j${"es": "JSON", "en": "JSON"}$j$, 1, true, 70, $j${"value": "JSON"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.STRING', $j${"es": "STRING", "en": "STRING"}$j$, 1, true, 80, $j${"value": "STRING"}$j$),
        (v_registry_attr_schema_tipo_dato, 'registry.attr_schema.tipo_dato.UUID', $j${"es": "UUID", "en": "UUID"}$j$, 1, true, 90, $j${"value": "UUID"}$j$);

    -- idn_audit_event_log_domain_code_check [bauth.idn_audit_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.auditoria.codigo_dominio', $j${"es": "Código de dominio", "en": "Domain Code"}$j$, 0, false, $j${"constraint": "idn_audit_event_log_domain_code_check", "columns": ["bauth.idn_audit_event_log.domain_code", "bauth.idn_audit_event_log_2026_07.domain_code", "bauth.idn_audit_event_log_2026_08.domain_code", "bauth.idn_audit_event_log_2026_09.domain_code", "bauth.idn_audit_event_log_default.domain_code", "bauth.idn_registry_atom_catalog.domain_code"]}$j$)
    RETURNING item_id INTO v_d11_auditoria_codigo_dominio;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D00', $j${"es": "D00", "en": "D00"}$j$, 1, true, 10, $j${"value": "D00"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D01', $j${"es": "D01", "en": "D01"}$j$, 1, true, 20, $j${"value": "D01"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D02', $j${"es": "D02", "en": "D02"}$j$, 1, true, 30, $j${"value": "D02"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D03', $j${"es": "D03", "en": "D03"}$j$, 1, true, 40, $j${"value": "D03"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D04', $j${"es": "D04", "en": "D04"}$j$, 1, true, 50, $j${"value": "D04"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D05', $j${"es": "D05", "en": "D05"}$j$, 1, true, 60, $j${"value": "D05"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D06', $j${"es": "D06", "en": "D06"}$j$, 1, true, 70, $j${"value": "D06"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D07', $j${"es": "D07", "en": "D07"}$j$, 1, true, 80, $j${"value": "D07"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D08', $j${"es": "D08", "en": "D08"}$j$, 1, true, 90, $j${"value": "D08"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D09', $j${"es": "D09", "en": "D09"}$j$, 1, true, 100, $j${"value": "D09"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D10', $j${"es": "D10", "en": "D10"}$j$, 1, true, 110, $j${"value": "D10"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D11', $j${"es": "D11", "en": "D11"}$j$, 1, true, 120, $j${"value": "D11"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D12', $j${"es": "D12", "en": "D12"}$j$, 1, true, 130, $j${"value": "D12"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D13', $j${"es": "D13", "en": "D13"}$j$, 1, true, 140, $j${"value": "D13"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D14', $j${"es": "D14", "en": "D14"}$j$, 1, true, 150, $j${"value": "D14"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D15', $j${"es": "D15", "en": "D15"}$j$, 1, true, 160, $j${"value": "D15"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D98', $j${"es": "D98", "en": "D98"}$j$, 1, true, 170, $j${"value": "D98"}$j$),
        (v_d11_auditoria_codigo_dominio, 'd11.auditoria.codigo_dominio.D99', $j${"es": "D99", "en": "D99"}$j$, 1, true, 180, $j${"value": "D99"}$j$);

    -- idn_audit_event_log_outcome_check [bauth.idn_audit_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.auditoria.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "idn_audit_event_log_outcome_check", "columns": ["bauth.idn_audit_event_log.outcome", "bauth.idn_audit_event_log_2026_07.outcome", "bauth.idn_audit_event_log_2026_08.outcome", "bauth.idn_audit_event_log_2026_09.outcome", "bauth.idn_audit_event_log_default.outcome"]}$j$)
    RETURNING item_id INTO v_d11_auditoria_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_auditoria_resultado, 'd11.auditoria.resultado.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_d11_auditoria_resultado, 'd11.auditoria.resultado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 20, $j${"value": "ERROR"}$j$),
        (v_d11_auditoria_resultado, 'd11.auditoria.resultado.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 30, $j${"value": "PARTIAL"}$j$),
        (v_d11_auditoria_resultado, 'd11.auditoria.resultado.PERMIT', $j${"es": "PERMIT", "en": "PERMIT"}$j$, 1, true, 40, $j${"value": "PERMIT"}$j$);

    -- idn_audit_event_log_subject_type_check [bauth.idn_audit_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.auditoria.tipo_sujeto', $j${"es": "Tipo de sujeto", "en": "Subject Type"}$j$, 0, false, $j${"constraint": "idn_audit_event_log_subject_type_check", "columns": ["bauth.idn_audit_event_log.subject_type", "bauth.idn_audit_event_log_2026_07.subject_type", "bauth.idn_audit_event_log_2026_08.subject_type", "bauth.idn_audit_event_log_2026_09.subject_type", "bauth.idn_audit_event_log_default.subject_type"]}$j$)
    RETURNING item_id INTO v_d11_auditoria_tipo_sujeto;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_auditoria_tipo_sujeto, 'd11.auditoria.tipo_sujeto.ENTITY', $j${"es": "ENTITY", "en": "ENTITY"}$j$, 1, true, 10, $j${"value": "ENTITY"}$j$),
        (v_d11_auditoria_tipo_sujeto, 'd11.auditoria.tipo_sujeto.NHI', $j${"es": "NHI", "en": "NHI"}$j$, 1, true, 20, $j${"value": "NHI"}$j$),
        (v_d11_auditoria_tipo_sujeto, 'd11.auditoria.tipo_sujeto.SYSTEM', $j${"es": "SYSTEM", "en": "SYSTEM"}$j$, 1, true, 30, $j${"value": "SYSTEM"}$j$),
        (v_d11_auditoria_tipo_sujeto, 'd11.auditoria.tipo_sujeto.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 40, $j${"value": "USER"}$j$);

    -- idn_audit_retention_policy_expiration_action_check [bauth.idn_audit_retention_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.retencion.accion_expiracion', $j${"es": "Acción al expirar", "en": "Expiration Action"}$j$, 0, false, $j${"constraint": "idn_audit_retention_policy_expiration_action_check", "columns": ["bauth.idn_audit_retention_policy.expiration_action"]}$j$)
    RETURNING item_id INTO v_d11_retencion_accion_expiracion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_retencion_accion_expiracion, 'd11.retencion.accion_expiracion.ANONYMIZE', $j${"es": "ANONYMIZE", "en": "ANONYMIZE"}$j$, 1, true, 10, $j${"value": "ANONYMIZE"}$j$),
        (v_d11_retencion_accion_expiracion, 'd11.retencion.accion_expiracion.ARCHIVE', $j${"es": "ARCHIVE", "en": "ARCHIVE"}$j$, 1, true, 20, $j${"value": "ARCHIVE"}$j$),
        (v_d11_retencion_accion_expiracion, 'd11.retencion.accion_expiracion.DELETE', $j${"es": "DELETE", "en": "DELETE"}$j$, 1, true, 30, $j${"value": "DELETE"}$j$),
        (v_d11_retencion_accion_expiracion, 'd11.retencion.accion_expiracion.KEEP', $j${"es": "KEEP", "en": "KEEP"}$j$, 1, true, 40, $j${"value": "KEEP"}$j$);

    -- idn_audit_siem_target_log_format_check [bauth.idn_audit_siem_target]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.siem.formato_log', $j${"es": "Formato de log", "en": "Log Format"}$j$, 0, false, $j${"constraint": "idn_audit_siem_target_log_format_check", "columns": ["bauth.idn_audit_siem_target.log_format"]}$j$)
    RETURNING item_id INTO v_d11_siem_formato_log;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_siem_formato_log, 'd11.siem.formato_log.CEF', $j${"es": "CEF", "en": "CEF"}$j$, 1, true, 10, $j${"value": "CEF"}$j$),
        (v_d11_siem_formato_log, 'd11.siem.formato_log.JSON', $j${"es": "JSON", "en": "JSON"}$j$, 1, true, 20, $j${"value": "JSON"}$j$),
        (v_d11_siem_formato_log, 'd11.siem.formato_log.LEEF', $j${"es": "LEEF", "en": "LEEF"}$j$, 1, true, 30, $j${"value": "LEEF"}$j$),
        (v_d11_siem_formato_log, 'd11.siem.formato_log.SYSLOG_RFC5424', $j${"es": "SYSLOG_RFC5424", "en": "SYSLOG_RFC5424"}$j$, 1, true, 40, $j${"value": "SYSLOG_RFC5424"}$j$),
        (v_d11_siem_formato_log, 'd11.siem.formato_log.WAZUH', $j${"es": "WAZUH", "en": "WAZUH"}$j$, 1, true, 50, $j${"value": "WAZUH"}$j$);

END $$;

-- ── Bloque 3/11 ───────────────────────────────
DO $$
DECLARE
    v_d11_siem_tipo_protocolo UUID;
    v_d05_inscripcion_tipo_biometrico UUID;
    v_d05_inscripcion_estado UUID;
    v_d05_identificacion_resultado UUID;
    v_d05_pad_accion_fallo UUID;
    v_d05_pad_nivel_pad UUID;
    v_d05_pad_estado UUID;
    v_d05_revocacion_bio_motivo_revocacion UUID;
    v_d05_verificacion_bio_resultado UUID;
    v_d12_ancla_tipo_evento_fuente UUID;
    v_d12_nodo_estado UUID;
    v_d12_transaccion_estado UUID;
    v_d12_transaccion_tipo_tx UUID;
    v_d12_wallet_cadena UUID;
    v_d12_wallet_estado UUID;
    v_d09_revocacion_cred_motivo UUID;
    v_d09_token_motivo_revocacion UUID;
    v_d09_token_tipo_token UUID;
    v_d10_delegacion_tipo_delegacion UUID;
    v_d10_rar_estado UUID;
    v_d10_restriccion_tipo_restriccion UUID;
    v_d10_uso_delegacion_resultado UUID;
    v_identidad_did_estado UUID;
    v_privacidad_dpia_reg_estado UUID;
    v_privacidad_dpia_reg_riesgo_residual UUID;
BEGIN

    -- idn_audit_siem_target_protocol_type_check [bauth.idn_audit_siem_target]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d11.siem.tipo_protocolo', $j${"es": "Tipo de protocolo", "en": "Protocol Type"}$j$, 0, false, $j${"constraint": "idn_audit_siem_target_protocol_type_check", "columns": ["bauth.idn_audit_siem_target.protocol_type"]}$j$)
    RETURNING item_id INTO v_d11_siem_tipo_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.ELASTIC', $j${"es": "ELASTIC", "en": "ELASTIC"}$j$, 1, true, 10, $j${"value": "ELASTIC"}$j$),
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.HTTP_WEBHOOK', $j${"es": "HTTP_WEBHOOK", "en": "HTTP_WEBHOOK"}$j$, 1, true, 20, $j${"value": "HTTP_WEBHOOK"}$j$),
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.KAFKA', $j${"es": "KAFKA", "en": "KAFKA"}$j$, 1, true, 30, $j${"value": "KAFKA"}$j$),
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.SYSLOG_TCP', $j${"es": "SYSLOG_TCP", "en": "SYSLOG_TCP"}$j$, 1, true, 40, $j${"value": "SYSLOG_TCP"}$j$),
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.SYSLOG_TLS', $j${"es": "SYSLOG_TLS", "en": "SYSLOG_TLS"}$j$, 1, true, 50, $j${"value": "SYSLOG_TLS"}$j$),
        (v_d11_siem_tipo_protocolo, 'd11.siem.tipo_protocolo.SYSLOG_UDP', $j${"es": "SYSLOG_UDP", "en": "SYSLOG_UDP"}$j$, 1, true, 60, $j${"value": "SYSLOG_UDP"}$j$);

    -- idn_biometric_enrollment_biometric_type_check [bauth.idn_biometric_enrollment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.inscripcion.tipo_biometrico', $j${"es": "Tipo biométrico", "en": "Biometric Type"}$j$, 0, false, $j${"constraint": "idn_biometric_enrollment_biometric_type_check", "columns": ["bauth.idn_biometric_enrollment.biometric_type", "bauth.idn_biometric_pad_policy.biometric_type", "bauth.idn_biometric_quality_policy.biometric_type"]}$j$)
    RETURNING item_id INTO v_d05_inscripcion_tipo_biometrico;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.FACE', $j${"es": "FACE", "en": "FACE"}$j$, 1, true, 10, $j${"value": "FACE"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.FINGERPRINT', $j${"es": "FINGERPRINT", "en": "FINGERPRINT"}$j$, 1, true, 20, $j${"value": "FINGERPRINT"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.IRIS', $j${"es": "IRIS", "en": "IRIS"}$j$, 1, true, 30, $j${"value": "IRIS"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.PALM', $j${"es": "PALM", "en": "PALM"}$j$, 1, true, 40, $j${"value": "PALM"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.RETINA', $j${"es": "RETINA", "en": "RETINA"}$j$, 1, true, 50, $j${"value": "RETINA"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.VEIN', $j${"es": "VEIN", "en": "VEIN"}$j$, 1, true, 60, $j${"value": "VEIN"}$j$),
        (v_d05_inscripcion_tipo_biometrico, 'd05.inscripcion.tipo_biometrico.VOICE', $j${"es": "VOICE", "en": "VOICE"}$j$, 1, true, 70, $j${"value": "VOICE"}$j$);

    -- idn_biometric_enrollment_status_check [bauth.idn_biometric_enrollment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.inscripcion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_biometric_enrollment_status_check", "columns": ["bauth.idn_biometric_enrollment.status", "bauth.idn_delegation_grant.status", "bauth.idn_identity_vc.status", "bauth.idn_physical_access_credential.status", "bauth.sig_certificate.status"]}$j$)
    RETURNING item_id INTO v_d05_inscripcion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_inscripcion_estado, 'd05.inscripcion.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d05_inscripcion_estado, 'd05.inscripcion.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d05_inscripcion_estado, 'd05.inscripcion.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_d05_inscripcion_estado, 'd05.inscripcion.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$);

    -- idn_biometric_identification_log_result_check [bauth.idn_biometric_identification_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.identificacion.resultado', $j${"es": "Resultado", "en": "Result"}$j$, 0, false, $j${"constraint": "idn_biometric_identification_log_result_check", "columns": ["bauth.idn_biometric_identification_log.result", "bauth.idn_biometric_identification_log_default.result"]}$j$)
    RETURNING item_id INTO v_d05_identificacion_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_identificacion_resultado, 'd05.identificacion.resultado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 10, $j${"value": "ERROR"}$j$),
        (v_d05_identificacion_resultado, 'd05.identificacion.resultado.IDENTIFIED', $j${"es": "IDENTIFIED", "en": "IDENTIFIED"}$j$, 1, true, 20, $j${"value": "IDENTIFIED"}$j$),
        (v_d05_identificacion_resultado, 'd05.identificacion.resultado.MULTIPLE_MATCH', $j${"es": "MULTIPLE_MATCH", "en": "MULTIPLE_MATCH"}$j$, 1, true, 30, $j${"value": "MULTIPLE_MATCH"}$j$),
        (v_d05_identificacion_resultado, 'd05.identificacion.resultado.NOT_IDENTIFIED', $j${"es": "NOT_IDENTIFIED", "en": "NOT_IDENTIFIED"}$j$, 1, true, 40, $j${"value": "NOT_IDENTIFIED"}$j$);

    -- idn_biometric_pad_policy_fail_action_check [bauth.idn_biometric_pad_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.pad.accion_fallo', $j${"es": "Acción en fallo", "en": "Fail Action"}$j$, 0, false, $j${"constraint": "idn_biometric_pad_policy_fail_action_check", "columns": ["bauth.idn_biometric_pad_policy.fail_action"]}$j$)
    RETURNING item_id INTO v_d05_pad_accion_fallo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_pad_accion_fallo, 'd05.pad.accion_fallo.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_d05_pad_accion_fallo, 'd05.pad.accion_fallo.LOG_AND_ALLOW', $j${"es": "LOG_AND_ALLOW", "en": "LOG_AND_ALLOW"}$j$, 1, true, 20, $j${"value": "LOG_AND_ALLOW"}$j$),
        (v_d05_pad_accion_fallo, 'd05.pad.accion_fallo.QUARANTINE', $j${"es": "QUARANTINE", "en": "QUARANTINE"}$j$, 1, true, 30, $j${"value": "QUARANTINE"}$j$),
        (v_d05_pad_accion_fallo, 'd05.pad.accion_fallo.STEP_UP', $j${"es": "STEP_UP", "en": "STEP_UP"}$j$, 1, true, 40, $j${"value": "STEP_UP"}$j$);

    -- idn_biometric_pad_policy_pad_level_check [bauth.idn_biometric_pad_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.pad.nivel_pad', $j${"es": "Nivel PAD (anti-spoofing)", "en": "Pad Level"}$j$, 0, false, $j${"constraint": "idn_biometric_pad_policy_pad_level_check", "columns": ["bauth.idn_biometric_pad_policy.pad_level"]}$j$)
    RETURNING item_id INTO v_d05_pad_nivel_pad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_pad_nivel_pad, 'd05.pad.nivel_pad.LEVEL_1', $j${"es": "LEVEL_1", "en": "LEVEL_1"}$j$, 1, true, 10, $j${"value": "LEVEL_1"}$j$),
        (v_d05_pad_nivel_pad, 'd05.pad.nivel_pad.LEVEL_2', $j${"es": "LEVEL_2", "en": "LEVEL_2"}$j$, 1, true, 20, $j${"value": "LEVEL_2"}$j$),
        (v_d05_pad_nivel_pad, 'd05.pad.nivel_pad.LEVEL_3', $j${"es": "LEVEL_3", "en": "LEVEL_3"}$j$, 1, true, 30, $j${"value": "LEVEL_3"}$j$);

    -- idn_biometric_pad_policy_status_check [bauth.idn_biometric_pad_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.pad.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_biometric_pad_policy_status_check", "columns": ["bauth.idn_biometric_pad_policy.status", "bauth.idn_biometric_quality_policy.status", "bauth.idn_financial_sod_rule.status", "bauth.idn_geospatial_data_residency.status", "bauth.idn_geospatial_velocity_policy.status", "bauth.idn_network_context_propagation.status"]}$j$)
    RETURNING item_id INTO v_d05_pad_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_pad_estado, 'd05.pad.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d05_pad_estado, 'd05.pad.estado.DISABLED', $j${"es": "DISABLED", "en": "DISABLED"}$j$, 1, true, 20, $j${"value": "DISABLED"}$j$);

    -- idn_biometric_revocation_revocation_reason_check [bauth.idn_biometric_revocation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.revocacion_bio.motivo_revocacion', $j${"es": "Motivo de revocación", "en": "Revocation Reason"}$j$, 0, false, $j${"constraint": "idn_biometric_revocation_revocation_reason_check", "columns": ["bauth.idn_biometric_revocation.revocation_reason"]}$j$)
    RETURNING item_id INTO v_d05_revocacion_bio_motivo_revocacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.ADMIN', $j${"es": "ADMIN", "en": "ADMIN"}$j$, 1, true, 10, $j${"value": "ADMIN"}$j$),
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.COMPROMISE', $j${"es": "COMPROMISE", "en": "COMPROMISE"}$j$, 1, true, 20, $j${"value": "COMPROMISE"}$j$),
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.EXPIRATION', $j${"es": "EXPIRATION", "en": "EXPIRATION"}$j$, 1, true, 30, $j${"value": "EXPIRATION"}$j$),
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.INCIDENT', $j${"es": "INCIDENT", "en": "INCIDENT"}$j$, 1, true, 40, $j${"value": "INCIDENT"}$j$),
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.QUALITY_DEGRADED', $j${"es": "QUALITY_DEGRADED", "en": "QUALITY_DEGRADED"}$j$, 1, true, 50, $j${"value": "QUALITY_DEGRADED"}$j$),
        (v_d05_revocacion_bio_motivo_revocacion, 'd05.revocacion_bio.motivo_revocacion.USER_REQUEST', $j${"es": "USER_REQUEST", "en": "USER_REQUEST"}$j$, 1, true, 60, $j${"value": "USER_REQUEST"}$j$);

    -- idn_biometric_verification_log_outcome_check [bauth.idn_biometric_verification_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d05.verificacion_bio.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "idn_biometric_verification_log_outcome_check", "columns": ["bauth.idn_biometric_verification_log.outcome", "bauth.idn_biometric_verification_log_2026_07.outcome", "bauth.idn_biometric_verification_log_2026_08.outcome", "bauth.idn_biometric_verification_log_default.outcome"]}$j$)
    RETURNING item_id INTO v_d05_verificacion_bio_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 10, $j${"value": "ERROR"}$j$),
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.LIVENESS_FAIL', $j${"es": "LIVENESS_FAIL", "en": "LIVENESS_FAIL"}$j$, 1, true, 20, $j${"value": "LIVENESS_FAIL"}$j$),
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.MATCH', $j${"es": "MATCH", "en": "MATCH"}$j$, 1, true, 30, $j${"value": "MATCH"}$j$),
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.NO_MATCH', $j${"es": "NO_MATCH", "en": "NO_MATCH"}$j$, 1, true, 40, $j${"value": "NO_MATCH"}$j$),
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.QUALITY_FAIL', $j${"es": "QUALITY_FAIL", "en": "QUALITY_FAIL"}$j$, 1, true, 50, $j${"value": "QUALITY_FAIL"}$j$),
        (v_d05_verificacion_bio_resultado, 'd05.verificacion_bio.resultado.TIMEOUT', $j${"es": "TIMEOUT", "en": "TIMEOUT"}$j$, 1, true, 60, $j${"value": "TIMEOUT"}$j$);

    -- idn_blockchain_anchor_ext_source_event_type_check [bauth.idn_blockchain_anchor_ext]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.ancla.tipo_evento_fuente', $j${"es": "Tipo de evento fuente", "en": "Source Event Type"}$j$, 0, false, $j${"constraint": "idn_blockchain_anchor_ext_source_event_type_check", "columns": ["bauth.idn_blockchain_anchor_ext.source_event_type"]}$j$)
    RETURNING item_id INTO v_d12_ancla_tipo_evento_fuente;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_ancla_tipo_evento_fuente, 'd12.ancla.tipo_evento_fuente.AUDIT_BATCH', $j${"es": "AUDIT_BATCH", "en": "AUDIT_BATCH"}$j$, 1, true, 10, $j${"value": "AUDIT_BATCH"}$j$),
        (v_d12_ancla_tipo_evento_fuente, 'd12.ancla.tipo_evento_fuente.DIGITAL_SIGNATURE', $j${"es": "DIGITAL_SIGNATURE", "en": "DIGITAL_SIGNATURE"}$j$, 1, true, 20, $j${"value": "DIGITAL_SIGNATURE"}$j$),
        (v_d12_ancla_tipo_evento_fuente, 'd12.ancla.tipo_evento_fuente.PRIVILEGE_GRANT', $j${"es": "PRIVILEGE_GRANT", "en": "PRIVILEGE_GRANT"}$j$, 1, true, 30, $j${"value": "PRIVILEGE_GRANT"}$j$),
        (v_d12_ancla_tipo_evento_fuente, 'd12.ancla.tipo_evento_fuente.SOD_VIOLATION', $j${"es": "SOD_VIOLATION", "en": "SOD_VIOLATION"}$j$, 1, true, 40, $j${"value": "SOD_VIOLATION"}$j$),
        (v_d12_ancla_tipo_evento_fuente, 'd12.ancla.tipo_evento_fuente.VC_ISSUED', $j${"es": "VC_ISSUED", "en": "VC_ISSUED"}$j$, 1, true, 50, $j${"value": "VC_ISSUED"}$j$);

    -- idn_blockchain_node_status_check [bauth.idn_blockchain_node]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.nodo.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_blockchain_node_status_check", "columns": ["bauth.idn_blockchain_node.status"]}$j$)
    RETURNING item_id INTO v_d12_nodo_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_nodo_estado, 'd12.nodo.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d12_nodo_estado, 'd12.nodo.estado.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_d12_nodo_estado, 'd12.nodo.estado.OFFLINE', $j${"es": "OFFLINE", "en": "OFFLINE"}$j$, 1, true, 30, $j${"value": "OFFLINE"}$j$),
        (v_d12_nodo_estado, 'd12.nodo.estado.SYNCING', $j${"es": "SYNCING", "en": "SYNCING"}$j$, 1, true, 40, $j${"value": "SYNCING"}$j$);

    -- idn_blockchain_transaction_status_check [bauth.idn_blockchain_transaction]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.transaccion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_blockchain_transaction_status_check", "columns": ["bauth.idn_blockchain_transaction.status"]}$j$)
    RETURNING item_id INTO v_d12_transaccion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_transaccion_estado, 'd12.transaccion.estado.CONFIRMED', $j${"es": "CONFIRMED", "en": "CONFIRMED"}$j$, 1, true, 10, $j${"value": "CONFIRMED"}$j$),
        (v_d12_transaccion_estado, 'd12.transaccion.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_d12_transaccion_estado, 'd12.transaccion.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$),
        (v_d12_transaccion_estado, 'd12.transaccion.estado.REVERTED', $j${"es": "REVERTED", "en": "REVERTED"}$j$, 1, true, 40, $j${"value": "REVERTED"}$j$);

    -- idn_blockchain_transaction_tx_type_check [bauth.idn_blockchain_transaction]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.transaccion.tipo_tx', $j${"es": "Tipo de transacción blockchain", "en": "Tx Type"}$j$, 0, false, $j${"constraint": "idn_blockchain_transaction_tx_type_check", "columns": ["bauth.idn_blockchain_transaction.tx_type"]}$j$)
    RETURNING item_id INTO v_d12_transaccion_tipo_tx;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.CALL', $j${"es": "CALL", "en": "CALL"}$j$, 1, true, 10, $j${"value": "CALL"}$j$),
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.DEPLOY', $j${"es": "DEPLOY", "en": "DEPLOY"}$j$, 1, true, 20, $j${"value": "DEPLOY"}$j$),
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.FREEZE', $j${"es": "FREEZE", "en": "FREEZE"}$j$, 1, true, 30, $j${"value": "FREEZE"}$j$),
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.REVERT', $j${"es": "REVERT", "en": "REVERT"}$j$, 1, true, 40, $j${"value": "REVERT"}$j$),
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.SETTLE', $j${"es": "SETTLE", "en": "SETTLE"}$j$, 1, true, 50, $j${"value": "SETTLE"}$j$),
        (v_d12_transaccion_tipo_tx, 'd12.transaccion.tipo_tx.UNFREEZE', $j${"es": "UNFREEZE", "en": "UNFREEZE"}$j$, 1, true, 60, $j${"value": "UNFREEZE"}$j$);

    -- idn_blockchain_wallet_chain_check [bauth.idn_blockchain_wallet]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.wallet.cadena', $j${"es": "Cadena", "en": "Chain"}$j$, 0, false, $j${"constraint": "idn_blockchain_wallet_chain_check", "columns": ["bauth.idn_blockchain_wallet.chain"]}$j$)
    RETURNING item_id INTO v_d12_wallet_cadena;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_wallet_cadena, 'd12.wallet.cadena.ARBITRUM', $j${"es": "ARBITRUM", "en": "ARBITRUM"}$j$, 1, true, 10, $j${"value": "ARBITRUM"}$j$),
        (v_d12_wallet_cadena, 'd12.wallet.cadena.BESU_QBFT', $j${"es": "BESU_QBFT", "en": "BESU_QBFT"}$j$, 1, true, 20, $j${"value": "BESU_QBFT"}$j$);

    -- idn_blockchain_wallet_status_check [bauth.idn_blockchain_wallet]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d12.wallet.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_blockchain_wallet_status_check", "columns": ["bauth.idn_blockchain_wallet.status"]}$j$)
    RETURNING item_id INTO v_d12_wallet_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d12_wallet_estado, 'd12.wallet.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d12_wallet_estado, 'd12.wallet.estado.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_d12_wallet_estado, 'd12.wallet.estado.FROZEN', $j${"es": "FROZEN", "en": "FROZEN"}$j$, 1, true, 30, $j${"value": "FROZEN"}$j$);

    -- chk_idcr_motivo [bauth.idn_credencial_revocacion]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d09.revocacion_cred.motivo', $j${"es": "Motivo", "en": "Motivo"}$j$, 0, false, $j${"constraint": "chk_idcr_motivo", "columns": ["bauth.idn_credencial_revocacion.motivo"]}$j$)
    RETURNING item_id INTO v_d09_revocacion_cred_motivo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.ADMIN_REVOKE', $j${"es": "ADMIN_REVOKE", "en": "ADMIN_REVOKE"}$j$, 1, true, 10, $j${"value": "ADMIN_REVOKE"}$j$),
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.COMPROMISED', $j${"es": "COMPROMISED", "en": "COMPROMISED"}$j$, 1, true, 20, $j${"value": "COMPROMISED"}$j$),
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 30, $j${"value": "EXPIRED"}$j$),
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.LOST_DEVICE', $j${"es": "LOST_DEVICE", "en": "LOST_DEVICE"}$j$, 1, true, 40, $j${"value": "LOST_DEVICE"}$j$),
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.ROTATION', $j${"es": "ROTATION", "en": "ROTATION"}$j$, 1, true, 50, $j${"value": "ROTATION"}$j$),
        (v_d09_revocacion_cred_motivo, 'd09.revocacion_cred.motivo.USER_REQUEST', $j${"es": "USER_REQUEST", "en": "USER_REQUEST"}$j$, 1, true, 60, $j${"value": "USER_REQUEST"}$j$);

    -- idn_credential_token_issued_revocation_reason_check [bauth.idn_credential_token_issued]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d09.token.motivo_revocacion', $j${"es": "Motivo de revocación", "en": "Revocation Reason"}$j$, 0, false, $j${"constraint": "idn_credential_token_issued_revocation_reason_check", "columns": ["bauth.idn_credential_token_issued.revocation_reason", "bauth.idn_credential_token_issued_2026_07.revocation_reason", "bauth.idn_credential_token_issued_2026_08.revocation_reason", "bauth.idn_credential_token_issued_2026_09.revocation_reason", "bauth.idn_credential_token_issued_default.revocation_reason"]}$j$)
    RETURNING item_id INTO v_d09_token_motivo_revocacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d09_token_motivo_revocacion, 'd09.token.motivo_revocacion.ADMIN_REVOKE', $j${"es": "ADMIN_REVOKE", "en": "ADMIN_REVOKE"}$j$, 1, true, 10, $j${"value": "ADMIN_REVOKE"}$j$),
        (v_d09_token_motivo_revocacion, 'd09.token.motivo_revocacion.CREDENTIAL_CHANGE', $j${"es": "CREDENTIAL_CHANGE", "en": "CREDENTIAL_CHANGE"}$j$, 1, true, 20, $j${"value": "CREDENTIAL_CHANGE"}$j$),
        (v_d09_token_motivo_revocacion, 'd09.token.motivo_revocacion.SESSION_EXPIRED', $j${"es": "SESSION_EXPIRED", "en": "SESSION_EXPIRED"}$j$, 1, true, 30, $j${"value": "SESSION_EXPIRED"}$j$),
        (v_d09_token_motivo_revocacion, 'd09.token.motivo_revocacion.SUSPICIOUS_ACTIVITY', $j${"es": "SUSPICIOUS_ACTIVITY", "en": "SUSPICIOUS_ACTIVITY"}$j$, 1, true, 40, $j${"value": "SUSPICIOUS_ACTIVITY"}$j$),
        (v_d09_token_motivo_revocacion, 'd09.token.motivo_revocacion.USER_LOGOUT', $j${"es": "USER_LOGOUT", "en": "USER_LOGOUT"}$j$, 1, true, 50, $j${"value": "USER_LOGOUT"}$j$);

    -- idn_credential_token_issued_token_type_check [bauth.idn_credential_token_issued]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d09.token.tipo_token', $j${"es": "Tipo de token", "en": "Token Type"}$j$, 0, false, $j${"constraint": "idn_credential_token_issued_token_type_check", "columns": ["bauth.idn_credential_token_issued.token_type", "bauth.idn_credential_token_issued_2026_07.token_type", "bauth.idn_credential_token_issued_2026_08.token_type", "bauth.idn_credential_token_issued_2026_09.token_type", "bauth.idn_credential_token_issued_default.token_type"]}$j$)
    RETURNING item_id INTO v_d09_token_tipo_token;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d09_token_tipo_token, 'd09.token.tipo_token.ACCESS', $j${"es": "ACCESS", "en": "ACCESS"}$j$, 1, true, 10, $j${"value": "ACCESS"}$j$),
        (v_d09_token_tipo_token, 'd09.token.tipo_token.DEVICE', $j${"es": "DEVICE", "en": "DEVICE"}$j$, 1, true, 20, $j${"value": "DEVICE"}$j$),
        (v_d09_token_tipo_token, 'd09.token.tipo_token.EXCHANGE', $j${"es": "EXCHANGE", "en": "EXCHANGE"}$j$, 1, true, 30, $j${"value": "EXCHANGE"}$j$),
        (v_d09_token_tipo_token, 'd09.token.tipo_token.ID', $j${"es": "ID", "en": "ID"}$j$, 1, true, 40, $j${"value": "ID"}$j$),
        (v_d09_token_tipo_token, 'd09.token.tipo_token.REFRESH', $j${"es": "REFRESH", "en": "REFRESH"}$j$, 1, true, 50, $j${"value": "REFRESH"}$j$);

    -- idn_delegation_grant_delegation_type_check [bauth.idn_delegation_grant]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d10.delegacion.tipo_delegacion', $j${"es": "Tipo de delegación", "en": "Delegation Type"}$j$, 0, false, $j${"constraint": "idn_delegation_grant_delegation_type_check", "columns": ["bauth.idn_delegation_grant.delegation_type"]}$j$)
    RETURNING item_id INTO v_d10_delegacion_tipo_delegacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d10_delegacion_tipo_delegacion, 'd10.delegacion.tipo_delegacion.AGENT', $j${"es": "AGENT", "en": "AGENT"}$j$, 1, true, 10, $j${"value": "AGENT"}$j$),
        (v_d10_delegacion_tipo_delegacion, 'd10.delegacion.tipo_delegacion.IMPERSONATION', $j${"es": "IMPERSONATION", "en": "IMPERSONATION"}$j$, 1, true, 20, $j${"value": "IMPERSONATION"}$j$),
        (v_d10_delegacion_tipo_delegacion, 'd10.delegacion.tipo_delegacion.PROXY', $j${"es": "PROXY", "en": "PROXY"}$j$, 1, true, 30, $j${"value": "PROXY"}$j$),
        (v_d10_delegacion_tipo_delegacion, 'd10.delegacion.tipo_delegacion.TOKEN_EXCHANGE', $j${"es": "TOKEN_EXCHANGE", "en": "TOKEN_EXCHANGE"}$j$, 1, true, 40, $j${"value": "TOKEN_EXCHANGE"}$j$);

    -- idn_delegation_rar_request_status_check [bauth.idn_delegation_rar_request]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d10.rar.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_delegation_rar_request_status_check", "columns": ["bauth.idn_delegation_rar_request.status"]}$j$)
    RETURNING item_id INTO v_d10_rar_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d10_rar_estado, 'd10.rar.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_d10_rar_estado, 'd10.rar.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d10_rar_estado, 'd10.rar.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$),
        (v_d10_rar_estado, 'd10.rar.estado.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 40, $j${"value": "REJECTED"}$j$);

    -- idn_delegation_restriction_restriction_type_check [bauth.idn_delegation_restriction]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d10.restriccion.tipo_restriccion', $j${"es": "Tipo de restricción", "en": "Restriction Type"}$j$, 0, false, $j${"constraint": "idn_delegation_restriction_restriction_type_check", "columns": ["bauth.idn_delegation_restriction.restriction_type"]}$j$)
    RETURNING item_id INTO v_d10_restriccion_tipo_restriccion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d10_restriccion_tipo_restriccion, 'd10.restriccion.tipo_restriccion.APPROVAL_REQUIRED', $j${"es": "APPROVAL_REQUIRED", "en": "APPROVAL_REQUIRED"}$j$, 1, true, 10, $j${"value": "APPROVAL_REQUIRED"}$j$),
        (v_d10_restriccion_tipo_restriccion, 'd10.restriccion.tipo_restriccion.HOURS_ONLY', $j${"es": "HOURS_ONLY", "en": "HOURS_ONLY"}$j$, 1, true, 20, $j${"value": "HOURS_ONLY"}$j$),
        (v_d10_restriccion_tipo_restriccion, 'd10.restriccion.tipo_restriccion.IP_WHITELIST', $j${"es": "IP_WHITELIST", "en": "IP_WHITELIST"}$j$, 1, true, 30, $j${"value": "IP_WHITELIST"}$j$),
        (v_d10_restriccion_tipo_restriccion, 'd10.restriccion.tipo_restriccion.RESOURCE_LIMIT', $j${"es": "RESOURCE_LIMIT", "en": "RESOURCE_LIMIT"}$j$, 1, true, 40, $j${"value": "RESOURCE_LIMIT"}$j$),
        (v_d10_restriccion_tipo_restriccion, 'd10.restriccion.tipo_restriccion.SCOPE_LIMIT', $j${"es": "SCOPE_LIMIT", "en": "SCOPE_LIMIT"}$j$, 1, true, 50, $j${"value": "SCOPE_LIMIT"}$j$);

    -- idn_delegation_usage_log_outcome_check [bauth.idn_delegation_usage_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d10.uso_delegacion.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "idn_delegation_usage_log_outcome_check", "columns": ["bauth.idn_delegation_usage_log.outcome", "bauth.idn_delegation_usage_log_2026_07.outcome", "bauth.idn_delegation_usage_log_2026_08.outcome", "bauth.idn_delegation_usage_log_default.outcome"]}$j$)
    RETURNING item_id INTO v_d10_uso_delegacion_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d10_uso_delegacion_resultado, 'd10.uso_delegacion.resultado.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_d10_uso_delegacion_resultado, 'd10.uso_delegacion.resultado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 20, $j${"value": "ERROR"}$j$),
        (v_d10_uso_delegacion_resultado, 'd10.uso_delegacion.resultado.PERMIT', $j${"es": "PERMIT", "en": "PERMIT"}$j$, 1, true, 30, $j${"value": "PERMIT"}$j$);

    -- chk_idd_status [bauth.idn_did_document]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.did.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_idd_status", "columns": ["bauth.idn_did_document.status"]}$j$)
    RETURNING item_id INTO v_identidad_did_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_did_estado, 'identidad.did.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_identidad_did_estado, 'identidad.did.estado.DEACTIVATED', $j${"es": "DEACTIVATED", "en": "DEACTIVATED"}$j$, 1, true, 20, $j${"value": "DEACTIVATED"}$j$),
        (v_identidad_did_estado, 'identidad.did.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 30, $j${"value": "EXPIRED"}$j$),
        (v_identidad_did_estado, 'identidad.did.estado.INVALID', $j${"es": "INVALID", "en": "INVALID"}$j$, 1, true, 40, $j${"value": "INVALID"}$j$);

    -- chk_idpia_estado [bauth.idn_dpia_registro]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('privacidad.dpia_reg.estado', $j${"es": "Estado", "en": "Estado"}$j$, 0, false, $j${"constraint": "chk_idpia_estado", "columns": ["bauth.idn_dpia_registro.estado"]}$j$)
    RETURNING item_id INTO v_privacidad_dpia_reg_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.DRAFT', $j${"es": "DRAFT", "en": "DRAFT"}$j$, 1, true, 30, $j${"value": "DRAFT"}$j$),
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.IN_REVIEW', $j${"es": "IN_REVIEW", "en": "IN_REVIEW"}$j$, 1, true, 40, $j${"value": "IN_REVIEW"}$j$),
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 50, $j${"value": "REJECTED"}$j$),
        (v_privacidad_dpia_reg_estado, 'privacidad.dpia_reg.estado.REQUIRES_DPA', $j${"es": "REQUIRES_DPA", "en": "REQUIRES_DPA"}$j$, 1, true, 60, $j${"value": "REQUIRES_DPA"}$j$);

    -- chk_idpia_riesgo [bauth.idn_dpia_registro]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('privacidad.dpia_reg.riesgo_residual', $j${"es": "Riesgo residual (DPIA)", "en": "Riesgo Residual"}$j$, 0, false, $j${"constraint": "chk_idpia_riesgo", "columns": ["bauth.idn_dpia_registro.riesgo_residual"]}$j$)
    RETURNING item_id INTO v_privacidad_dpia_reg_riesgo_residual;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_privacidad_dpia_reg_riesgo_residual, 'privacidad.dpia_reg.riesgo_residual.HIGH', $j${"es": "HIGH", "en": "HIGH"}$j$, 1, true, 10, $j${"value": "HIGH"}$j$),
        (v_privacidad_dpia_reg_riesgo_residual, 'privacidad.dpia_reg.riesgo_residual.LOW', $j${"es": "LOW", "en": "LOW"}$j$, 1, true, 20, $j${"value": "LOW"}$j$),
        (v_privacidad_dpia_reg_riesgo_residual, 'privacidad.dpia_reg.riesgo_residual.MEDIUM', $j${"es": "MEDIUM", "en": "MEDIUM"}$j$, 1, true, 30, $j${"value": "MEDIUM"}$j$),
        (v_privacidad_dpia_reg_riesgo_residual, 'privacidad.dpia_reg.riesgo_residual.VERY_HIGH', $j${"es": "VERY_HIGH", "en": "VERY_HIGH"}$j$, 1, true, 40, $j${"value": "VERY_HIGH"}$j$);

END $$;

-- ── Bloque 4/11 ───────────────────────────────
DO $$
DECLARE
    v_d03_aprobacion_tipo_operacion UUID;
    v_d03_voto_decision UUID;
    v_d03_fraude_tipo_alerta UUID;
    v_d03_fraude_resultado UUID;
    v_d03_factura_estado_sin UUID;
    v_d03_limite_tipo_operacion UUID;
    v_d03_limite_alcance UUID;
    v_d03_limite_estado UUID;
    v_d03_reconciliacion_tipo_reconciliacion UUID;
    v_d03_reconciliacion_estado UUID;
    v_d03_reporte_tipo_reporte UUID;
    v_d03_reporte_estado UUID;
    v_d03_sod_tipo_conflicto UUID;
    v_d03_tpp_perfil_fapi UUID;
    v_d03_tpp_revocado_por UUID;
    v_d06_residencia_aplica_a UUID;
    v_d06_residencia_accion_violacion UUID;
    v_d06_geocerca_accion_dentro UUID;
    v_d06_geocerca_accion_fuera UUID;
    v_d06_geocerca_tipo_geocerca UUID;
    v_d06_ubicacion_fuente_ubicacion UUID;
    v_d99_admin_rol_admin UUID;
    v_d99_cumplimiento_estado UUID;
    v_d99_cripto_familia_algoritmo UUID;
    v_d99_hitl_tipo_entidad UUID;
BEGIN

    -- idn_financial_approval_operation_type_check [bauth.idn_financial_approval]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.aprobacion.tipo_operacion', $j${"es": "Tipo de operación", "en": "Operation Type"}$j$, 0, false, $j${"constraint": "idn_financial_approval_operation_type_check", "columns": ["bauth.idn_financial_approval.operation_type"]}$j$)
    RETURNING item_id INTO v_d03_aprobacion_tipo_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_aprobacion_tipo_operacion, 'd03.aprobacion.tipo_operacion.ACCOUNTING', $j${"es": "ACCOUNTING", "en": "ACCOUNTING"}$j$, 1, true, 10, $j${"value": "ACCOUNTING"}$j$),
        (v_d03_aprobacion_tipo_operacion, 'd03.aprobacion.tipo_operacion.APPROVAL', $j${"es": "APPROVAL", "en": "APPROVAL"}$j$, 1, true, 20, $j${"value": "APPROVAL"}$j$),
        (v_d03_aprobacion_tipo_operacion, 'd03.aprobacion.tipo_operacion.ISSUANCE', $j${"es": "ISSUANCE", "en": "ISSUANCE"}$j$, 1, true, 30, $j${"value": "ISSUANCE"}$j$),
        (v_d03_aprobacion_tipo_operacion, 'd03.aprobacion.tipo_operacion.PAYMENT', $j${"es": "PAYMENT", "en": "PAYMENT"}$j$, 1, true, 40, $j${"value": "PAYMENT"}$j$),
        (v_d03_aprobacion_tipo_operacion, 'd03.aprobacion.tipo_operacion.TRANSFER', $j${"es": "TRANSFER", "en": "TRANSFER"}$j$, 1, true, 50, $j${"value": "TRANSFER"}$j$);

    -- idn_financial_approval_vote_decision_check [bauth.idn_financial_approval_vote]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.voto.decision', $j${"es": "Decisión", "en": "Decision"}$j$, 0, false, $j${"constraint": "idn_financial_approval_vote_decision_check", "columns": ["bauth.idn_financial_approval_vote.decision"]}$j$)
    RETURNING item_id INTO v_d03_voto_decision;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_voto_decision, 'd03.voto.decision.ABSTAIN', $j${"es": "ABSTAIN", "en": "ABSTAIN"}$j$, 1, true, 10, $j${"value": "ABSTAIN"}$j$),
        (v_d03_voto_decision, 'd03.voto.decision.APPROVE', $j${"es": "APPROVE", "en": "APPROVE"}$j$, 1, true, 20, $j${"value": "APPROVE"}$j$),
        (v_d03_voto_decision, 'd03.voto.decision.REJECT', $j${"es": "REJECT", "en": "REJECT"}$j$, 1, true, 30, $j${"value": "REJECT"}$j$);

    -- idn_financial_fraud_alert_alert_type_check [bauth.idn_financial_fraud_alert]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.fraude.tipo_alerta', $j${"es": "Tipo de alerta de fraude", "en": "Alert Type"}$j$, 0, false, $j${"constraint": "idn_financial_fraud_alert_alert_type_check", "columns": ["bauth.idn_financial_fraud_alert.alert_type"]}$j$)
    RETURNING item_id INTO v_d03_fraude_tipo_alerta;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.ANOMALOUS_LOCATION', $j${"es": "ANOMALOUS_LOCATION", "en": "ANOMALOUS_LOCATION"}$j$, 1, true, 10, $j${"value": "ANOMALOUS_LOCATION"}$j$),
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.MULTIPLE_REJECTIONS', $j${"es": "MULTIPLE_REJECTIONS", "en": "MULTIPLE_REJECTIONS"}$j$, 1, true, 20, $j${"value": "MULTIPLE_REJECTIONS"}$j$),
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.SOD_VIOLATION', $j${"es": "SOD_VIOLATION", "en": "SOD_VIOLATION"}$j$, 1, true, 30, $j${"value": "SOD_VIOLATION"}$j$),
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.TIME_PATTERN', $j${"es": "TIME_PATTERN", "en": "TIME_PATTERN"}$j$, 1, true, 40, $j${"value": "TIME_PATTERN"}$j$),
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.UNUSUAL_AMOUNT', $j${"es": "UNUSUAL_AMOUNT", "en": "UNUSUAL_AMOUNT"}$j$, 1, true, 50, $j${"value": "UNUSUAL_AMOUNT"}$j$),
        (v_d03_fraude_tipo_alerta, 'd03.fraude.tipo_alerta.VELOCITY_CHECK', $j${"es": "VELOCITY_CHECK", "en": "VELOCITY_CHECK"}$j$, 1, true, 60, $j${"value": "VELOCITY_CHECK"}$j$);

    -- idn_financial_fraud_alert_result_check [bauth.idn_financial_fraud_alert]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.fraude.resultado', $j${"es": "Resultado", "en": "Result"}$j$, 0, false, $j${"constraint": "idn_financial_fraud_alert_result_check", "columns": ["bauth.idn_financial_fraud_alert.result"]}$j$)
    RETURNING item_id INTO v_d03_fraude_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_fraude_resultado, 'd03.fraude.resultado.ESCALATED', $j${"es": "ESCALATED", "en": "ESCALATED"}$j$, 1, true, 10, $j${"value": "ESCALATED"}$j$),
        (v_d03_fraude_resultado, 'd03.fraude.resultado.FALSE_POSITIVE', $j${"es": "FALSE_POSITIVE", "en": "FALSE_POSITIVE"}$j$, 1, true, 20, $j${"value": "FALSE_POSITIVE"}$j$),
        (v_d03_fraude_resultado, 'd03.fraude.resultado.FRAUD_CONFIRMED', $j${"es": "FRAUD_CONFIRMED", "en": "FRAUD_CONFIRMED"}$j$, 1, true, 30, $j${"value": "FRAUD_CONFIRMED"}$j$),
        (v_d03_fraude_resultado, 'd03.fraude.resultado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 40, $j${"value": "PENDING"}$j$);

    -- idn_financial_invoice_auth_sin_status_check [bauth.idn_financial_invoice_auth]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.factura.estado_sin', $j${"es": "Estado SIN Bolivia", "en": "Sin Status"}$j$, 0, false, $j${"constraint": "idn_financial_invoice_auth_sin_status_check", "columns": ["bauth.idn_financial_invoice_auth.sin_status"]}$j$)
    RETURNING item_id INTO v_d03_factura_estado_sin;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_factura_estado_sin, 'd03.factura.estado_sin.AUTHORIZED', $j${"es": "AUTHORIZED", "en": "AUTHORIZED"}$j$, 1, true, 10, $j${"value": "AUTHORIZED"}$j$),
        (v_d03_factura_estado_sin, 'd03.factura.estado_sin.CANCELLED', $j${"es": "CANCELLED", "en": "CANCELLED"}$j$, 1, true, 20, $j${"value": "CANCELLED"}$j$),
        (v_d03_factura_estado_sin, 'd03.factura.estado_sin.CONTINGENCY', $j${"es": "CONTINGENCY", "en": "CONTINGENCY"}$j$, 1, true, 30, $j${"value": "CONTINGENCY"}$j$),
        (v_d03_factura_estado_sin, 'd03.factura.estado_sin.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 40, $j${"value": "PENDING"}$j$),
        (v_d03_factura_estado_sin, 'd03.factura.estado_sin.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 50, $j${"value": "REJECTED"}$j$);

    -- idn_financial_limit_operation_type_check [bauth.idn_financial_limit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.limite.tipo_operacion', $j${"es": "Tipo de operación", "en": "Operation Type"}$j$, 0, false, $j${"constraint": "idn_financial_limit_operation_type_check", "columns": ["bauth.idn_financial_limit.operation_type"]}$j$)
    RETURNING item_id INTO v_d03_limite_tipo_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.ACCOUNTING', $j${"es": "ACCOUNTING", "en": "ACCOUNTING"}$j$, 1, true, 10, $j${"value": "ACCOUNTING"}$j$),
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.APPROVAL', $j${"es": "APPROVAL", "en": "APPROVAL"}$j$, 1, true, 20, $j${"value": "APPROVAL"}$j$),
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.GENERAL', $j${"es": "GENERAL", "en": "GENERAL"}$j$, 1, true, 30, $j${"value": "GENERAL"}$j$),
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.ISSUANCE', $j${"es": "ISSUANCE", "en": "ISSUANCE"}$j$, 1, true, 40, $j${"value": "ISSUANCE"}$j$),
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.PAYMENT', $j${"es": "PAYMENT", "en": "PAYMENT"}$j$, 1, true, 50, $j${"value": "PAYMENT"}$j$),
        (v_d03_limite_tipo_operacion, 'd03.limite.tipo_operacion.TRANSFER', $j${"es": "TRANSFER", "en": "TRANSFER"}$j$, 1, true, 60, $j${"value": "TRANSFER"}$j$);

    -- idn_financial_limit_scope_check [bauth.idn_financial_limit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.limite.alcance', $j${"es": "Alcance", "en": "Scope"}$j$, 0, false, $j${"constraint": "idn_financial_limit_scope_check", "columns": ["bauth.idn_financial_limit.scope"]}$j$)
    RETURNING item_id INTO v_d03_limite_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_limite_alcance, 'd03.limite.alcance.CLIENT', $j${"es": "CLIENT", "en": "CLIENT"}$j$, 1, true, 10, $j${"value": "CLIENT"}$j$),
        (v_d03_limite_alcance, 'd03.limite.alcance.ENTITY', $j${"es": "ENTITY", "en": "ENTITY"}$j$, 1, true, 20, $j${"value": "ENTITY"}$j$),
        (v_d03_limite_alcance, 'd03.limite.alcance.ROLE', $j${"es": "ROLE", "en": "ROLE"}$j$, 1, true, 30, $j${"value": "ROLE"}$j$),
        (v_d03_limite_alcance, 'd03.limite.alcance.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 40, $j${"value": "USER"}$j$);

    -- idn_financial_limit_status_check [bauth.idn_financial_limit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.limite.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_financial_limit_status_check", "columns": ["bauth.idn_financial_limit.status", "bauth.idn_geospatial_geofence.status", "bauth.idn_network_connection_policy.status", "bauth.idn_network_dlp_policy.status", "bauth.idn_network_posture_policy.status"]}$j$)
    RETURNING item_id INTO v_d03_limite_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_limite_estado, 'd03.limite.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d03_limite_estado, 'd03.limite.estado.DISABLED', $j${"es": "DISABLED", "en": "DISABLED"}$j$, 1, true, 20, $j${"value": "DISABLED"}$j$),
        (v_d03_limite_estado, 'd03.limite.estado.DRAFT', $j${"es": "DRAFT", "en": "DRAFT"}$j$, 1, true, 30, $j${"value": "DRAFT"}$j$);

    -- idn_financial_reconciliation_reconciliation_type_check [bauth.idn_financial_reconciliation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.reconciliacion.tipo_reconciliacion', $j${"es": "Tipo de reconciliación", "en": "Reconciliation Type"}$j$, 0, false, $j${"constraint": "idn_financial_reconciliation_reconciliation_type_check", "columns": ["bauth.idn_financial_reconciliation.reconciliation_type"]}$j$)
    RETURNING item_id INTO v_d03_reconciliacion_tipo_reconciliacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_reconciliacion_tipo_reconciliacion, 'd03.reconciliacion.tipo_reconciliacion.ANNUAL', $j${"es": "ANNUAL", "en": "ANNUAL"}$j$, 1, true, 10, $j${"value": "ANNUAL"}$j$),
        (v_d03_reconciliacion_tipo_reconciliacion, 'd03.reconciliacion.tipo_reconciliacion.DAILY', $j${"es": "DAILY", "en": "DAILY"}$j$, 1, true, 20, $j${"value": "DAILY"}$j$),
        (v_d03_reconciliacion_tipo_reconciliacion, 'd03.reconciliacion.tipo_reconciliacion.MONTHLY', $j${"es": "MONTHLY", "en": "MONTHLY"}$j$, 1, true, 30, $j${"value": "MONTHLY"}$j$),
        (v_d03_reconciliacion_tipo_reconciliacion, 'd03.reconciliacion.tipo_reconciliacion.QUARTERLY', $j${"es": "QUARTERLY", "en": "QUARTERLY"}$j$, 1, true, 40, $j${"value": "QUARTERLY"}$j$);

    -- idn_financial_reconciliation_status_check [bauth.idn_financial_reconciliation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.reconciliacion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_financial_reconciliation_status_check", "columns": ["bauth.idn_financial_reconciliation.status"]}$j$)
    RETURNING item_id INTO v_d03_reconciliacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_reconciliacion_estado, 'd03.reconciliacion.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_d03_reconciliacion_estado, 'd03.reconciliacion.estado.COMPLETED', $j${"es": "COMPLETED", "en": "COMPLETED"}$j$, 1, true, 20, $j${"value": "COMPLETED"}$j$),
        (v_d03_reconciliacion_estado, 'd03.reconciliacion.estado.IN_PROGRESS', $j${"es": "IN_PROGRESS", "en": "IN_PROGRESS"}$j$, 1, true, 30, $j${"value": "IN_PROGRESS"}$j$),
        (v_d03_reconciliacion_estado, 'd03.reconciliacion.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 40, $j${"value": "PENDING"}$j$),
        (v_d03_reconciliacion_estado, 'd03.reconciliacion.estado.WITH_DIFFERENCES', $j${"es": "WITH_DIFFERENCES", "en": "WITH_DIFFERENCES"}$j$, 1, true, 50, $j${"value": "WITH_DIFFERENCES"}$j$);

    -- idn_financial_report_report_type_check [bauth.idn_financial_report]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.reporte.tipo_reporte', $j${"es": "Tipo de reporte", "en": "Report Type"}$j$, 0, false, $j${"constraint": "idn_financial_report_report_type_check", "columns": ["bauth.idn_financial_report.report_type"]}$j$)
    RETURNING item_id INTO v_d03_reporte_tipo_reporte;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.ANNUAL', $j${"es": "ANNUAL", "en": "ANNUAL"}$j$, 1, true, 10, $j${"value": "ANNUAL"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.AUDIT', $j${"es": "AUDIT", "en": "AUDIT"}$j$, 1, true, 20, $j${"value": "AUDIT"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.INCIDENT', $j${"es": "INCIDENT", "en": "INCIDENT"}$j$, 1, true, 30, $j${"value": "INCIDENT"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.PCI_DSS', $j${"es": "PCI_DSS", "en": "PCI_DSS"}$j$, 1, true, 40, $j${"value": "PCI_DSS"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.QUARTERLY', $j${"es": "QUARTERLY", "en": "QUARTERLY"}$j$, 1, true, 50, $j${"value": "QUARTERLY"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.SOX_302', $j${"es": "SOX_302", "en": "SOX_302"}$j$, 1, true, 60, $j${"value": "SOX_302"}$j$),
        (v_d03_reporte_tipo_reporte, 'd03.reporte.tipo_reporte.SOX_404', $j${"es": "SOX_404", "en": "SOX_404"}$j$, 1, true, 70, $j${"value": "SOX_404"}$j$);

    -- idn_financial_report_status_check [bauth.idn_financial_report]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.reporte.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_financial_report_status_check", "columns": ["bauth.idn_financial_report.status"]}$j$)
    RETURNING item_id INTO v_d03_reporte_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_reporte_estado, 'd03.reporte.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_d03_reporte_estado, 'd03.reporte.estado.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_d03_reporte_estado, 'd03.reporte.estado.DRAFT', $j${"es": "DRAFT", "en": "DRAFT"}$j$, 1, true, 30, $j${"value": "DRAFT"}$j$),
        (v_d03_reporte_estado, 'd03.reporte.estado.PUBLISHED', $j${"es": "PUBLISHED", "en": "PUBLISHED"}$j$, 1, true, 40, $j${"value": "PUBLISHED"}$j$),
        (v_d03_reporte_estado, 'd03.reporte.estado.REVIEW', $j${"es": "REVIEW", "en": "REVIEW"}$j$, 1, true, 50, $j${"value": "REVIEW"}$j$);

    -- idn_financial_sod_rule_conflict_type_check [bauth.idn_financial_sod_rule]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.sod.tipo_conflicto', $j${"es": "Tipo de conflicto", "en": "Conflict Type"}$j$, 0, false, $j${"constraint": "idn_financial_sod_rule_conflict_type_check", "columns": ["bauth.idn_financial_sod_rule.conflict_type"]}$j$)
    RETURNING item_id INTO v_d03_sod_tipo_conflicto;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_sod_tipo_conflicto, 'd03.sod.tipo_conflicto.MUTUALLY_EXCLUSIVE', $j${"es": "MUTUALLY_EXCLUSIVE", "en": "MUTUALLY_EXCLUSIVE"}$j$, 1, true, 10, $j${"value": "MUTUALLY_EXCLUSIVE"}$j$),
        (v_d03_sod_tipo_conflicto, 'd03.sod.tipo_conflicto.REQUIRES_APPROVAL', $j${"es": "REQUIRES_APPROVAL", "en": "REQUIRES_APPROVAL"}$j$, 1, true, 20, $j${"value": "REQUIRES_APPROVAL"}$j$),
        (v_d03_sod_tipo_conflicto, 'd03.sod.tipo_conflicto.SEQUENTIAL_ONLY', $j${"es": "SEQUENTIAL_ONLY", "en": "SEQUENTIAL_ONLY"}$j$, 1, true, 30, $j${"value": "SEQUENTIAL_ONLY"}$j$);

    -- idn_financial_tpp_consent_fapi_profile_check [bauth.idn_financial_tpp_consent]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.tpp.perfil_fapi', $j${"es": "Perfil FAPI", "en": "Fapi Profile"}$j$, 0, false, $j${"constraint": "idn_financial_tpp_consent_fapi_profile_check", "columns": ["bauth.idn_financial_tpp_consent.fapi_profile"]}$j$)
    RETURNING item_id INTO v_d03_tpp_perfil_fapi;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_tpp_perfil_fapi, 'd03.tpp.perfil_fapi.FAPI_1_0', $j${"es": "FAPI_1_0", "en": "FAPI_1_0"}$j$, 1, true, 10, $j${"value": "FAPI_1_0"}$j$),
        (v_d03_tpp_perfil_fapi, 'd03.tpp.perfil_fapi.FAPI_2_0', $j${"es": "FAPI_2_0", "en": "FAPI_2_0"}$j$, 1, true, 20, $j${"value": "FAPI_2_0"}$j$);

    -- idn_financial_tpp_consent_revoked_by_check [bauth.idn_financial_tpp_consent]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d03.tpp.revocado_por', $j${"es": "Revocado por", "en": "Revoked By"}$j$, 0, false, $j${"constraint": "idn_financial_tpp_consent_revoked_by_check", "columns": ["bauth.idn_financial_tpp_consent.revoked_by"]}$j$)
    RETURNING item_id INTO v_d03_tpp_revocado_por;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d03_tpp_revocado_por, 'd03.tpp.revocado_por.ADMIN', $j${"es": "ADMIN", "en": "ADMIN"}$j$, 1, true, 10, $j${"value": "ADMIN"}$j$),
        (v_d03_tpp_revocado_por, 'd03.tpp.revocado_por.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d03_tpp_revocado_por, 'd03.tpp.revocado_por.REGULATOR', $j${"es": "REGULATOR", "en": "REGULATOR"}$j$, 1, true, 30, $j${"value": "REGULATOR"}$j$),
        (v_d03_tpp_revocado_por, 'd03.tpp.revocado_por.TPP', $j${"es": "TPP", "en": "TPP"}$j$, 1, true, 40, $j${"value": "TPP"}$j$),
        (v_d03_tpp_revocado_por, 'd03.tpp.revocado_por.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 50, $j${"value": "USER"}$j$);

    -- idn_geospatial_data_residency_apply_to_check [bauth.idn_geospatial_data_residency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.residencia.aplica_a', $j${"es": "Aplica a", "en": "Apply To"}$j$, 0, false, $j${"constraint": "idn_geospatial_data_residency_apply_to_check", "columns": ["bauth.idn_geospatial_data_residency.apply_to"]}$j$)
    RETURNING item_id INTO v_d06_residencia_aplica_a;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_residencia_aplica_a, 'd06.residencia.aplica_a.ALL', $j${"es": "ALL", "en": "ALL"}$j$, 1, true, 10, $j${"value": "ALL"}$j$),
        (v_d06_residencia_aplica_a, 'd06.residencia.aplica_a.AUTH_ONLY', $j${"es": "AUTH_ONLY", "en": "AUTH_ONLY"}$j$, 1, true, 20, $j${"value": "AUTH_ONLY"}$j$),
        (v_d06_residencia_aplica_a, 'd06.residencia.aplica_a.DATA_RESIDENCY', $j${"es": "DATA_RESIDENCY", "en": "DATA_RESIDENCY"}$j$, 1, true, 30, $j${"value": "DATA_RESIDENCY"}$j$),
        (v_d06_residencia_aplica_a, 'd06.residencia.aplica_a.STORAGE', $j${"es": "STORAGE", "en": "STORAGE"}$j$, 1, true, 40, $j${"value": "STORAGE"}$j$);

    -- idn_geospatial_data_residency_violation_action_check [bauth.idn_geospatial_data_residency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.residencia.accion_violacion', $j${"es": "Acción en violación", "en": "Violation Action"}$j$, 0, false, $j${"constraint": "idn_geospatial_data_residency_violation_action_check", "columns": ["bauth.idn_geospatial_data_residency.violation_action"]}$j$)
    RETURNING item_id INTO v_d06_residencia_accion_violacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_residencia_accion_violacion, 'd06.residencia.accion_violacion.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_d06_residencia_accion_violacion, 'd06.residencia.accion_violacion.LOG', $j${"es": "LOG", "en": "LOG"}$j$, 1, true, 20, $j${"value": "LOG"}$j$),
        (v_d06_residencia_accion_violacion, 'd06.residencia.accion_violacion.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 30, $j${"value": "NOTIFY"}$j$),
        (v_d06_residencia_accion_violacion, 'd06.residencia.accion_violacion.QUARANTINE', $j${"es": "QUARANTINE", "en": "QUARANTINE"}$j$, 1, true, 40, $j${"value": "QUARANTINE"}$j$);

    -- idn_geospatial_geofence_action_inside_check [bauth.idn_geospatial_geofence]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.geocerca.accion_dentro', $j${"es": "Acción dentro de geocerca", "en": "Action Inside"}$j$, 0, false, $j${"constraint": "idn_geospatial_geofence_action_inside_check", "columns": ["bauth.idn_geospatial_geofence.action_inside"]}$j$)
    RETURNING item_id INTO v_d06_geocerca_accion_dentro;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_geocerca_accion_dentro, 'd06.geocerca.accion_dentro.ALLOW', $j${"es": "ALLOW", "en": "ALLOW"}$j$, 1, true, 10, $j${"value": "ALLOW"}$j$),
        (v_d06_geocerca_accion_dentro, 'd06.geocerca.accion_dentro.LOG', $j${"es": "LOG", "en": "LOG"}$j$, 1, true, 20, $j${"value": "LOG"}$j$),
        (v_d06_geocerca_accion_dentro, 'd06.geocerca.accion_dentro.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 30, $j${"value": "NOTIFY"}$j$),
        (v_d06_geocerca_accion_dentro, 'd06.geocerca.accion_dentro.STEP_UP', $j${"es": "STEP_UP", "en": "STEP_UP"}$j$, 1, true, 40, $j${"value": "STEP_UP"}$j$);

    -- idn_geospatial_geofence_action_outside_check [bauth.idn_geospatial_geofence]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.geocerca.accion_fuera', $j${"es": "Acción fuera de geocerca", "en": "Action Outside"}$j$, 0, false, $j${"constraint": "idn_geospatial_geofence_action_outside_check", "columns": ["bauth.idn_geospatial_geofence.action_outside", "bauth.idn_geospatial_velocity_policy.action"]}$j$)
    RETURNING item_id INTO v_d06_geocerca_accion_fuera;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_geocerca_accion_fuera, 'd06.geocerca.accion_fuera.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_d06_geocerca_accion_fuera, 'd06.geocerca.accion_fuera.LOG', $j${"es": "LOG", "en": "LOG"}$j$, 1, true, 20, $j${"value": "LOG"}$j$),
        (v_d06_geocerca_accion_fuera, 'd06.geocerca.accion_fuera.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 30, $j${"value": "NOTIFY"}$j$),
        (v_d06_geocerca_accion_fuera, 'd06.geocerca.accion_fuera.STEP_UP', $j${"es": "STEP_UP", "en": "STEP_UP"}$j$, 1, true, 40, $j${"value": "STEP_UP"}$j$);

    -- idn_geospatial_geofence_fence_type_check [bauth.idn_geospatial_geofence]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.geocerca.tipo_geocerca', $j${"es": "Tipo de geocerca", "en": "Fence Type"}$j$, 0, false, $j${"constraint": "idn_geospatial_geofence_fence_type_check", "columns": ["bauth.idn_geospatial_geofence.fence_type"]}$j$)
    RETURNING item_id INTO v_d06_geocerca_tipo_geocerca;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_geocerca_tipo_geocerca, 'd06.geocerca.tipo_geocerca.CIRCLE', $j${"es": "CIRCLE", "en": "CIRCLE"}$j$, 1, true, 10, $j${"value": "CIRCLE"}$j$),
        (v_d06_geocerca_tipo_geocerca, 'd06.geocerca.tipo_geocerca.CITY', $j${"es": "CITY", "en": "CITY"}$j$, 1, true, 20, $j${"value": "CITY"}$j$),
        (v_d06_geocerca_tipo_geocerca, 'd06.geocerca.tipo_geocerca.COUNTRY', $j${"es": "COUNTRY", "en": "COUNTRY"}$j$, 1, true, 30, $j${"value": "COUNTRY"}$j$),
        (v_d06_geocerca_tipo_geocerca, 'd06.geocerca.tipo_geocerca.POLYGON', $j${"es": "POLYGON", "en": "POLYGON"}$j$, 1, true, 40, $j${"value": "POLYGON"}$j$),
        (v_d06_geocerca_tipo_geocerca, 'd06.geocerca.tipo_geocerca.REGION', $j${"es": "REGION", "en": "REGION"}$j$, 1, true, 50, $j${"value": "REGION"}$j$);

    -- idn_geospatial_location_log_location_source_check [bauth.idn_geospatial_location_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d06.ubicacion.fuente_ubicacion', $j${"es": "Fuente de ubicación", "en": "Location Source"}$j$, 0, false, $j${"constraint": "idn_geospatial_location_log_location_source_check", "columns": ["bauth.idn_geospatial_location_log.location_source", "bauth.idn_geospatial_location_log_2026_07.location_source", "bauth.idn_geospatial_location_log_2026_08.location_source", "bauth.idn_geospatial_location_log_default.location_source"]}$j$)
    RETURNING item_id INTO v_d06_ubicacion_fuente_ubicacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.BEACON', $j${"es": "BEACON", "en": "BEACON"}$j$, 1, true, 10, $j${"value": "BEACON"}$j$),
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.CELL', $j${"es": "CELL", "en": "CELL"}$j$, 1, true, 20, $j${"value": "CELL"}$j$),
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.GPS', $j${"es": "GPS", "en": "GPS"}$j$, 1, true, 30, $j${"value": "GPS"}$j$),
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.IP_GEOIP', $j${"es": "IP_GEOIP", "en": "IP_GEOIP"}$j$, 1, true, 40, $j${"value": "IP_GEOIP"}$j$),
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 50, $j${"value": "MANUAL"}$j$),
        (v_d06_ubicacion_fuente_ubicacion, 'd06.ubicacion.fuente_ubicacion.WIFI', $j${"es": "WIFI", "en": "WIFI"}$j$, 1, true, 60, $j${"value": "WIFI"}$j$);

    -- idn_global_admin_admin_role_check [bauth.idn_global_admin]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.admin.rol_admin', $j${"es": "Rol de administrador global", "en": "Admin Role"}$j$, 0, false, $j${"constraint": "idn_global_admin_admin_role_check", "columns": ["bauth.idn_global_admin.admin_role"]}$j$)
    RETURNING item_id INTO v_d99_admin_rol_admin;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_admin_rol_admin, 'd99.admin.rol_admin.AUDIT_ADMIN', $j${"es": "AUDIT_ADMIN", "en": "AUDIT_ADMIN"}$j$, 1, true, 10, $j${"value": "AUDIT_ADMIN"}$j$),
        (v_d99_admin_rol_admin, 'd99.admin.rol_admin.SECURITY_ADMIN', $j${"es": "SECURITY_ADMIN", "en": "SECURITY_ADMIN"}$j$, 1, true, 20, $j${"value": "SECURITY_ADMIN"}$j$),
        (v_d99_admin_rol_admin, 'd99.admin.rol_admin.SUPER_ADMIN', $j${"es": "SUPER_ADMIN", "en": "SUPER_ADMIN"}$j$, 1, true, 30, $j${"value": "SUPER_ADMIN"}$j$),
        (v_d99_admin_rol_admin, 'd99.admin.rol_admin.SUPPORT_ADMIN', $j${"es": "SUPPORT_ADMIN", "en": "SUPPORT_ADMIN"}$j$, 1, true, 40, $j${"value": "SUPPORT_ADMIN"}$j$);

    -- idn_global_compliance_control_status_check [bauth.idn_global_compliance_control]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.cumplimiento.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_global_compliance_control_status_check", "columns": ["bauth.idn_global_compliance_control.status"]}$j$)
    RETURNING item_id INTO v_d99_cumplimiento_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_cumplimiento_estado, 'd99.cumplimiento.estado.GAP', $j${"es": "GAP", "en": "GAP"}$j$, 1, true, 10, $j${"value": "GAP"}$j$),
        (v_d99_cumplimiento_estado, 'd99.cumplimiento.estado.IMPLEMENTED', $j${"es": "IMPLEMENTED", "en": "IMPLEMENTED"}$j$, 1, true, 20, $j${"value": "IMPLEMENTED"}$j$),
        (v_d99_cumplimiento_estado, 'd99.cumplimiento.estado.NOT_APPLICABLE', $j${"es": "NOT_APPLICABLE", "en": "NOT_APPLICABLE"}$j$, 1, true, 30, $j${"value": "NOT_APPLICABLE"}$j$),
        (v_d99_cumplimiento_estado, 'd99.cumplimiento.estado.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 40, $j${"value": "PARTIAL"}$j$),
        (v_d99_cumplimiento_estado, 'd99.cumplimiento.estado.PLANNED', $j${"es": "PLANNED", "en": "PLANNED"}$j$, 1, true, 50, $j${"value": "PLANNED"}$j$);

    -- idn_global_crypto_params_algorithm_family_check [bauth.idn_global_crypto_params]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.cripto.familia_algoritmo', $j${"es": "Familia de algoritmo", "en": "Algorithm Family"}$j$, 0, false, $j${"constraint": "idn_global_crypto_params_algorithm_family_check", "columns": ["bauth.idn_global_crypto_params.algorithm_family"]}$j$)
    RETURNING item_id INTO v_d99_cripto_familia_algoritmo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.ASYMMETRIC', $j${"es": "ASYMMETRIC", "en": "ASYMMETRIC"}$j$, 1, true, 10, $j${"value": "ASYMMETRIC"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.HASH', $j${"es": "HASH", "en": "HASH"}$j$, 1, true, 20, $j${"value": "HASH"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.KDF', $j${"es": "KDF", "en": "KDF"}$j$, 1, true, 30, $j${"value": "KDF"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.KEM', $j${"es": "KEM", "en": "KEM"}$j$, 1, true, 40, $j${"value": "KEM"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.MAC', $j${"es": "MAC", "en": "MAC"}$j$, 1, true, 50, $j${"value": "MAC"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.SIGNATURE', $j${"es": "SIGNATURE", "en": "SIGNATURE"}$j$, 1, true, 60, $j${"value": "SIGNATURE"}$j$),
        (v_d99_cripto_familia_algoritmo, 'd99.cripto.familia_algoritmo.SYMMETRIC', $j${"es": "SYMMETRIC", "en": "SYMMETRIC"}$j$, 1, true, 70, $j${"value": "SYMMETRIC"}$j$);

    -- idn_global_hitl_exception_affected_entity_type_check [bauth.idn_global_hitl_exception]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.hitl.tipo_entidad', $j${"es": "Tipo de entidad afectada", "en": "Affected Entity Type"}$j$, 0, false, $j${"constraint": "idn_global_hitl_exception_affected_entity_type_check", "columns": ["bauth.idn_global_hitl_exception.affected_entity_type"]}$j$)
    RETURNING item_id INTO v_d99_hitl_tipo_entidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.ALGORITHM', $j${"es": "ALGORITHM", "en": "ALGORITHM"}$j$, 1, true, 10, $j${"value": "ALGORITHM"}$j$),
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.CERT', $j${"es": "CERT", "en": "CERT"}$j$, 1, true, 20, $j${"value": "CERT"}$j$),
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.POLICY', $j${"es": "POLICY", "en": "POLICY"}$j$, 1, true, 30, $j${"value": "POLICY"}$j$),
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.ROLE', $j${"es": "ROLE", "en": "ROLE"}$j$, 1, true, 40, $j${"value": "ROLE"}$j$),
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.TENANT', $j${"es": "TENANT", "en": "TENANT"}$j$, 1, true, 50, $j${"value": "TENANT"}$j$),
        (v_d99_hitl_tipo_entidad, 'd99.hitl.tipo_entidad.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 60, $j${"value": "USER"}$j$);

END $$;

-- ── Bloque 5/11 ───────────────────────────────
DO $$
DECLARE
    v_d99_hitl_tipo_excepcion UUID;
    v_d99_hitl_estado UUID;
    v_d99_notificacion_tipo_notificacion UUID;
    v_d99_notificacion_severidad UUID;
    v_d99_notificacion_alcance_destino UUID;
    v_d99_sbom_tipo_componente UUID;
    v_d99_sbom_nivel_riesgo UUID;
    v_identidad_ciclo_vida_tipo_evento UUID;
    v_identidad_atributo_mutabilidad UUID;
    v_identidad_atributo_unicidad UUID;
    v_identidad_attr_historial_operacion UUID;
    v_identidad_consentimiento_via_otorgamiento UUID;
    v_identidad_consentimiento_base_legal UUID;
    v_identidad_consentimiento_via_retiro UUID;
    v_identidad_entidad_estado UUID;
    v_identidad_proofing_nivel_eidas UUID;
    v_identidad_proofing_estado UUID;
    v_identidad_proofing_tipo_proofing UUID;
    v_identidad_vc_tipo_vc_eidas UUID;
    v_identidad_vc_formato_vc UUID;
    v_d07_conexion_version_tls UUID;
    v_d07_propagacion_formato_propagacion UUID;
    v_d07_dlp_accion_deteccion UUID;
    v_d07_dpop_algoritmo UUID;
    v_d07_postura_red_accion_fallo UUID;
BEGIN

    -- idn_global_hitl_exception_exception_type_check [bauth.idn_global_hitl_exception]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.hitl.tipo_excepcion', $j${"es": "Tipo de excepción", "en": "Exception Type"}$j$, 0, false, $j${"constraint": "idn_global_hitl_exception_exception_type_check", "columns": ["bauth.idn_global_hitl_exception.exception_type"]}$j$)
    RETURNING item_id INTO v_d99_hitl_tipo_excepcion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.AI_DECISION_REVIEWED', $j${"es": "AI_DECISION_REVIEWED", "en": "AI_DECISION_REVIEWED"}$j$, 1, true, 10, $j${"value": "AI_DECISION_REVIEWED"}$j$),
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.COMPLIANCE_BREACH', $j${"es": "COMPLIANCE_BREACH", "en": "COMPLIANCE_BREACH"}$j$, 1, true, 20, $j${"value": "COMPLIANCE_BREACH"}$j$),
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.CRYPTO_DOWNGRADE', $j${"es": "CRYPTO_DOWNGRADE", "en": "CRYPTO_DOWNGRADE"}$j$, 1, true, 30, $j${"value": "CRYPTO_DOWNGRADE"}$j$),
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.EMERGENCY_ACCESS', $j${"es": "EMERGENCY_ACCESS", "en": "EMERGENCY_ACCESS"}$j$, 1, true, 40, $j${"value": "EMERGENCY_ACCESS"}$j$),
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.POLICY_OVERRIDE', $j${"es": "POLICY_OVERRIDE", "en": "POLICY_OVERRIDE"}$j$, 1, true, 50, $j${"value": "POLICY_OVERRIDE"}$j$),
        (v_d99_hitl_tipo_excepcion, 'd99.hitl.tipo_excepcion.PROHIBITED_ALGO', $j${"es": "PROHIBITED_ALGO", "en": "PROHIBITED_ALGO"}$j$, 1, true, 60, $j${"value": "PROHIBITED_ALGO"}$j$);

    -- idn_global_hitl_exception_status_check [bauth.idn_global_hitl_exception]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.hitl.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_global_hitl_exception_status_check", "columns": ["bauth.idn_global_hitl_exception.status"]}$j$)
    RETURNING item_id INTO v_d99_hitl_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_hitl_estado, 'd99.hitl.estado.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_d99_hitl_estado, 'd99.hitl.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d99_hitl_estado, 'd99.hitl.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$),
        (v_d99_hitl_estado, 'd99.hitl.estado.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 40, $j${"value": "REJECTED"}$j$),
        (v_d99_hitl_estado, 'd99.hitl.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 50, $j${"value": "REVOKED"}$j$);

    -- idn_global_notification_notification_type_check [bauth.idn_global_notification]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.notificacion.tipo_notificacion', $j${"es": "Tipo de notificación", "en": "Notification Type"}$j$, 0, false, $j${"constraint": "idn_global_notification_notification_type_check", "columns": ["bauth.idn_global_notification.notification_type"]}$j$)
    RETURNING item_id INTO v_d99_notificacion_tipo_notificacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.CAPACITY_ALERT', $j${"es": "CAPACITY_ALERT", "en": "CAPACITY_ALERT"}$j$, 1, true, 10, $j${"value": "CAPACITY_ALERT"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.CERT_EXPIRY', $j${"es": "CERT_EXPIRY", "en": "CERT_EXPIRY"}$j$, 1, true, 20, $j${"value": "CERT_EXPIRY"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.COMPLIANCE_WARNING', $j${"es": "COMPLIANCE_WARNING", "en": "COMPLIANCE_WARNING"}$j$, 1, true, 30, $j${"value": "COMPLIANCE_WARNING"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.CRYPTO_EXPIRY', $j${"es": "CRYPTO_EXPIRY", "en": "CRYPTO_EXPIRY"}$j$, 1, true, 40, $j${"value": "CRYPTO_EXPIRY"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.INCIDENT', $j${"es": "INCIDENT", "en": "INCIDENT"}$j$, 1, true, 50, $j${"value": "INCIDENT"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.MAINTENANCE', $j${"es": "MAINTENANCE", "en": "MAINTENANCE"}$j$, 1, true, 60, $j${"value": "MAINTENANCE"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.POLICY_CHANGE', $j${"es": "POLICY_CHANGE", "en": "POLICY_CHANGE"}$j$, 1, true, 70, $j${"value": "POLICY_CHANGE"}$j$),
        (v_d99_notificacion_tipo_notificacion, 'd99.notificacion.tipo_notificacion.SECURITY_ALERT', $j${"es": "SECURITY_ALERT", "en": "SECURITY_ALERT"}$j$, 1, true, 80, $j${"value": "SECURITY_ALERT"}$j$);

    -- idn_global_notification_severity_check [bauth.idn_global_notification]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.notificacion.severidad', $j${"es": "Severidad", "en": "Severity"}$j$, 0, false, $j${"constraint": "idn_global_notification_severity_check", "columns": ["bauth.idn_global_notification.severity"]}$j$)
    RETURNING item_id INTO v_d99_notificacion_severidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_notificacion_severidad, 'd99.notificacion.severidad.CRITICAL', $j${"es": "CRITICAL", "en": "CRITICAL"}$j$, 1, true, 10, $j${"value": "CRITICAL"}$j$),
        (v_d99_notificacion_severidad, 'd99.notificacion.severidad.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 20, $j${"value": "ERROR"}$j$),
        (v_d99_notificacion_severidad, 'd99.notificacion.severidad.INFO', $j${"es": "INFO", "en": "INFO"}$j$, 1, true, 30, $j${"value": "INFO"}$j$),
        (v_d99_notificacion_severidad, 'd99.notificacion.severidad.WARNING', $j${"es": "WARNING", "en": "WARNING"}$j$, 1, true, 40, $j${"value": "WARNING"}$j$);

    -- idn_global_notification_target_scope_check [bauth.idn_global_notification]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.notificacion.alcance_destino', $j${"es": "Alcance del destino", "en": "Target Scope"}$j$, 0, false, $j${"constraint": "idn_global_notification_target_scope_check", "columns": ["bauth.idn_global_notification.target_scope"]}$j$)
    RETURNING item_id INTO v_d99_notificacion_alcance_destino;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_notificacion_alcance_destino, 'd99.notificacion.alcance_destino.ADMIN', $j${"es": "ADMIN", "en": "ADMIN"}$j$, 1, true, 10, $j${"value": "ADMIN"}$j$),
        (v_d99_notificacion_alcance_destino, 'd99.notificacion.alcance_destino.ALL', $j${"es": "ALL", "en": "ALL"}$j$, 1, true, 20, $j${"value": "ALL"}$j$),
        (v_d99_notificacion_alcance_destino, 'd99.notificacion.alcance_destino.TENANT', $j${"es": "TENANT", "en": "TENANT"}$j$, 1, true, 30, $j${"value": "TENANT"}$j$);

    -- idn_global_sbom_component_type_check [bauth.idn_global_sbom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.sbom.tipo_componente', $j${"es": "Tipo de componente SBOM", "en": "Component Type"}$j$, 0, false, $j${"constraint": "idn_global_sbom_component_type_check", "columns": ["bauth.idn_global_sbom.component_type"]}$j$)
    RETURNING item_id INTO v_d99_sbom_tipo_componente;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.CONTAINER', $j${"es": "CONTAINER", "en": "CONTAINER"}$j$, 1, true, 10, $j${"value": "CONTAINER"}$j$),
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.DAEMON', $j${"es": "DAEMON", "en": "DAEMON"}$j$, 1, true, 20, $j${"value": "DAEMON"}$j$),
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.FRAMEWORK', $j${"es": "FRAMEWORK", "en": "FRAMEWORK"}$j$, 1, true, 30, $j${"value": "FRAMEWORK"}$j$),
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.LIBRARY', $j${"es": "LIBRARY", "en": "LIBRARY"}$j$, 1, true, 40, $j${"value": "LIBRARY"}$j$),
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.OS_PACKAGE', $j${"es": "OS_PACKAGE", "en": "OS_PACKAGE"}$j$, 1, true, 50, $j${"value": "OS_PACKAGE"}$j$),
        (v_d99_sbom_tipo_componente, 'd99.sbom.tipo_componente.TOOL', $j${"es": "TOOL", "en": "TOOL"}$j$, 1, true, 60, $j${"value": "TOOL"}$j$);

    -- idn_global_sbom_risk_level_check [bauth.idn_global_sbom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d99.sbom.nivel_riesgo', $j${"es": "Nivel de riesgo", "en": "Risk Level"}$j$, 0, false, $j${"constraint": "idn_global_sbom_risk_level_check", "columns": ["bauth.idn_global_sbom.risk_level"]}$j$)
    RETURNING item_id INTO v_d99_sbom_nivel_riesgo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d99_sbom_nivel_riesgo, 'd99.sbom.nivel_riesgo.CRITICAL', $j${"es": "CRITICAL", "en": "CRITICAL"}$j$, 1, true, 10, $j${"value": "CRITICAL"}$j$),
        (v_d99_sbom_nivel_riesgo, 'd99.sbom.nivel_riesgo.HIGH', $j${"es": "HIGH", "en": "HIGH"}$j$, 1, true, 20, $j${"value": "HIGH"}$j$),
        (v_d99_sbom_nivel_riesgo, 'd99.sbom.nivel_riesgo.LOW', $j${"es": "LOW", "en": "LOW"}$j$, 1, true, 30, $j${"value": "LOW"}$j$),
        (v_d99_sbom_nivel_riesgo, 'd99.sbom.nivel_riesgo.MEDIUM', $j${"es": "MEDIUM", "en": "MEDIUM"}$j$, 1, true, 40, $j${"value": "MEDIUM"}$j$),
        (v_d99_sbom_nivel_riesgo, 'd99.sbom.nivel_riesgo.NONE', $j${"es": "NONE", "en": "NONE"}$j$, 1, true, 50, $j${"value": "NONE"}$j$);

    -- chk_ile_event_type [bauth.idn_identidad_lifecycle_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.ciclo_vida.tipo_evento', $j${"es": "Tipo de evento", "en": "Event Type"}$j$, 0, false, $j${"constraint": "chk_ile_event_type", "columns": ["bauth.idn_identidad_lifecycle_event.event_type"]}$j$)
    RETURNING item_id INTO v_identidad_ciclo_vida_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.HIRED', $j${"es": "HIRED", "en": "HIRED"}$j$, 1, true, 10, $j${"value": "HIRED"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.ON_LEAVE', $j${"es": "ON_LEAVE", "en": "ON_LEAVE"}$j$, 1, true, 20, $j${"value": "ON_LEAVE"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.PROMOTED', $j${"es": "PROMOTED", "en": "PROMOTED"}$j$, 1, true, 30, $j${"value": "PROMOTED"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.REACTIVATED', $j${"es": "REACTIVATED", "en": "REACTIVATED"}$j$, 1, true, 40, $j${"value": "REACTIVATED"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.RETURNED', $j${"es": "RETURNED", "en": "RETURNED"}$j$, 1, true, 50, $j${"value": "RETURNED"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.TERMINATED', $j${"es": "TERMINATED", "en": "TERMINATED"}$j$, 1, true, 60, $j${"value": "TERMINATED"}$j$),
        (v_identidad_ciclo_vida_tipo_evento, 'identidad.ciclo_vida.tipo_evento.TRANSFERRED', $j${"es": "TRANSFERRED", "en": "TRANSFERRED"}$j$, 1, true, 70, $j${"value": "TRANSFERRED"}$j$);

    -- chk_iiattr_mutability [bauth.idn_identity_attribute]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.atributo.mutabilidad', $j${"es": "Mutabilidad", "en": "Mutability"}$j$, 0, false, $j${"constraint": "chk_iiattr_mutability", "columns": ["bauth.idn_identity_attribute.mutability"]}$j$)
    RETURNING item_id INTO v_identidad_atributo_mutabilidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_atributo_mutabilidad, 'identidad.atributo.mutabilidad.IMMUTABLE', $j${"es": "IMMUTABLE", "en": "IMMUTABLE"}$j$, 1, true, 10, $j${"value": "IMMUTABLE"}$j$),
        (v_identidad_atributo_mutabilidad, 'identidad.atributo.mutabilidad.READ_ONLY', $j${"es": "READ_ONLY", "en": "READ_ONLY"}$j$, 1, true, 20, $j${"value": "READ_ONLY"}$j$),
        (v_identidad_atributo_mutabilidad, 'identidad.atributo.mutabilidad.READ_WRITE', $j${"es": "READ_WRITE", "en": "READ_WRITE"}$j$, 1, true, 30, $j${"value": "READ_WRITE"}$j$);

    -- chk_iiattr_uniqueness [bauth.idn_identity_attribute]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.atributo.unicidad', $j${"es": "Unicidad del atributo", "en": "Uniqueness"}$j$, 0, false, $j${"constraint": "chk_iiattr_uniqueness", "columns": ["bauth.idn_identity_attribute.uniqueness"]}$j$)
    RETURNING item_id INTO v_identidad_atributo_unicidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_atributo_unicidad, 'identidad.atributo.unicidad.GLOBAL', $j${"es": "GLOBAL", "en": "GLOBAL"}$j$, 1, true, 10, $j${"value": "GLOBAL"}$j$),
        (v_identidad_atributo_unicidad, 'identidad.atributo.unicidad.NONE', $j${"es": "NONE", "en": "NONE"}$j$, 1, true, 20, $j${"value": "NONE"}$j$),
        (v_identidad_atributo_unicidad, 'identidad.atributo.unicidad.SERVER', $j${"es": "SERVER", "en": "SERVER"}$j$, 1, true, 30, $j${"value": "SERVER"}$j$);

    -- chk_iah_operation [bauth.idn_identity_attribute_history]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.attr_historial.operacion', $j${"es": "Operación", "en": "Operation"}$j$, 0, false, $j${"constraint": "chk_iah_operation", "columns": ["bauth.idn_identity_attribute_history.operation", "bauth.idn_identity_attribute_history_2026_07.operation", "bauth.idn_identity_attribute_history_2026_08.operation", "bauth.idn_identity_attribute_history_2026_09.operation", "bauth.idn_identity_attribute_history_2026_10.operation", "bauth.idn_identity_attribute_history_2026_11.operation"]}$j$)
    RETURNING item_id INTO v_identidad_attr_historial_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_attr_historial_operacion, 'identidad.attr_historial.operacion.INSERT', $j${"es": "INSERT", "en": "INSERT"}$j$, 1, true, 10, $j${"value": "INSERT"}$j$),
        (v_identidad_attr_historial_operacion, 'identidad.attr_historial.operacion.SOFT_DELETE', $j${"es": "SOFT_DELETE", "en": "SOFT_DELETE"}$j$, 1, true, 20, $j${"value": "SOFT_DELETE"}$j$),
        (v_identidad_attr_historial_operacion, 'identidad.attr_historial.operacion.UPDATE', $j${"es": "UPDATE", "en": "UPDATE"}$j$, 1, true, 30, $j${"value": "UPDATE"}$j$);

    -- chk_ic_granted_via [bauth.idn_identity_consent]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.consentimiento.via_otorgamiento', $j${"es": "Otorgado vía", "en": "Granted Via"}$j$, 0, false, $j${"constraint": "chk_ic_granted_via", "columns": ["bauth.idn_identity_consent.granted_via"]}$j$)
    RETURNING item_id INTO v_identidad_consentimiento_via_otorgamiento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_consentimiento_via_otorgamiento, 'identidad.consentimiento.via_otorgamiento.API', $j${"es": "API", "en": "API"}$j$, 1, true, 10, $j${"value": "API"}$j$),
        (v_identidad_consentimiento_via_otorgamiento, 'identidad.consentimiento.via_otorgamiento.APP', $j${"es": "APP", "en": "APP"}$j$, 1, true, 20, $j${"value": "APP"}$j$),
        (v_identidad_consentimiento_via_otorgamiento, 'identidad.consentimiento.via_otorgamiento.EMAIL', $j${"es": "EMAIL", "en": "EMAIL"}$j$, 1, true, 30, $j${"value": "EMAIL"}$j$),
        (v_identidad_consentimiento_via_otorgamiento, 'identidad.consentimiento.via_otorgamiento.IN_PERSON', $j${"es": "IN_PERSON", "en": "IN_PERSON"}$j$, 1, true, 40, $j${"value": "IN_PERSON"}$j$),
        (v_identidad_consentimiento_via_otorgamiento, 'identidad.consentimiento.via_otorgamiento.WEB', $j${"es": "WEB", "en": "WEB"}$j$, 1, true, 50, $j${"value": "WEB"}$j$);

    -- chk_ic_legal_basis [bauth.idn_identity_consent]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.consentimiento.base_legal', $j${"es": "Base legal (GDPR)", "en": "Legal Basis"}$j$, 0, false, $j${"constraint": "chk_ic_legal_basis", "columns": ["bauth.idn_identity_consent.legal_basis"]}$j$)
    RETURNING item_id INTO v_identidad_consentimiento_base_legal;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.CONSENT', $j${"es": "CONSENT", "en": "CONSENT"}$j$, 1, true, 10, $j${"value": "CONSENT"}$j$),
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.CONTRACT', $j${"es": "CONTRACT", "en": "CONTRACT"}$j$, 1, true, 20, $j${"value": "CONTRACT"}$j$),
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.LEGAL_OBLIGATION', $j${"es": "LEGAL_OBLIGATION", "en": "LEGAL_OBLIGATION"}$j$, 1, true, 30, $j${"value": "LEGAL_OBLIGATION"}$j$),
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.LEGITIMATE_INTEREST', $j${"es": "LEGITIMATE_INTEREST", "en": "LEGITIMATE_INTEREST"}$j$, 1, true, 40, $j${"value": "LEGITIMATE_INTEREST"}$j$),
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.PUBLIC_TASK', $j${"es": "PUBLIC_TASK", "en": "PUBLIC_TASK"}$j$, 1, true, 50, $j${"value": "PUBLIC_TASK"}$j$),
        (v_identidad_consentimiento_base_legal, 'identidad.consentimiento.base_legal.VITAL_INTEREST', $j${"es": "VITAL_INTEREST", "en": "VITAL_INTEREST"}$j$, 1, true, 60, $j${"value": "VITAL_INTEREST"}$j$);

    -- chk_ic_withdrawn_via [bauth.idn_identity_consent]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.consentimiento.via_retiro', $j${"es": "Retirado vía", "en": "Withdrawn Via"}$j$, 0, false, $j${"constraint": "chk_ic_withdrawn_via", "columns": ["bauth.idn_identity_consent.withdrawn_via"]}$j$)
    RETURNING item_id INTO v_identidad_consentimiento_via_retiro;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.ADMIN', $j${"es": "ADMIN", "en": "ADMIN"}$j$, 1, true, 10, $j${"value": "ADMIN"}$j$),
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.API', $j${"es": "API", "en": "API"}$j$, 1, true, 20, $j${"value": "API"}$j$),
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.APP', $j${"es": "APP", "en": "APP"}$j$, 1, true, 30, $j${"value": "APP"}$j$),
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.EMAIL', $j${"es": "EMAIL", "en": "EMAIL"}$j$, 1, true, 40, $j${"value": "EMAIL"}$j$),
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.IN_PERSON', $j${"es": "IN_PERSON", "en": "IN_PERSON"}$j$, 1, true, 50, $j${"value": "IN_PERSON"}$j$),
        (v_identidad_consentimiento_via_retiro, 'identidad.consentimiento.via_retiro.WEB', $j${"es": "WEB", "en": "WEB"}$j$, 1, true, 60, $j${"value": "WEB"}$j$);

    -- idn_identidad_entidad_status_check [bauth.idn_identity_entity]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.entidad.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_identidad_entidad_status_check", "columns": ["bauth.idn_identity_entity.status"]}$j$)
    RETURNING item_id INTO v_identidad_entidad_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_entidad_estado, 'identidad.entidad.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_identidad_entidad_estado, 'identidad.entidad.estado.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_identidad_entidad_estado, 'identidad.entidad.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 30, $j${"value": "SUSPENDED"}$j$);

    -- chk_iip_eidas [bauth.idn_identity_proofing]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.proofing.nivel_eidas', $j${"es": "Nivel eIDAS", "en": "Eidas Level"}$j$, 0, false, $j${"constraint": "chk_iip_eidas", "columns": ["bauth.idn_identity_proofing.eidas_level", "bauth.idn_identity_vc.eidas_assurance_level"]}$j$)
    RETURNING item_id INTO v_identidad_proofing_nivel_eidas;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_proofing_nivel_eidas, 'identidad.proofing.nivel_eidas.HIGH', $j${"es": "HIGH", "en": "HIGH"}$j$, 1, true, 10, $j${"value": "HIGH"}$j$),
        (v_identidad_proofing_nivel_eidas, 'identidad.proofing.nivel_eidas.LOW', $j${"es": "LOW", "en": "LOW"}$j$, 1, true, 20, $j${"value": "LOW"}$j$),
        (v_identidad_proofing_nivel_eidas, 'identidad.proofing.nivel_eidas.SUBSTANTIAL', $j${"es": "SUBSTANTIAL", "en": "SUBSTANTIAL"}$j$, 1, true, 30, $j${"value": "SUBSTANTIAL"}$j$);

    -- chk_ip_status [bauth.idn_identity_proofing]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.proofing.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_ip_status", "columns": ["bauth.idn_identity_proofing.status"]}$j$)
    RETURNING item_id INTO v_identidad_proofing_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_proofing_estado, 'identidad.proofing.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 10, $j${"value": "EXPIRED"}$j$),
        (v_identidad_proofing_estado, 'identidad.proofing.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_identidad_proofing_estado, 'identidad.proofing.estado.IN_PROGRESS', $j${"es": "IN_PROGRESS", "en": "IN_PROGRESS"}$j$, 1, true, 30, $j${"value": "IN_PROGRESS"}$j$),
        (v_identidad_proofing_estado, 'identidad.proofing.estado.PASSED', $j${"es": "PASSED", "en": "PASSED"}$j$, 1, true, 40, $j${"value": "PASSED"}$j$),
        (v_identidad_proofing_estado, 'identidad.proofing.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 50, $j${"value": "PENDING"}$j$);

    -- chk_ip_type [bauth.idn_identity_proofing]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.proofing.tipo_proofing', $j${"es": "Tipo de proofing", "en": "Proofing Type"}$j$, 0, false, $j${"constraint": "chk_ip_type", "columns": ["bauth.idn_identity_proofing.proofing_type"]}$j$)
    RETURNING item_id INTO v_identidad_proofing_tipo_proofing;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_proofing_tipo_proofing, 'identidad.proofing.tipo_proofing.IN_PERSON', $j${"es": "IN_PERSON", "en": "IN_PERSON"}$j$, 1, true, 10, $j${"value": "IN_PERSON"}$j$),
        (v_identidad_proofing_tipo_proofing, 'identidad.proofing.tipo_proofing.REMOTE_ATTENDED', $j${"es": "REMOTE_ATTENDED", "en": "REMOTE_ATTENDED"}$j$, 1, true, 20, $j${"value": "REMOTE_ATTENDED"}$j$),
        (v_identidad_proofing_tipo_proofing, 'identidad.proofing.tipo_proofing.REMOTE_UNATTENDED', $j${"es": "REMOTE_UNATTENDED", "en": "REMOTE_UNATTENDED"}$j$, 1, true, 30, $j${"value": "REMOTE_UNATTENDED"}$j$),
        (v_identidad_proofing_tipo_proofing, 'identidad.proofing.tipo_proofing.SELF_ASSERTED', $j${"es": "SELF_ASSERTED", "en": "SELF_ASSERTED"}$j$, 1, true, 40, $j${"value": "SELF_ASSERTED"}$j$),
        (v_identidad_proofing_tipo_proofing, 'identidad.proofing.tipo_proofing.TRUSTED_REFEREE', $j${"es": "TRUSTED_REFEREE", "en": "TRUSTED_REFEREE"}$j$, 1, true, 50, $j${"value": "TRUSTED_REFEREE"}$j$);

    -- chk_ivc_eidas_type [bauth.idn_identity_vc]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.vc.tipo_vc_eidas', $j${"es": "Tipo VC eIDAS", "en": "Eidas Vc Type"}$j$, 0, false, $j${"constraint": "chk_ivc_eidas_type", "columns": ["bauth.idn_identity_vc.eidas_vc_type"]}$j$)
    RETURNING item_id INTO v_identidad_vc_tipo_vc_eidas;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_vc_tipo_vc_eidas, 'identidad.vc.tipo_vc_eidas.EAA', $j${"es": "EAA", "en": "EAA"}$j$, 1, true, 10, $j${"value": "EAA"}$j$),
        (v_identidad_vc_tipo_vc_eidas, 'identidad.vc.tipo_vc_eidas.ELM', $j${"es": "ELM", "en": "ELM"}$j$, 1, true, 20, $j${"value": "ELM"}$j$),
        (v_identidad_vc_tipo_vc_eidas, 'identidad.vc.tipo_vc_eidas.PID', $j${"es": "PID", "en": "PID"}$j$, 1, true, 30, $j${"value": "PID"}$j$),
        (v_identidad_vc_tipo_vc_eidas, 'identidad.vc.tipo_vc_eidas.PuB-EAA', $j${"es": "PuB-EAA", "en": "PuB-EAA"}$j$, 1, true, 40, $j${"value": "PuB-EAA"}$j$),
        (v_identidad_vc_tipo_vc_eidas, 'identidad.vc.tipo_vc_eidas.QEAA', $j${"es": "QEAA", "en": "QEAA"}$j$, 1, true, 50, $j${"value": "QEAA"}$j$);

    -- chk_ivc_format [bauth.idn_identity_vc]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.vc.formato_vc', $j${"es": "Formato VC", "en": "Vc Format"}$j$, 0, false, $j${"constraint": "chk_ivc_format", "columns": ["bauth.idn_identity_vc.vc_format"]}$j$)
    RETURNING item_id INTO v_identidad_vc_formato_vc;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_vc_formato_vc, 'identidad.vc.formato_vc.SD_JWT_VC', $j${"es": "SD_JWT_VC", "en": "SD_JWT_VC"}$j$, 1, true, 10, $j${"value": "SD_JWT_VC"}$j$),
        (v_identidad_vc_formato_vc, 'identidad.vc.formato_vc.VC_DATA_MODEL_1_1', $j${"es": "VC_DATA_MODEL_1_1", "en": "VC_DATA_MODEL_1_1"}$j$, 1, true, 20, $j${"value": "VC_DATA_MODEL_1_1"}$j$),
        (v_identidad_vc_formato_vc, 'identidad.vc.formato_vc.VC_DATA_MODEL_2_0', $j${"es": "VC_DATA_MODEL_2_0", "en": "VC_DATA_MODEL_2_0"}$j$, 1, true, 30, $j${"value": "VC_DATA_MODEL_2_0"}$j$);

    -- idn_network_connection_policy_min_tls_version_check [bauth.idn_network_connection_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.conexion.version_tls', $j${"es": "Versión mínima TLS", "en": "Min Tls Version"}$j$, 0, false, $j${"constraint": "idn_network_connection_policy_min_tls_version_check", "columns": ["bauth.idn_network_connection_policy.min_tls_version"]}$j$)
    RETURNING item_id INTO v_d07_conexion_version_tls;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_conexion_version_tls, 'd07.conexion.version_tls.TLS_1_2', $j${"es": "TLS_1_2", "en": "TLS_1_2"}$j$, 1, true, 10, $j${"value": "TLS_1_2"}$j$),
        (v_d07_conexion_version_tls, 'd07.conexion.version_tls.TLS_1_3', $j${"es": "TLS_1_3", "en": "TLS_1_3"}$j$, 1, true, 20, $j${"value": "TLS_1_3"}$j$);

    -- idn_network_context_propagation_propagation_format_check [bauth.idn_network_context_propagation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.propagacion.formato_propagacion', $j${"es": "Formato de propagación", "en": "Propagation Format"}$j$, 0, false, $j${"constraint": "idn_network_context_propagation_propagation_format_check", "columns": ["bauth.idn_network_context_propagation.propagation_format"]}$j$)
    RETURNING item_id INTO v_d07_propagacion_formato_propagacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_propagacion_formato_propagacion, 'd07.propagacion.formato_propagacion.OTEL_BAGGAGE', $j${"es": "OTEL_BAGGAGE", "en": "OTEL_BAGGAGE"}$j$, 1, true, 10, $j${"value": "OTEL_BAGGAGE"}$j$),
        (v_d07_propagacion_formato_propagacion, 'd07.propagacion.formato_propagacion.SBOS_CTX_HEADER', $j${"es": "SBOS_CTX_HEADER", "en": "SBOS_CTX_HEADER"}$j$, 1, true, 20, $j${"value": "SBOS_CTX_HEADER"}$j$),
        (v_d07_propagacion_formato_propagacion, 'd07.propagacion.formato_propagacion.W3C_BAGGAGE', $j${"es": "W3C_BAGGAGE", "en": "W3C_BAGGAGE"}$j$, 1, true, 30, $j${"value": "W3C_BAGGAGE"}$j$),
        (v_d07_propagacion_formato_propagacion, 'd07.propagacion.formato_propagacion.W3C_TRACEPARENT', $j${"es": "W3C_TRACEPARENT", "en": "W3C_TRACEPARENT"}$j$, 1, true, 40, $j${"value": "W3C_TRACEPARENT"}$j$);

    -- idn_network_dlp_policy_action_on_match_check [bauth.idn_network_dlp_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.dlp.accion_deteccion', $j${"es": "Acción al detectar", "en": "Action On Match"}$j$, 0, false, $j${"constraint": "idn_network_dlp_policy_action_on_match_check", "columns": ["bauth.idn_network_dlp_policy.action_on_match"]}$j$)
    RETURNING item_id INTO v_d07_dlp_accion_deteccion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_dlp_accion_deteccion, 'd07.dlp.accion_deteccion.BLOCK', $j${"es": "BLOCK", "en": "BLOCK"}$j$, 1, true, 10, $j${"value": "BLOCK"}$j$),
        (v_d07_dlp_accion_deteccion, 'd07.dlp.accion_deteccion.LOG', $j${"es": "LOG", "en": "LOG"}$j$, 1, true, 20, $j${"value": "LOG"}$j$),
        (v_d07_dlp_accion_deteccion, 'd07.dlp.accion_deteccion.QUARANTINE', $j${"es": "QUARANTINE", "en": "QUARANTINE"}$j$, 1, true, 30, $j${"value": "QUARANTINE"}$j$),
        (v_d07_dlp_accion_deteccion, 'd07.dlp.accion_deteccion.REDACT', $j${"es": "REDACT", "en": "REDACT"}$j$, 1, true, 40, $j${"value": "REDACT"}$j$);

    -- idn_network_dpop_binding_alg_check [bauth.idn_network_dpop_binding]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.dpop.algoritmo', $j${"es": "Algoritmo criptográfico", "en": "Alg"}$j$, 0, false, $j${"constraint": "idn_network_dpop_binding_alg_check", "columns": ["bauth.idn_network_dpop_binding.alg"]}$j$)
    RETURNING item_id INTO v_d07_dpop_algoritmo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_dpop_algoritmo, 'd07.dpop.algoritmo.ES256', $j${"es": "ES256", "en": "ES256"}$j$, 1, true, 10, $j${"value": "ES256"}$j$),
        (v_d07_dpop_algoritmo, 'd07.dpop.algoritmo.ES384', $j${"es": "ES384", "en": "ES384"}$j$, 1, true, 20, $j${"value": "ES384"}$j$),
        (v_d07_dpop_algoritmo, 'd07.dpop.algoritmo.EdDSA', $j${"es": "EdDSA", "en": "EdDSA"}$j$, 1, true, 30, $j${"value": "EdDSA"}$j$),
        (v_d07_dpop_algoritmo, 'd07.dpop.algoritmo.PS256', $j${"es": "PS256", "en": "PS256"}$j$, 1, true, 40, $j${"value": "PS256"}$j$),
        (v_d07_dpop_algoritmo, 'd07.dpop.algoritmo.RS256', $j${"es": "RS256", "en": "RS256"}$j$, 1, true, 50, $j${"value": "RS256"}$j$);

    -- idn_network_posture_policy_action_on_fail_check [bauth.idn_network_posture_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.postura_red.accion_fallo', $j${"es": "Acción en fallo", "en": "Action On Fail"}$j$, 0, false, $j${"constraint": "idn_network_posture_policy_action_on_fail_check", "columns": ["bauth.idn_network_posture_policy.action_on_fail"]}$j$)
    RETURNING item_id INTO v_d07_postura_red_accion_fallo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_postura_red_accion_fallo, 'd07.postura_red.accion_fallo.CHALLENGE', $j${"es": "CHALLENGE", "en": "CHALLENGE"}$j$, 1, true, 10, $j${"value": "CHALLENGE"}$j$),
        (v_d07_postura_red_accion_fallo, 'd07.postura_red.accion_fallo.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 20, $j${"value": "DENY"}$j$),
        (v_d07_postura_red_accion_fallo, 'd07.postura_red.accion_fallo.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 30, $j${"value": "NOTIFY"}$j$),
        (v_d07_postura_red_accion_fallo, 'd07.postura_red.accion_fallo.STEP_UP', $j${"es": "STEP_UP", "en": "STEP_UP"}$j$, 1, true, 40, $j${"value": "STEP_UP"}$j$);

END $$;

-- ── Bloque 6/11 ───────────────────────────────
DO $$
DECLARE
    v_d07_tasa_limite_accion_exceso UUID;
    v_d07_tasa_limite_alcance UUID;
    v_d07_segmento_tipo_segmento UUID;
    v_d07_segmento_confianza UUID;
    v_d15_nhi_rotacion_accion_fallo UUID;
    v_d15_nhi_rotacion_tipo_nhi UUID;
    v_d15_svid_estado UUID;
    v_d15_svid_tipo_svid UUID;
    v_d02_credencial_fisica_tipo_credencial UUID;
    v_d02_emergencia_modo_puerta UUID;
    v_d02_emergencia_tipo_emergencia UUID;
    v_d02_evento_fisico_tipo_credencial UUID;
    v_d02_evento_fisico_tipo_evento UUID;
    v_d02_evento_fisico_resultado UUID;
    v_d02_ubicacion_fisica_tipo_ubicacion UUID;
    v_d02_ubicacion_fisica_estado UUID;
    v_d02_lector_direccion UUID;
    v_d02_lector_protocolo UUID;
    v_d02_lector_tipo_lector UUID;
    v_d02_lector_estado UUID;
    v_d02_visita_estado UUID;
    v_cfg_nodo_politica_tamano_fuente UUID;
    v_registry_schema_attr_categoria UUID;
    v_registry_schema_attr_clasificacion UUID;
    v_registry_schema_attr_tipo_dato UUID;
BEGIN

    -- idn_network_rate_policy_action_on_exceed_check [bauth.idn_network_rate_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.tasa_limite.accion_exceso', $j${"es": "Acción al exceder", "en": "Action On Exceed"}$j$, 0, false, $j${"constraint": "idn_network_rate_policy_action_on_exceed_check", "columns": ["bauth.idn_network_rate_policy.action_on_exceed"]}$j$)
    RETURNING item_id INTO v_d07_tasa_limite_accion_exceso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_tasa_limite_accion_exceso, 'd07.tasa_limite.accion_exceso.BLOCK', $j${"es": "BLOCK", "en": "BLOCK"}$j$, 1, true, 10, $j${"value": "BLOCK"}$j$),
        (v_d07_tasa_limite_accion_exceso, 'd07.tasa_limite.accion_exceso.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 20, $j${"value": "NOTIFY"}$j$),
        (v_d07_tasa_limite_accion_exceso, 'd07.tasa_limite.accion_exceso.THROTTLE', $j${"es": "THROTTLE", "en": "THROTTLE"}$j$, 1, true, 30, $j${"value": "THROTTLE"}$j$);

    -- idn_network_rate_policy_scope_check [bauth.idn_network_rate_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.tasa_limite.alcance', $j${"es": "Alcance", "en": "Scope"}$j$, 0, false, $j${"constraint": "idn_network_rate_policy_scope_check", "columns": ["bauth.idn_network_rate_policy.scope"]}$j$)
    RETURNING item_id INTO v_d07_tasa_limite_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_tasa_limite_alcance, 'd07.tasa_limite.alcance.CLIENT', $j${"es": "CLIENT", "en": "CLIENT"}$j$, 1, true, 10, $j${"value": "CLIENT"}$j$),
        (v_d07_tasa_limite_alcance, 'd07.tasa_limite.alcance.GLOBAL', $j${"es": "GLOBAL", "en": "GLOBAL"}$j$, 1, true, 20, $j${"value": "GLOBAL"}$j$),
        (v_d07_tasa_limite_alcance, 'd07.tasa_limite.alcance.IP', $j${"es": "IP", "en": "IP"}$j$, 1, true, 30, $j${"value": "IP"}$j$),
        (v_d07_tasa_limite_alcance, 'd07.tasa_limite.alcance.TENANT', $j${"es": "TENANT", "en": "TENANT"}$j$, 1, true, 40, $j${"value": "TENANT"}$j$),
        (v_d07_tasa_limite_alcance, 'd07.tasa_limite.alcance.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 50, $j${"value": "USER"}$j$);

    -- idn_network_segment_segment_type_check [bauth.idn_network_segment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.segmento.tipo_segmento', $j${"es": "Tipo de segmento", "en": "Segment Type"}$j$, 0, false, $j${"constraint": "idn_network_segment_segment_type_check", "columns": ["bauth.idn_network_segment.segment_type"]}$j$)
    RETURNING item_id INTO v_d07_segmento_tipo_segmento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_segmento_tipo_segmento, 'd07.segmento.tipo_segmento.DMZ', $j${"es": "DMZ", "en": "DMZ"}$j$, 1, true, 10, $j${"value": "DMZ"}$j$),
        (v_d07_segmento_tipo_segmento, 'd07.segmento.tipo_segmento.INTERNAL', $j${"es": "INTERNAL", "en": "INTERNAL"}$j$, 1, true, 20, $j${"value": "INTERNAL"}$j$),
        (v_d07_segmento_tipo_segmento, 'd07.segmento.tipo_segmento.ISOLATED', $j${"es": "ISOLATED", "en": "ISOLATED"}$j$, 1, true, 30, $j${"value": "ISOLATED"}$j$),
        (v_d07_segmento_tipo_segmento, 'd07.segmento.tipo_segmento.QUARANTINE', $j${"es": "QUARANTINE", "en": "QUARANTINE"}$j$, 1, true, 40, $j${"value": "QUARANTINE"}$j$),
        (v_d07_segmento_tipo_segmento, 'd07.segmento.tipo_segmento.TRUSTED', $j${"es": "TRUSTED", "en": "TRUSTED"}$j$, 1, true, 50, $j${"value": "TRUSTED"}$j$);

    -- idn_network_segment_trust_level_check [bauth.idn_network_segment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d07.segmento.confianza', $j${"es": "Nivel de confianza", "en": "Trust Level"}$j$, 0, false, $j${"constraint": "idn_network_segment_trust_level_check", "columns": ["bauth.idn_network_segment.trust_level"]}$j$)
    RETURNING item_id INTO v_d07_segmento_confianza;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d07_segmento_confianza, 'd07.segmento.confianza.CONDITIONALLY_TRUSTED', $j${"es": "CONDITIONALLY_TRUSTED", "en": "CONDITIONALLY_TRUSTED"}$j$, 1, true, 10, $j${"value": "CONDITIONALLY_TRUSTED"}$j$),
        (v_d07_segmento_confianza, 'd07.segmento.confianza.TRUSTED', $j${"es": "TRUSTED", "en": "TRUSTED"}$j$, 1, true, 20, $j${"value": "TRUSTED"}$j$),
        (v_d07_segmento_confianza, 'd07.segmento.confianza.UNTRUSTED', $j${"es": "UNTRUSTED", "en": "UNTRUSTED"}$j$, 1, true, 30, $j${"value": "UNTRUSTED"}$j$);

    -- idn_nhi_rotation_policy_fail_action_check [bauth.idn_nhi_rotation_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_rotacion.accion_fallo', $j${"es": "Acción en fallo", "en": "Fail Action"}$j$, 0, false, $j${"constraint": "idn_nhi_rotation_policy_fail_action_check", "columns": ["bauth.idn_nhi_rotation_policy.fail_action"]}$j$)
    RETURNING item_id INTO v_d15_nhi_rotacion_accion_fallo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_rotacion_accion_fallo, 'd15.nhi_rotacion.accion_fallo.ALERT_ADMIN', $j${"es": "ALERT_ADMIN", "en": "ALERT_ADMIN"}$j$, 1, true, 10, $j${"value": "ALERT_ADMIN"}$j$),
        (v_d15_nhi_rotacion_accion_fallo, 'd15.nhi_rotacion.accion_fallo.NOTIFY', $j${"es": "NOTIFY", "en": "NOTIFY"}$j$, 1, true, 20, $j${"value": "NOTIFY"}$j$),
        (v_d15_nhi_rotacion_accion_fallo, 'd15.nhi_rotacion.accion_fallo.SUSPEND_NHI', $j${"es": "SUSPEND_NHI", "en": "SUSPEND_NHI"}$j$, 1, true, 30, $j${"value": "SUSPEND_NHI"}$j$);

    -- idn_nhi_rotation_policy_nhi_type_check [bauth.idn_nhi_rotation_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_rotacion.tipo_nhi', $j${"es": "Tipo NHI", "en": "Nhi Type"}$j$, 0, false, $j${"constraint": "idn_nhi_rotation_policy_nhi_type_check", "columns": ["bauth.idn_nhi_rotation_policy.nhi_type"]}$j$)
    RETURNING item_id INTO v_d15_nhi_rotacion_tipo_nhi;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.AGENT_IA', $j${"es": "AGENT_IA", "en": "AGENT_IA"}$j$, 1, true, 10, $j${"value": "AGENT_IA"}$j$),
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.API_KEY', $j${"es": "API_KEY", "en": "API_KEY"}$j$, 1, true, 20, $j${"value": "API_KEY"}$j$),
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.BOT', $j${"es": "BOT", "en": "BOT"}$j$, 1, true, 30, $j${"value": "BOT"}$j$),
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.CI_CD', $j${"es": "CI_CD", "en": "CI_CD"}$j$, 1, true, 40, $j${"value": "CI_CD"}$j$),
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.DAEMON', $j${"es": "DAEMON", "en": "DAEMON"}$j$, 1, true, 50, $j${"value": "DAEMON"}$j$),
        (v_d15_nhi_rotacion_tipo_nhi, 'd15.nhi_rotacion.tipo_nhi.SERVICE_ACCOUNT', $j${"es": "SERVICE_ACCOUNT", "en": "SERVICE_ACCOUNT"}$j$, 1, true, 60, $j${"value": "SERVICE_ACCOUNT"}$j$);

    -- idn_nhi_svid_status_check [bauth.idn_nhi_svid]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.svid.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_nhi_svid_status_check", "columns": ["bauth.idn_nhi_svid.status"]}$j$)
    RETURNING item_id INTO v_d15_svid_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_svid_estado, 'd15.svid.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d15_svid_estado, 'd15.svid.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d15_svid_estado, 'd15.svid.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_d15_svid_estado, 'd15.svid.estado.ROTATED', $j${"es": "ROTATED", "en": "ROTATED"}$j$, 1, true, 40, $j${"value": "ROTATED"}$j$);

    -- idn_nhi_svid_svid_type_check [bauth.idn_nhi_svid]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.svid.tipo_svid', $j${"es": "Tipo de SVID", "en": "Svid Type"}$j$, 0, false, $j${"constraint": "idn_nhi_svid_svid_type_check", "columns": ["bauth.idn_nhi_svid.svid_type"]}$j$)
    RETURNING item_id INTO v_d15_svid_tipo_svid;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_svid_tipo_svid, 'd15.svid.tipo_svid.JWT', $j${"es": "JWT", "en": "JWT"}$j$, 1, true, 10, $j${"value": "JWT"}$j$),
        (v_d15_svid_tipo_svid, 'd15.svid.tipo_svid.X509', $j${"es": "X509", "en": "X509"}$j$, 1, true, 20, $j${"value": "X509"}$j$);

    -- idn_physical_access_credential_credential_type_check [bauth.idn_physical_access_credential]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.credencial_fisica.tipo_credencial', $j${"es": "Tipo de credencial", "en": "Credential Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_credential_credential_type_check", "columns": ["bauth.idn_physical_access_credential.credential_type"]}$j$)
    RETURNING item_id INTO v_d02_credencial_fisica_tipo_credencial;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.BIOMETRIC', $j${"es": "BIOMETRIC", "en": "BIOMETRIC"}$j$, 1, true, 10, $j${"value": "BIOMETRIC"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.NFC', $j${"es": "NFC", "en": "NFC"}$j$, 1, true, 20, $j${"value": "NFC"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.PIN', $j${"es": "PIN", "en": "PIN"}$j$, 1, true, 30, $j${"value": "PIN"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.PIV', $j${"es": "PIV", "en": "PIV"}$j$, 1, true, 40, $j${"value": "PIV"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.QR', $j${"es": "QR", "en": "QR"}$j$, 1, true, 50, $j${"value": "QR"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.RFID', $j${"es": "RFID", "en": "RFID"}$j$, 1, true, 60, $j${"value": "RFID"}$j$),
        (v_d02_credencial_fisica_tipo_credencial, 'd02.credencial_fisica.tipo_credencial.SMARTCARD', $j${"es": "SMARTCARD", "en": "SMARTCARD"}$j$, 1, true, 70, $j${"value": "SMARTCARD"}$j$);

    -- idn_physical_access_emergency_door_mode_check [bauth.idn_physical_access_emergency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.emergencia.modo_puerta', $j${"es": "Modo de puerta de emergencia", "en": "Door Mode"}$j$, 0, false, $j${"constraint": "idn_physical_access_emergency_door_mode_check", "columns": ["bauth.idn_physical_access_emergency.door_mode"]}$j$)
    RETURNING item_id INTO v_d02_emergencia_modo_puerta;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_emergencia_modo_puerta, 'd02.emergencia.modo_puerta.FAIL_SAFE', $j${"es": "FAIL_SAFE", "en": "FAIL_SAFE"}$j$, 1, true, 10, $j${"value": "FAIL_SAFE"}$j$),
        (v_d02_emergencia_modo_puerta, 'd02.emergencia.modo_puerta.FAIL_SECURE', $j${"es": "FAIL_SECURE", "en": "FAIL_SECURE"}$j$, 1, true, 20, $j${"value": "FAIL_SECURE"}$j$),
        (v_d02_emergencia_modo_puerta, 'd02.emergencia.modo_puerta.MANUAL_OVERRIDE', $j${"es": "MANUAL_OVERRIDE", "en": "MANUAL_OVERRIDE"}$j$, 1, true, 30, $j${"value": "MANUAL_OVERRIDE"}$j$),
        (v_d02_emergencia_modo_puerta, 'd02.emergencia.modo_puerta.NORMAL', $j${"es": "NORMAL", "en": "NORMAL"}$j$, 1, true, 40, $j${"value": "NORMAL"}$j$);

    -- idn_physical_access_emergency_emergency_type_check [bauth.idn_physical_access_emergency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.emergencia.tipo_emergencia', $j${"es": "Tipo de emergencia física", "en": "Emergency Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_emergency_emergency_type_check", "columns": ["bauth.idn_physical_access_emergency.emergency_type"]}$j$)
    RETURNING item_id INTO v_d02_emergencia_tipo_emergencia;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.EVACUATION', $j${"es": "EVACUATION", "en": "EVACUATION"}$j$, 1, true, 10, $j${"value": "EVACUATION"}$j$),
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.FIRE', $j${"es": "FIRE", "en": "FIRE"}$j$, 1, true, 20, $j${"value": "FIRE"}$j$),
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.INTRUSION', $j${"es": "INTRUSION", "en": "INTRUSION"}$j$, 1, true, 30, $j${"value": "INTRUSION"}$j$),
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.MEDICAL', $j${"es": "MEDICAL", "en": "MEDICAL"}$j$, 1, true, 40, $j${"value": "MEDICAL"}$j$),
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.OTHER', $j${"es": "OTHER", "en": "OTHER"}$j$, 1, true, 50, $j${"value": "OTHER"}$j$),
        (v_d02_emergencia_tipo_emergencia, 'd02.emergencia.tipo_emergencia.POWER_FAILURE', $j${"es": "POWER_FAILURE", "en": "POWER_FAILURE"}$j$, 1, true, 60, $j${"value": "POWER_FAILURE"}$j$);

    -- idn_physical_access_event_log_credential_type_check [bauth.idn_physical_access_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.evento_fisico.tipo_credencial', $j${"es": "Tipo de credencial", "en": "Credential Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_event_log_credential_type_check", "columns": ["bauth.idn_physical_access_event_log.credential_type", "bauth.idn_physical_access_event_log_2026_07.credential_type", "bauth.idn_physical_access_event_log_2026_08.credential_type", "bauth.idn_physical_access_event_log_default.credential_type"]}$j$)
    RETURNING item_id INTO v_d02_evento_fisico_tipo_credencial;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_evento_fisico_tipo_credencial, 'd02.evento_fisico.tipo_credencial.BIOMETRIC', $j${"es": "BIOMETRIC", "en": "BIOMETRIC"}$j$, 1, true, 10, $j${"value": "BIOMETRIC"}$j$),
        (v_d02_evento_fisico_tipo_credencial, 'd02.evento_fisico.tipo_credencial.MULTIFACTOR', $j${"es": "MULTIFACTOR", "en": "MULTIFACTOR"}$j$, 1, true, 20, $j${"value": "MULTIFACTOR"}$j$),
        (v_d02_evento_fisico_tipo_credencial, 'd02.evento_fisico.tipo_credencial.PIN', $j${"es": "PIN", "en": "PIN"}$j$, 1, true, 30, $j${"value": "PIN"}$j$),
        (v_d02_evento_fisico_tipo_credencial, 'd02.evento_fisico.tipo_credencial.RFID', $j${"es": "RFID", "en": "RFID"}$j$, 1, true, 40, $j${"value": "RFID"}$j$),
        (v_d02_evento_fisico_tipo_credencial, 'd02.evento_fisico.tipo_credencial.SMARTCARD', $j${"es": "SMARTCARD", "en": "SMARTCARD"}$j$, 1, true, 50, $j${"value": "SMARTCARD"}$j$);

    -- idn_physical_access_event_log_event_type_check [bauth.idn_physical_access_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.evento_fisico.tipo_evento', $j${"es": "Tipo de evento", "en": "Event Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_event_log_event_type_check", "columns": ["bauth.idn_physical_access_event_log.event_type", "bauth.idn_physical_access_event_log_2026_07.event_type", "bauth.idn_physical_access_event_log_2026_08.event_type", "bauth.idn_physical_access_event_log_default.event_type"]}$j$)
    RETURNING item_id INTO v_d02_evento_fisico_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.ALARM', $j${"es": "ALARM", "en": "ALARM"}$j$, 1, true, 10, $j${"value": "ALARM"}$j$),
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.ANTIPASSBACK', $j${"es": "ANTIPASSBACK", "en": "ANTIPASSBACK"}$j$, 1, true, 20, $j${"value": "ANTIPASSBACK"}$j$),
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.DENIED', $j${"es": "DENIED", "en": "DENIED"}$j$, 1, true, 30, $j${"value": "DENIED"}$j$),
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.ENTRY', $j${"es": "ENTRY", "en": "ENTRY"}$j$, 1, true, 40, $j${"value": "ENTRY"}$j$),
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.EXIT', $j${"es": "EXIT", "en": "EXIT"}$j$, 1, true, 50, $j${"value": "EXIT"}$j$),
        (v_d02_evento_fisico_tipo_evento, 'd02.evento_fisico.tipo_evento.FORCED', $j${"es": "FORCED", "en": "FORCED"}$j$, 1, true, 60, $j${"value": "FORCED"}$j$);

    -- idn_physical_access_event_log_outcome_check [bauth.idn_physical_access_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.evento_fisico.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "idn_physical_access_event_log_outcome_check", "columns": ["bauth.idn_physical_access_event_log.outcome", "bauth.idn_physical_access_event_log_2026_07.outcome", "bauth.idn_physical_access_event_log_2026_08.outcome", "bauth.idn_physical_access_event_log_default.outcome"]}$j$)
    RETURNING item_id INTO v_d02_evento_fisico_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_evento_fisico_resultado, 'd02.evento_fisico.resultado.ALARM', $j${"es": "ALARM", "en": "ALARM"}$j$, 1, true, 10, $j${"value": "ALARM"}$j$),
        (v_d02_evento_fisico_resultado, 'd02.evento_fisico.resultado.DENIED', $j${"es": "DENIED", "en": "DENIED"}$j$, 1, true, 20, $j${"value": "DENIED"}$j$),
        (v_d02_evento_fisico_resultado, 'd02.evento_fisico.resultado.GRANTED', $j${"es": "GRANTED", "en": "GRANTED"}$j$, 1, true, 30, $j${"value": "GRANTED"}$j$),
        (v_d02_evento_fisico_resultado, 'd02.evento_fisico.resultado.TIMEOUT', $j${"es": "TIMEOUT", "en": "TIMEOUT"}$j$, 1, true, 40, $j${"value": "TIMEOUT"}$j$);

    -- idn_physical_access_location_location_type_check [bauth.idn_physical_access_location]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.ubicacion_fisica.tipo_ubicacion', $j${"es": "Tipo de ubicación", "en": "Location Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_location_location_type_check", "columns": ["bauth.idn_physical_access_location.location_type"]}$j$)
    RETURNING item_id INTO v_d02_ubicacion_fisica_tipo_ubicacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.BUILDING', $j${"es": "BUILDING", "en": "BUILDING"}$j$, 1, true, 10, $j${"value": "BUILDING"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.DATACENTER', $j${"es": "DATACENTER", "en": "DATACENTER"}$j$, 1, true, 20, $j${"value": "DATACENTER"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.FLOOR', $j${"es": "FLOOR", "en": "FLOOR"}$j$, 1, true, 30, $j${"value": "FLOOR"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.PERIMETER', $j${"es": "PERIMETER", "en": "PERIMETER"}$j$, 1, true, 40, $j${"value": "PERIMETER"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.ROOM', $j${"es": "ROOM", "en": "ROOM"}$j$, 1, true, 50, $j${"value": "ROOM"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.VEHICLE_ACCESS', $j${"es": "VEHICLE_ACCESS", "en": "VEHICLE_ACCESS"}$j$, 1, true, 60, $j${"value": "VEHICLE_ACCESS"}$j$),
        (v_d02_ubicacion_fisica_tipo_ubicacion, 'd02.ubicacion_fisica.tipo_ubicacion.WAREHOUSE', $j${"es": "WAREHOUSE", "en": "WAREHOUSE"}$j$, 1, true, 70, $j${"value": "WAREHOUSE"}$j$);

    -- idn_physical_access_location_status_check [bauth.idn_physical_access_location]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.ubicacion_fisica.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_physical_access_location_status_check", "columns": ["bauth.idn_physical_access_location.status"]}$j$)
    RETURNING item_id INTO v_d02_ubicacion_fisica_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_ubicacion_fisica_estado, 'd02.ubicacion_fisica.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d02_ubicacion_fisica_estado, 'd02.ubicacion_fisica.estado.INACTIVE', $j${"es": "INACTIVE", "en": "INACTIVE"}$j$, 1, true, 20, $j${"value": "INACTIVE"}$j$),
        (v_d02_ubicacion_fisica_estado, 'd02.ubicacion_fisica.estado.MAINTENANCE', $j${"es": "MAINTENANCE", "en": "MAINTENANCE"}$j$, 1, true, 30, $j${"value": "MAINTENANCE"}$j$);

    -- idn_physical_access_reader_direction_check [bauth.idn_physical_access_reader]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.lector.direccion', $j${"es": "Dirección", "en": "Direction"}$j$, 0, false, $j${"constraint": "idn_physical_access_reader_direction_check", "columns": ["bauth.idn_physical_access_reader.direction"]}$j$)
    RETURNING item_id INTO v_d02_lector_direccion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_lector_direccion, 'd02.lector.direccion.BIDIRECTIONAL', $j${"es": "BIDIRECTIONAL", "en": "BIDIRECTIONAL"}$j$, 1, true, 10, $j${"value": "BIDIRECTIONAL"}$j$),
        (v_d02_lector_direccion, 'd02.lector.direccion.ENTRY', $j${"es": "ENTRY", "en": "ENTRY"}$j$, 1, true, 20, $j${"value": "ENTRY"}$j$),
        (v_d02_lector_direccion, 'd02.lector.direccion.EXIT', $j${"es": "EXIT", "en": "EXIT"}$j$, 1, true, 30, $j${"value": "EXIT"}$j$);

    -- idn_physical_access_reader_protocol_check [bauth.idn_physical_access_reader]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.lector.protocolo', $j${"es": "Protocolo", "en": "Protocol"}$j$, 0, false, $j${"constraint": "idn_physical_access_reader_protocol_check", "columns": ["bauth.idn_physical_access_reader.protocol"]}$j$)
    RETURNING item_id INTO v_d02_lector_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_lector_protocolo, 'd02.lector.protocolo.OSDP_V1', $j${"es": "OSDP_V1", "en": "OSDP_V1"}$j$, 1, true, 10, $j${"value": "OSDP_V1"}$j$),
        (v_d02_lector_protocolo, 'd02.lector.protocolo.OSDP_V2', $j${"es": "OSDP_V2", "en": "OSDP_V2"}$j$, 1, true, 20, $j${"value": "OSDP_V2"}$j$),
        (v_d02_lector_protocolo, 'd02.lector.protocolo.OSDP_V2_2', $j${"es": "OSDP_V2_2", "en": "OSDP_V2_2"}$j$, 1, true, 30, $j${"value": "OSDP_V2_2"}$j$),
        (v_d02_lector_protocolo, 'd02.lector.protocolo.WIEGAND', $j${"es": "WIEGAND", "en": "WIEGAND"}$j$, 1, true, 40, $j${"value": "WIEGAND"}$j$);

    -- idn_physical_access_reader_reader_type_check [bauth.idn_physical_access_reader]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.lector.tipo_lector', $j${"es": "Tipo de lector", "en": "Reader Type"}$j$, 0, false, $j${"constraint": "idn_physical_access_reader_reader_type_check", "columns": ["bauth.idn_physical_access_reader.reader_type"]}$j$)
    RETURNING item_id INTO v_d02_lector_tipo_lector;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.BIOMETRIC', $j${"es": "BIOMETRIC", "en": "BIOMETRIC"}$j$, 1, true, 10, $j${"value": "BIOMETRIC"}$j$),
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.MULTIFACTOR', $j${"es": "MULTIFACTOR", "en": "MULTIFACTOR"}$j$, 1, true, 20, $j${"value": "MULTIFACTOR"}$j$),
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.OSDP', $j${"es": "OSDP", "en": "OSDP"}$j$, 1, true, 30, $j${"value": "OSDP"}$j$),
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.PIN', $j${"es": "PIN", "en": "PIN"}$j$, 1, true, 40, $j${"value": "PIN"}$j$),
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.RFID', $j${"es": "RFID", "en": "RFID"}$j$, 1, true, 50, $j${"value": "RFID"}$j$),
        (v_d02_lector_tipo_lector, 'd02.lector.tipo_lector.SMARTCARD', $j${"es": "SMARTCARD", "en": "SMARTCARD"}$j$, 1, true, 60, $j${"value": "SMARTCARD"}$j$);

    -- idn_physical_access_reader_status_check [bauth.idn_physical_access_reader]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.lector.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_physical_access_reader_status_check", "columns": ["bauth.idn_physical_access_reader.status"]}$j$)
    RETURNING item_id INTO v_d02_lector_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_lector_estado, 'd02.lector.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d02_lector_estado, 'd02.lector.estado.DISABLED', $j${"es": "DISABLED", "en": "DISABLED"}$j$, 1, true, 20, $j${"value": "DISABLED"}$j$),
        (v_d02_lector_estado, 'd02.lector.estado.MAINTENANCE', $j${"es": "MAINTENANCE", "en": "MAINTENANCE"}$j$, 1, true, 30, $j${"value": "MAINTENANCE"}$j$),
        (v_d02_lector_estado, 'd02.lector.estado.OFFLINE', $j${"es": "OFFLINE", "en": "OFFLINE"}$j$, 1, true, 40, $j${"value": "OFFLINE"}$j$);

    -- idn_physical_access_visit_status_check [bauth.idn_physical_access_visit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d02.visita.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_physical_access_visit_status_check", "columns": ["bauth.idn_physical_access_visit.status"]}$j$)
    RETURNING item_id INTO v_d02_visita_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d02_visita_estado, 'd02.visita.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d02_visita_estado, 'd02.visita.estado.CANCELLED', $j${"es": "CANCELLED", "en": "CANCELLED"}$j$, 1, true, 20, $j${"value": "CANCELLED"}$j$),
        (v_d02_visita_estado, 'd02.visita.estado.COMPLETED', $j${"es": "COMPLETED", "en": "COMPLETED"}$j$, 1, true, 30, $j${"value": "COMPLETED"}$j$),
        (v_d02_visita_estado, 'd02.visita.estado.NO_SHOW', $j${"es": "NO_SHOW", "en": "NO_SHOW"}$j$, 1, true, 40, $j${"value": "NO_SHOW"}$j$),
        (v_d02_visita_estado, 'd02.visita.estado.SCHEDULED', $j${"es": "SCHEDULED", "en": "SCHEDULED"}$j$, 1, true, 50, $j${"value": "SCHEDULED"}$j$);

    -- chk_itn_font_size_token [bauth.idn_policy_node_type]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('cfg.nodo_politica.tamano_fuente', $j${"es": "Token de tamaño de fuente", "en": "Font Size Token"}$j$, 0, false, $j${"constraint": "chk_itn_font_size_token", "columns": ["bauth.idn_policy_node_type.font_size_token"]}$j$)
    RETURNING item_id INTO v_cfg_nodo_politica_tamano_fuente;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_cfg_nodo_politica_tamano_fuente, 'cfg.nodo_politica.tamano_fuente.base', $j${"es": "base", "en": "base"}$j$, 1, true, 10, $j${"value": "base"}$j$),
        (v_cfg_nodo_politica_tamano_fuente, 'cfg.nodo_politica.tamano_fuente.md', $j${"es": "md", "en": "md"}$j$, 1, true, 20, $j${"value": "md"}$j$),
        (v_cfg_nodo_politica_tamano_fuente, 'cfg.nodo_politica.tamano_fuente.sm', $j${"es": "sm", "en": "sm"}$j$, 1, true, 30, $j${"value": "sm"}$j$),
        (v_cfg_nodo_politica_tamano_fuente, 'cfg.nodo_politica.tamano_fuente.xs', $j${"es": "xs", "en": "xs"}$j$, 1, true, 40, $j${"value": "xs"}$j$);

    -- idn_registry_attribute_schema_category_check [bauth.idn_registry_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.schema_attr.categoria', $j${"es": "Categoría", "en": "Category"}$j$, 0, false, $j${"constraint": "idn_registry_attribute_schema_category_check", "columns": ["bauth.idn_registry_attribute_schema.category"]}$j$)
    RETURNING item_id INTO v_registry_schema_attr_categoria;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.BIOMETRIC', $j${"es": "BIOMETRIC", "en": "BIOMETRIC"}$j$, 1, true, 10, $j${"value": "BIOMETRIC"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.CONTACT', $j${"es": "CONTACT", "en": "CONTACT"}$j$, 1, true, 20, $j${"value": "CONTACT"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.CUSTOM', $j${"es": "CUSTOM", "en": "CUSTOM"}$j$, 1, true, 30, $j${"value": "CUSTOM"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.FINANCIAL', $j${"es": "FINANCIAL", "en": "FINANCIAL"}$j$, 1, true, 40, $j${"value": "FINANCIAL"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.IDENTITY', $j${"es": "IDENTITY", "en": "IDENTITY"}$j$, 1, true, 50, $j${"value": "IDENTITY"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.LEGAL', $j${"es": "LEGAL", "en": "LEGAL"}$j$, 1, true, 60, $j${"value": "LEGAL"}$j$),
        (v_registry_schema_attr_categoria, 'registry.schema_attr.categoria.SYSTEM', $j${"es": "SYSTEM", "en": "SYSTEM"}$j$, 1, true, 70, $j${"value": "SYSTEM"}$j$);

    -- idn_registry_attribute_schema_classification_check [bauth.idn_registry_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.schema_attr.clasificacion', $j${"es": "Clasificación", "en": "Classification"}$j$, 0, false, $j${"constraint": "idn_registry_attribute_schema_classification_check", "columns": ["bauth.idn_registry_attribute_schema.classification"]}$j$)
    RETURNING item_id INTO v_registry_schema_attr_clasificacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_schema_attr_clasificacion, 'registry.schema_attr.clasificacion.CONFIDENTIAL', $j${"es": "CONFIDENTIAL", "en": "CONFIDENTIAL"}$j$, 1, true, 10, $j${"value": "CONFIDENTIAL"}$j$),
        (v_registry_schema_attr_clasificacion, 'registry.schema_attr.clasificacion.INTERNAL', $j${"es": "INTERNAL", "en": "INTERNAL"}$j$, 1, true, 20, $j${"value": "INTERNAL"}$j$),
        (v_registry_schema_attr_clasificacion, 'registry.schema_attr.clasificacion.PUBLIC', $j${"es": "PUBLIC", "en": "PUBLIC"}$j$, 1, true, 30, $j${"value": "PUBLIC"}$j$),
        (v_registry_schema_attr_clasificacion, 'registry.schema_attr.clasificacion.SECRET', $j${"es": "SECRET", "en": "SECRET"}$j$, 1, true, 40, $j${"value": "SECRET"}$j$);

    -- idn_registry_attribute_schema_data_type_check [bauth.idn_registry_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.schema_attr.tipo_dato', $j${"es": "Tipo de dato", "en": "Data Type"}$j$, 0, false, $j${"constraint": "idn_registry_attribute_schema_data_type_check", "columns": ["bauth.idn_registry_attribute_schema.data_type"]}$j$)
    RETURNING item_id INTO v_registry_schema_attr_tipo_dato;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.BINARY', $j${"es": "BINARY", "en": "BINARY"}$j$, 1, true, 10, $j${"value": "BINARY"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.BOOLEAN', $j${"es": "BOOLEAN", "en": "BOOLEAN"}$j$, 1, true, 20, $j${"value": "BOOLEAN"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.DATE', $j${"es": "DATE", "en": "DATE"}$j$, 1, true, 30, $j${"value": "DATE"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.DATETIME', $j${"es": "DATETIME", "en": "DATETIME"}$j$, 1, true, 40, $j${"value": "DATETIME"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.DECIMAL', $j${"es": "DECIMAL", "en": "DECIMAL"}$j$, 1, true, 50, $j${"value": "DECIMAL"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.INTEGER', $j${"es": "INTEGER", "en": "INTEGER"}$j$, 1, true, 60, $j${"value": "INTEGER"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.JSON', $j${"es": "JSON", "en": "JSON"}$j$, 1, true, 70, $j${"value": "JSON"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.TEXT', $j${"es": "TEXT", "en": "TEXT"}$j$, 1, true, 80, $j${"value": "TEXT"}$j$),
        (v_registry_schema_attr_tipo_dato, 'registry.schema_attr.tipo_dato.UUID', $j${"es": "UUID", "en": "UUID"}$j$, 1, true, 90, $j${"value": "UUID"}$j$);

END $$;

-- ── Bloque 7/11 ───────────────────────────────
DO $$
DECLARE
    v_registry_schema_attr_mutabilidad UUID;
    v_registry_schema_attr_fuente UUID;
    v_d15_nhi_agente_tipo_sesion UUID;
    v_d15_nhi_cert_decision UUID;
    v_d15_nhi_identidad_estado UUID;
    v_d15_nhi_identidad_tipo_nhi UUID;
    v_d15_nhi_ciclo_tipo_evento UUID;
    v_rol_ciclo_vida_tipo_disparador UUID;
    v_rol_template_operacion UUID;
    v_rol_ver_retencion_clase_info UUID;
    v_rol_ver_contrato_compatibilidad UUID;
    v_scim_mapeo_attr_mutabilidad_scim UUID;
    v_scim_mapeo_attr_recurso_scim UUID;
    v_scim_mapeo_attr_retorno_scim UUID;
    v_scim_mapeo_attr_tabla_local UUID;
    v_d13_cadena_ca_tipo_ca UUID;
    v_d13_eudi_wallet_estado UUID;
    v_d13_solicitud_firma_tipo_documento UUID;
    v_d13_solicitud_firma_motor UUID;
    v_d13_solicitud_firma_formato_firma UUID;
    v_d13_solicitud_firma_estado UUID;
    v_d13_revocacion_cert_fuente_verificacion UUID;
    v_d13_revocacion_cert_estado UUID;
    v_d13_verificacion_firma_estado_cert UUID;
    v_d13_verificacion_firma_resultado UUID;
BEGIN

    -- idn_registry_attribute_schema_mutability_check [bauth.idn_registry_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.schema_attr.mutabilidad', $j${"es": "Mutabilidad", "en": "Mutability"}$j$, 0, false, $j${"constraint": "idn_registry_attribute_schema_mutability_check", "columns": ["bauth.idn_registry_attribute_schema.mutability"]}$j$)
    RETURNING item_id INTO v_registry_schema_attr_mutabilidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_schema_attr_mutabilidad, 'registry.schema_attr.mutabilidad.READ_ONLY', $j${"es": "READ_ONLY", "en": "READ_ONLY"}$j$, 1, true, 10, $j${"value": "READ_ONLY"}$j$),
        (v_registry_schema_attr_mutabilidad, 'registry.schema_attr.mutabilidad.READ_WRITE', $j${"es": "READ_WRITE", "en": "READ_WRITE"}$j$, 1, true, 20, $j${"value": "READ_WRITE"}$j$),
        (v_registry_schema_attr_mutabilidad, 'registry.schema_attr.mutabilidad.WRITE_ONCE', $j${"es": "WRITE_ONCE", "en": "WRITE_ONCE"}$j$, 1, true, 30, $j${"value": "WRITE_ONCE"}$j$);

    -- idn_registry_attribute_schema_source_check [bauth.idn_registry_attribute_schema]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('registry.schema_attr.fuente', $j${"es": "Fuente", "en": "Source"}$j$, 0, false, $j${"constraint": "idn_registry_attribute_schema_source_check", "columns": ["bauth.idn_registry_attribute_schema.source"]}$j$)
    RETURNING item_id INTO v_registry_schema_attr_fuente;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_registry_schema_attr_fuente, 'registry.schema_attr.fuente.DERIVED', $j${"es": "DERIVED", "en": "DERIVED"}$j$, 1, true, 10, $j${"value": "DERIVED"}$j$),
        (v_registry_schema_attr_fuente, 'registry.schema_attr.fuente.IMPORT', $j${"es": "IMPORT", "en": "IMPORT"}$j$, 1, true, 20, $j${"value": "IMPORT"}$j$),
        (v_registry_schema_attr_fuente, 'registry.schema_attr.fuente.PROOFING', $j${"es": "PROOFING", "en": "PROOFING"}$j$, 1, true, 30, $j${"value": "PROOFING"}$j$),
        (v_registry_schema_attr_fuente, 'registry.schema_attr.fuente.SYSTEM', $j${"es": "SYSTEM", "en": "SYSTEM"}$j$, 1, true, 40, $j${"value": "SYSTEM"}$j$),
        (v_registry_schema_attr_fuente, 'registry.schema_attr.fuente.USER', $j${"es": "USER", "en": "USER"}$j$, 1, true, 50, $j${"value": "USER"}$j$);

    -- chk_iai_session [bauth.idn_roles_nhi_agent_identity]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_agente.tipo_sesion', $j${"es": "Tipo de sesión", "en": "Session Type"}$j$, 0, false, $j${"constraint": "chk_iai_session", "columns": ["bauth.idn_roles_nhi_agent_identity.session_type"]}$j$)
    RETURNING item_id INTO v_d15_nhi_agente_tipo_sesion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_agente_tipo_sesion, 'd15.nhi_agente.tipo_sesion.EPHEMERAL', $j${"es": "EPHEMERAL", "en": "EPHEMERAL"}$j$, 1, true, 10, $j${"value": "EPHEMERAL"}$j$),
        (v_d15_nhi_agente_tipo_sesion, 'd15.nhi_agente.tipo_sesion.PERSISTENT', $j${"es": "PERSISTENT", "en": "PERSISTENT"}$j$, 1, true, 20, $j${"value": "PERSISTENT"}$j$);

    -- chk_inc_decision [bauth.idn_roles_nhi_certification]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_cert.decision', $j${"es": "Decisión", "en": "Decision"}$j$, 0, false, $j${"constraint": "chk_inc_decision", "columns": ["bauth.idn_roles_nhi_certification.decision"]}$j$)
    RETURNING item_id INTO v_d15_nhi_cert_decision;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_cert_decision, 'd15.nhi_cert.decision.CERTIFY', $j${"es": "CERTIFY", "en": "CERTIFY"}$j$, 1, true, 10, $j${"value": "CERTIFY"}$j$),
        (v_d15_nhi_cert_decision, 'd15.nhi_cert.decision.DECOMMISSION', $j${"es": "DECOMMISSION", "en": "DECOMMISSION"}$j$, 1, true, 20, $j${"value": "DECOMMISSION"}$j$),
        (v_d15_nhi_cert_decision, 'd15.nhi_cert.decision.ESCALATE', $j${"es": "ESCALATE", "en": "ESCALATE"}$j$, 1, true, 30, $j${"value": "ESCALATE"}$j$),
        (v_d15_nhi_cert_decision, 'd15.nhi_cert.decision.REDUCE_SCOPE', $j${"es": "REDUCE_SCOPE", "en": "REDUCE_SCOPE"}$j$, 1, true, 40, $j${"value": "REDUCE_SCOPE"}$j$);

    -- chk_inhi_status [bauth.idn_roles_nhi_identity]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_identidad.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_inhi_status", "columns": ["bauth.idn_roles_nhi_identity.status"]}$j$)
    RETURNING item_id INTO v_d15_nhi_identidad_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_identidad_estado, 'd15.nhi_identidad.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d15_nhi_identidad_estado, 'd15.nhi_identidad.estado.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_d15_nhi_identidad_estado, 'd15.nhi_identidad.estado.DORMANT', $j${"es": "DORMANT", "en": "DORMANT"}$j$, 1, true, 30, $j${"value": "DORMANT"}$j$),
        (v_d15_nhi_identidad_estado, 'd15.nhi_identidad.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$);

    -- chk_inhi_type [bauth.idn_roles_nhi_identity]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_identidad.tipo_nhi', $j${"es": "Tipo NHI", "en": "Nhi Type"}$j$, 0, false, $j${"constraint": "chk_inhi_type", "columns": ["bauth.idn_roles_nhi_identity.nhi_type"]}$j$)
    RETURNING item_id INTO v_d15_nhi_identidad_tipo_nhi;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.AGENT', $j${"es": "AGENT", "en": "AGENT"}$j$, 1, true, 10, $j${"value": "AGENT"}$j$),
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.API_CLIENT', $j${"es": "API_CLIENT", "en": "API_CLIENT"}$j$, 1, true, 20, $j${"value": "API_CLIENT"}$j$),
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.BOT', $j${"es": "BOT", "en": "BOT"}$j$, 1, true, 30, $j${"value": "BOT"}$j$),
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.CI_CD_PIPELINE', $j${"es": "CI_CD_PIPELINE", "en": "CI_CD_PIPELINE"}$j$, 1, true, 40, $j${"value": "CI_CD_PIPELINE"}$j$),
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.SERVICE_ACCOUNT', $j${"es": "SERVICE_ACCOUNT", "en": "SERVICE_ACCOUNT"}$j$, 1, true, 50, $j${"value": "SERVICE_ACCOUNT"}$j$),
        (v_d15_nhi_identidad_tipo_nhi, 'd15.nhi_identidad.tipo_nhi.WORKLOAD', $j${"es": "WORKLOAD", "en": "WORKLOAD"}$j$, 1, true, 60, $j${"value": "WORKLOAD"}$j$);

    -- chk_inle_type [bauth.idn_roles_nhi_lifecycle_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d15.nhi_ciclo.tipo_evento', $j${"es": "Tipo de evento", "en": "Event Type"}$j$, 0, false, $j${"constraint": "chk_inle_type", "columns": ["bauth.idn_roles_nhi_lifecycle_event.event_type"]}$j$)
    RETURNING item_id INTO v_d15_nhi_ciclo_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.CERTIFIED', $j${"es": "CERTIFIED", "en": "CERTIFIED"}$j$, 1, true, 10, $j${"value": "CERTIFIED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.OWNER_CHANGED', $j${"es": "OWNER_CHANGED", "en": "OWNER_CHANGED"}$j$, 1, true, 30, $j${"value": "OWNER_CHANGED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.PROVISIONED', $j${"es": "PROVISIONED", "en": "PROVISIONED"}$j$, 1, true, 40, $j${"value": "PROVISIONED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.REACTIVATED', $j${"es": "REACTIVATED", "en": "REACTIVATED"}$j$, 1, true, 50, $j${"value": "REACTIVATED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.REVIEW_SCHEDULED', $j${"es": "REVIEW_SCHEDULED", "en": "REVIEW_SCHEDULED"}$j$, 1, true, 60, $j${"value": "REVIEW_SCHEDULED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.ROTATED', $j${"es": "ROTATED", "en": "ROTATED"}$j$, 1, true, 70, $j${"value": "ROTATED"}$j$),
        (v_d15_nhi_ciclo_tipo_evento, 'd15.nhi_ciclo.tipo_evento.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 80, $j${"value": "SUSPENDED"}$j$);

    -- chk_irle_trigger [bauth.idn_roles_rol_lifecycle_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol.ciclo_vida.tipo_disparador', $j${"es": "Tipo de disparador del ciclo de vida", "en": "Trigger Type"}$j$, 0, false, $j${"constraint": "chk_irle_trigger", "columns": ["bauth.idn_roles_rol_lifecycle_event.trigger_type"]}$j$)
    RETURNING item_id INTO v_rol_ciclo_vida_tipo_disparador;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.AUTO_EXPIRY', $j${"es": "AUTO_EXPIRY", "en": "AUTO_EXPIRY"}$j$, 1, true, 10, $j${"value": "AUTO_EXPIRY"}$j$),
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.BOOTSTRAP', $j${"es": "BOOTSTRAP", "en": "BOOTSTRAP"}$j$, 1, true, 20, $j${"value": "BOOTSTRAP"}$j$),
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.BREAKGLASS', $j${"es": "BREAKGLASS", "en": "BREAKGLASS"}$j$, 1, true, 30, $j${"value": "BREAKGLASS"}$j$),
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.IGA_REVIEW', $j${"es": "IGA_REVIEW", "en": "IGA_REVIEW"}$j$, 1, true, 40, $j${"value": "IGA_REVIEW"}$j$),
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 50, $j${"value": "MANUAL"}$j$),
        (v_rol_ciclo_vida_tipo_disparador, 'rol.ciclo_vida.tipo_disparador.RECONCILE', $j${"es": "RECONCILE", "en": "RECONCILE"}$j$, 1, true, 60, $j${"value": "RECONCILE"}$j$);

    -- idn_roles_template_history_operation_check [bauth.idn_roles_template_history]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol.template.operacion', $j${"es": "Operación", "en": "Operation"}$j$, 0, false, $j${"constraint": "idn_roles_template_history_operation_check", "columns": ["bauth.idn_roles_template_history.operation"]}$j$)
    RETURNING item_id INTO v_rol_template_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_template_operacion, 'rol.template.operacion.DEACTIVATE', $j${"es": "DEACTIVATE", "en": "DEACTIVATE"}$j$, 1, true, 10, $j${"value": "DEACTIVATE"}$j$),
        (v_rol_template_operacion, 'rol.template.operacion.INSERT', $j${"es": "INSERT", "en": "INSERT"}$j$, 1, true, 20, $j${"value": "INSERT"}$j$),
        (v_rol_template_operacion, 'rol.template.operacion.UPDATE', $j${"es": "UPDATE", "en": "UPDATE"}$j$, 1, true, 30, $j${"value": "UPDATE"}$j$);

    -- chk_irvb01rp_class [bauth.idn_roles_ver_b01_retention_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol.ver_retencion.clase_info', $j${"es": "Clase de información", "en": "Info Class"}$j$, 0, false, $j${"constraint": "chk_irvb01rp_class", "columns": ["bauth.idn_roles_ver_b01_retention_policy.info_class"]}$j$)
    RETURNING item_id INTO v_rol_ver_retencion_clase_info;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_ver_retencion_clase_info, 'rol.ver_retencion.clase_info.C1', $j${"es": "C1", "en": "C1"}$j$, 1, true, 10, $j${"value": "C1"}$j$),
        (v_rol_ver_retencion_clase_info, 'rol.ver_retencion.clase_info.C2', $j${"es": "C2", "en": "C2"}$j$, 1, true, 20, $j${"value": "C2"}$j$),
        (v_rol_ver_retencion_clase_info, 'rol.ver_retencion.clase_info.C3', $j${"es": "C3", "en": "C3"}$j$, 1, true, 30, $j${"value": "C3"}$j$),
        (v_rol_ver_retencion_clase_info, 'rol.ver_retencion.clase_info.C4', $j${"es": "C4", "en": "C4"}$j$, 1, true, 40, $j${"value": "C4"}$j$);

    -- chk_irvcrl_compat [bauth.idn_roles_ver_contract_revision_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('rol.ver_contrato.compatibilidad', $j${"es": "Compatibilidad", "en": "Compatibility"}$j$, 0, false, $j${"constraint": "chk_irvcrl_compat", "columns": ["bauth.idn_roles_ver_contract_revision_log.compatibility"]}$j$)
    RETURNING item_id INTO v_rol_ver_contrato_compatibilidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_rol_ver_contrato_compatibilidad, 'rol.ver_contrato.compatibilidad.BREAKING', $j${"es": "BREAKING", "en": "BREAKING"}$j$, 1, true, 10, $j${"value": "BREAKING"}$j$),
        (v_rol_ver_contrato_compatibilidad, 'rol.ver_contrato.compatibilidad.COMPATIBLE', $j${"es": "COMPATIBLE", "en": "COMPATIBLE"}$j$, 1, true, 20, $j${"value": "COMPATIBLE"}$j$);

    -- chk_isam_mutability [bauth.idn_scim_attribute_map]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('scim.mapeo_attr.mutabilidad_scim', $j${"es": "Mutabilidad SCIM", "en": "Scim Mutability"}$j$, 0, false, $j${"constraint": "chk_isam_mutability", "columns": ["bauth.idn_scim_attribute_map.scim_mutability"]}$j$)
    RETURNING item_id INTO v_scim_mapeo_attr_mutabilidad_scim;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_scim_mapeo_attr_mutabilidad_scim, 'scim.mapeo_attr.mutabilidad_scim.immutable', $j${"es": "immutable", "en": "immutable"}$j$, 1, true, 10, $j${"value": "immutable"}$j$),
        (v_scim_mapeo_attr_mutabilidad_scim, 'scim.mapeo_attr.mutabilidad_scim.readOnly', $j${"es": "readOnly", "en": "readOnly"}$j$, 1, true, 20, $j${"value": "readOnly"}$j$),
        (v_scim_mapeo_attr_mutabilidad_scim, 'scim.mapeo_attr.mutabilidad_scim.readWrite', $j${"es": "readWrite", "en": "readWrite"}$j$, 1, true, 30, $j${"value": "readWrite"}$j$),
        (v_scim_mapeo_attr_mutabilidad_scim, 'scim.mapeo_attr.mutabilidad_scim.writeOnly', $j${"es": "writeOnly", "en": "writeOnly"}$j$, 1, true, 40, $j${"value": "writeOnly"}$j$);

    -- chk_isam_resource [bauth.idn_scim_attribute_map]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('scim.mapeo_attr.recurso_scim', $j${"es": "Recurso SCIM", "en": "Scim Resource"}$j$, 0, false, $j${"constraint": "chk_isam_resource", "columns": ["bauth.idn_scim_attribute_map.scim_resource"]}$j$)
    RETURNING item_id INTO v_scim_mapeo_attr_recurso_scim;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_scim_mapeo_attr_recurso_scim, 'scim.mapeo_attr.recurso_scim.CustomResource', $j${"es": "CustomResource", "en": "CustomResource"}$j$, 1, true, 10, $j${"value": "CustomResource"}$j$),
        (v_scim_mapeo_attr_recurso_scim, 'scim.mapeo_attr.recurso_scim.EnterpriseUser', $j${"es": "EnterpriseUser", "en": "EnterpriseUser"}$j$, 1, true, 20, $j${"value": "EnterpriseUser"}$j$),
        (v_scim_mapeo_attr_recurso_scim, 'scim.mapeo_attr.recurso_scim.Group', $j${"es": "Group", "en": "Group"}$j$, 1, true, 30, $j${"value": "Group"}$j$),
        (v_scim_mapeo_attr_recurso_scim, 'scim.mapeo_attr.recurso_scim.ServiceAccount', $j${"es": "ServiceAccount", "en": "ServiceAccount"}$j$, 1, true, 40, $j${"value": "ServiceAccount"}$j$),
        (v_scim_mapeo_attr_recurso_scim, 'scim.mapeo_attr.recurso_scim.User', $j${"es": "User", "en": "User"}$j$, 1, true, 50, $j${"value": "User"}$j$);

    -- chk_isam_returned [bauth.idn_scim_attribute_map]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('scim.mapeo_attr.retorno_scim', $j${"es": "Retorno SCIM", "en": "Scim Returned"}$j$, 0, false, $j${"constraint": "chk_isam_returned", "columns": ["bauth.idn_scim_attribute_map.scim_returned"]}$j$)
    RETURNING item_id INTO v_scim_mapeo_attr_retorno_scim;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_scim_mapeo_attr_retorno_scim, 'scim.mapeo_attr.retorno_scim.always', $j${"es": "always", "en": "always"}$j$, 1, true, 10, $j${"value": "always"}$j$),
        (v_scim_mapeo_attr_retorno_scim, 'scim.mapeo_attr.retorno_scim.default', $j${"es": "default", "en": "default"}$j$, 1, true, 20, $j${"value": "default"}$j$),
        (v_scim_mapeo_attr_retorno_scim, 'scim.mapeo_attr.retorno_scim.never', $j${"es": "never", "en": "never"}$j$, 1, true, 30, $j${"value": "never"}$j$),
        (v_scim_mapeo_attr_retorno_scim, 'scim.mapeo_attr.retorno_scim.request', $j${"es": "request", "en": "request"}$j$, 1, true, 40, $j${"value": "request"}$j$);

    -- chk_isam_table [bauth.idn_scim_attribute_map]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('scim.mapeo_attr.tabla_local', $j${"es": "Tabla local", "en": "Local Table"}$j$, 0, false, $j${"constraint": "chk_isam_table", "columns": ["bauth.idn_scim_attribute_map.local_table"]}$j$)
    RETURNING item_id INTO v_scim_mapeo_attr_tabla_local;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_scim_mapeo_attr_tabla_local, 'scim.mapeo_attr.tabla_local.idn_identidad_atributo', $j${"es": "idn_identidad_atributo", "en": "idn_identidad_atributo"}$j$, 1, true, 10, $j${"value": "idn_identidad_atributo"}$j$),
        (v_scim_mapeo_attr_tabla_local, 'scim.mapeo_attr.tabla_local.idn_identidad_entidad', $j${"es": "idn_identidad_entidad", "en": "idn_identidad_entidad"}$j$, 1, true, 20, $j${"value": "idn_identidad_entidad"}$j$),
        (v_scim_mapeo_attr_tabla_local, 'scim.mapeo_attr.tabla_local.idn_identidad_proofing', $j${"es": "idn_identidad_proofing", "en": "idn_identidad_proofing"}$j$, 1, true, 30, $j${"value": "idn_identidad_proofing"}$j$),
        (v_scim_mapeo_attr_tabla_local, 'scim.mapeo_attr.tabla_local.idn_identidad_vc', $j${"es": "idn_identidad_vc", "en": "idn_identidad_vc"}$j$, 1, true, 40, $j${"value": "idn_identidad_vc"}$j$);

    -- idn_signature_ca_chain_ca_type_check [bauth.idn_signature_ca_chain]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.cadena_ca.tipo_ca', $j${"es": "Tipo de CA", "en": "Ca Type"}$j$, 0, false, $j${"constraint": "idn_signature_ca_chain_ca_type_check", "columns": ["bauth.idn_signature_ca_chain.ca_type"]}$j$)
    RETURNING item_id INTO v_d13_cadena_ca_tipo_ca;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_cadena_ca_tipo_ca, 'd13.cadena_ca.tipo_ca.ADSIB', $j${"es": "ADSIB", "en": "ADSIB"}$j$, 1, true, 10, $j${"value": "ADSIB"}$j$),
        (v_d13_cadena_ca_tipo_ca, 'd13.cadena_ca.tipo_ca.INTERMEDIATE_CA', $j${"es": "INTERMEDIATE_CA", "en": "INTERMEDIATE_CA"}$j$, 1, true, 20, $j${"value": "INTERMEDIATE_CA"}$j$),
        (v_d13_cadena_ca_tipo_ca, 'd13.cadena_ca.tipo_ca.ISSUING_CA', $j${"es": "ISSUING_CA", "en": "ISSUING_CA"}$j$, 1, true, 30, $j${"value": "ISSUING_CA"}$j$),
        (v_d13_cadena_ca_tipo_ca, 'd13.cadena_ca.tipo_ca.ROOT_CA', $j${"es": "ROOT_CA", "en": "ROOT_CA"}$j$, 1, true, 40, $j${"value": "ROOT_CA"}$j$),
        (v_d13_cadena_ca_tipo_ca, 'd13.cadena_ca.tipo_ca.VAULT_PKI', $j${"es": "VAULT_PKI", "en": "VAULT_PKI"}$j$, 1, true, 50, $j${"value": "VAULT_PKI"}$j$);

    -- idn_signature_eudi_wallet_status_check [bauth.idn_signature_eudi_wallet]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.eudi_wallet.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_signature_eudi_wallet_status_check", "columns": ["bauth.idn_signature_eudi_wallet.status"]}$j$)
    RETURNING item_id INTO v_d13_eudi_wallet_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_eudi_wallet_estado, 'd13.eudi_wallet.estado.LINKED', $j${"es": "LINKED", "en": "LINKED"}$j$, 1, true, 10, $j${"value": "LINKED"}$j$),
        (v_d13_eudi_wallet_estado, 'd13.eudi_wallet.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 20, $j${"value": "PENDING"}$j$),
        (v_d13_eudi_wallet_estado, 'd13.eudi_wallet.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_d13_eudi_wallet_estado, 'd13.eudi_wallet.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$);

    -- idn_signature_request_document_type_check [bauth.idn_signature_request]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.solicitud_firma.tipo_documento', $j${"es": "Tipo de documento", "en": "Document Type"}$j$, 0, false, $j${"constraint": "idn_signature_request_document_type_check", "columns": ["bauth.idn_signature_request.document_type"]}$j$)
    RETURNING item_id INTO v_d13_solicitud_firma_tipo_documento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.CONTRACT', $j${"es": "CONTRACT", "en": "CONTRACT"}$j$, 1, true, 10, $j${"value": "CONTRACT"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.INVOICE_SIN', $j${"es": "INVOICE_SIN", "en": "INVOICE_SIN"}$j$, 1, true, 20, $j${"value": "INVOICE_SIN"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.JSON', $j${"es": "JSON", "en": "JSON"}$j$, 1, true, 30, $j${"value": "JSON"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.JWT', $j${"es": "JWT", "en": "JWT"}$j$, 1, true, 40, $j${"value": "JWT"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.PDF', $j${"es": "PDF", "en": "PDF"}$j$, 1, true, 50, $j${"value": "PDF"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.VC', $j${"es": "VC", "en": "VC"}$j$, 1, true, 60, $j${"value": "VC"}$j$),
        (v_d13_solicitud_firma_tipo_documento, 'd13.solicitud_firma.tipo_documento.XML', $j${"es": "XML", "en": "XML"}$j$, 1, true, 70, $j${"value": "XML"}$j$);

    -- idn_signature_request_engine_check [bauth.idn_signature_request]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.solicitud_firma.motor', $j${"es": "Motor", "en": "Engine"}$j$, 0, false, $j${"constraint": "idn_signature_request_engine_check", "columns": ["bauth.idn_signature_request.engine"]}$j$)
    RETURNING item_id INTO v_d13_solicitud_firma_motor;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_solicitud_firma_motor, 'd13.solicitud_firma.motor.DUAL', $j${"es": "DUAL", "en": "DUAL"}$j$, 1, true, 10, $j${"value": "DUAL"}$j$),
        (v_d13_solicitud_firma_motor, 'd13.solicitud_firma.motor.EXTERNAL_ADSIB', $j${"es": "EXTERNAL_ADSIB", "en": "EXTERNAL_ADSIB"}$j$, 1, true, 20, $j${"value": "EXTERNAL_ADSIB"}$j$),
        (v_d13_solicitud_firma_motor, 'd13.solicitud_firma.motor.INTERNAL_ED25519', $j${"es": "INTERNAL_ED25519", "en": "INTERNAL_ED25519"}$j$, 1, true, 30, $j${"value": "INTERNAL_ED25519"}$j$);

    -- idn_signature_request_signature_format_check [bauth.idn_signature_request]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.solicitud_firma.formato_firma', $j${"es": "Formato de firma", "en": "Signature Format"}$j$, 0, false, $j${"constraint": "idn_signature_request_signature_format_check", "columns": ["bauth.idn_signature_request.signature_format"]}$j$)
    RETURNING item_id INTO v_d13_solicitud_firma_formato_firma;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.CADES_B', $j${"es": "CADES_B", "en": "CADES_B"}$j$, 1, true, 10, $j${"value": "CADES_B"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.JADES', $j${"es": "JADES", "en": "JADES"}$j$, 1, true, 20, $j${"value": "JADES"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.PADES_B', $j${"es": "PADES_B", "en": "PADES_B"}$j$, 1, true, 30, $j${"value": "PADES_B"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.PADES_LT', $j${"es": "PADES_LT", "en": "PADES_LT"}$j$, 1, true, 40, $j${"value": "PADES_LT"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.PADES_LTA', $j${"es": "PADES_LTA", "en": "PADES_LTA"}$j$, 1, true, 50, $j${"value": "PADES_LTA"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.PADES_T', $j${"es": "PADES_T", "en": "PADES_T"}$j$, 1, true, 60, $j${"value": "PADES_T"}$j$),
        (v_d13_solicitud_firma_formato_firma, 'd13.solicitud_firma.formato_firma.XADES_B', $j${"es": "XADES_B", "en": "XADES_B"}$j$, 1, true, 70, $j${"value": "XADES_B"}$j$);

    -- idn_signature_request_status_check [bauth.idn_signature_request]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.solicitud_firma.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_signature_request_status_check", "columns": ["bauth.idn_signature_request.status"]}$j$)
    RETURNING item_id INTO v_d13_solicitud_firma_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_solicitud_firma_estado, 'd13.solicitud_firma.estado.CANCELLED', $j${"es": "CANCELLED", "en": "CANCELLED"}$j$, 1, true, 10, $j${"value": "CANCELLED"}$j$),
        (v_d13_solicitud_firma_estado, 'd13.solicitud_firma.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_d13_solicitud_firma_estado, 'd13.solicitud_firma.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$),
        (v_d13_solicitud_firma_estado, 'd13.solicitud_firma.estado.SIGNED', $j${"es": "SIGNED", "en": "SIGNED"}$j$, 1, true, 40, $j${"value": "SIGNED"}$j$),
        (v_d13_solicitud_firma_estado, 'd13.solicitud_firma.estado.SIGNING', $j${"es": "SIGNING", "en": "SIGNING"}$j$, 1, true, 50, $j${"value": "SIGNING"}$j$);

    -- idn_signature_revocation_cache_check_source_check [bauth.idn_signature_revocation_cache]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.revocacion_cert.fuente_verificacion', $j${"es": "Fuente de verificación CRL/OCSP", "en": "Check Source"}$j$, 0, false, $j${"constraint": "idn_signature_revocation_cache_check_source_check", "columns": ["bauth.idn_signature_revocation_cache.check_source"]}$j$)
    RETURNING item_id INTO v_d13_revocacion_cert_fuente_verificacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_revocacion_cert_fuente_verificacion, 'd13.revocacion_cert.fuente_verificacion.CRL', $j${"es": "CRL", "en": "CRL"}$j$, 1, true, 10, $j${"value": "CRL"}$j$),
        (v_d13_revocacion_cert_fuente_verificacion, 'd13.revocacion_cert.fuente_verificacion.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 20, $j${"value": "MANUAL"}$j$),
        (v_d13_revocacion_cert_fuente_verificacion, 'd13.revocacion_cert.fuente_verificacion.OCSP', $j${"es": "OCSP", "en": "OCSP"}$j$, 1, true, 30, $j${"value": "OCSP"}$j$),
        (v_d13_revocacion_cert_fuente_verificacion, 'd13.revocacion_cert.fuente_verificacion.VAULT', $j${"es": "VAULT", "en": "VAULT"}$j$, 1, true, 40, $j${"value": "VAULT"}$j$);

    -- idn_signature_revocation_cache_status_check [bauth.idn_signature_revocation_cache]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.revocacion_cert.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "idn_signature_revocation_cache_status_check", "columns": ["bauth.idn_signature_revocation_cache.status"]}$j$)
    RETURNING item_id INTO v_d13_revocacion_cert_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_revocacion_cert_estado, 'd13.revocacion_cert.estado.GOOD', $j${"es": "GOOD", "en": "GOOD"}$j$, 1, true, 10, $j${"value": "GOOD"}$j$),
        (v_d13_revocacion_cert_estado, 'd13.revocacion_cert.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 20, $j${"value": "REVOKED"}$j$),
        (v_d13_revocacion_cert_estado, 'd13.revocacion_cert.estado.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 30, $j${"value": "UNKNOWN"}$j$);

    -- idn_signature_verification_log_cert_status_check [bauth.idn_signature_verification_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.verificacion_firma.estado_cert', $j${"es": "Estado del certificado", "en": "Cert Status"}$j$, 0, false, $j${"constraint": "idn_signature_verification_log_cert_status_check", "columns": ["bauth.idn_signature_verification_log.cert_status"]}$j$)
    RETURNING item_id INTO v_d13_verificacion_firma_estado_cert;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_verificacion_firma_estado_cert, 'd13.verificacion_firma.estado_cert.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 10, $j${"value": "EXPIRED"}$j$),
        (v_d13_verificacion_firma_estado_cert, 'd13.verificacion_firma.estado_cert.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 20, $j${"value": "REVOKED"}$j$),
        (v_d13_verificacion_firma_estado_cert, 'd13.verificacion_firma.estado_cert.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 30, $j${"value": "UNKNOWN"}$j$),
        (v_d13_verificacion_firma_estado_cert, 'd13.verificacion_firma.estado_cert.VALID', $j${"es": "VALID", "en": "VALID"}$j$, 1, true, 40, $j${"value": "VALID"}$j$);

    -- idn_signature_verification_log_outcome_check [bauth.idn_signature_verification_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d13.verificacion_firma.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "idn_signature_verification_log_outcome_check", "columns": ["bauth.idn_signature_verification_log.outcome"]}$j$)
    RETURNING item_id INTO v_d13_verificacion_firma_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 10, $j${"value": "ERROR"}$j$),
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.INVALID', $j${"es": "INVALID", "en": "INVALID"}$j$, 1, true, 30, $j${"value": "INVALID"}$j$),
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 40, $j${"value": "REVOKED"}$j$),
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.UNKNOWN', $j${"es": "UNKNOWN", "en": "UNKNOWN"}$j$, 1, true, 50, $j${"value": "UNKNOWN"}$j$),
        (v_d13_verificacion_firma_resultado, 'd13.verificacion_firma.resultado.VALID', $j${"es": "VALID", "en": "VALID"}$j$, 1, true, 60, $j${"value": "VALID"}$j$);

END $$;

-- ── Bloque 8/11 ───────────────────────────────
DO $$
DECLARE
    v_d04_excepcion_temp_tipo_excepcion UUID;
    v_d04_turno_tipo_rotacion UUID;
    v_d04_ventana_temporal_tipo_ventana UUID;
    v_identidad_usuario_metodo_registro UUID;
    v_identidad_usuario_estado UUID;
    v_identidad_recuperacion_estado UUID;
    v_identidad_recuperacion_tipo UUID;
    v_d14_breakglass_metodo_auth UUID;
    v_d14_breakglass_estado UUID;
    v_d14_breakglass_estado__control UUID;
    v_d14_credencial_priv_politica_rotacion UUID;
    v_d14_credencial_priv_estado UUID;
    v_d14_credencial_priv_tipo_credencial UUID;
    v_d14_cuenta_priv_estado UUID;
    v_d14_cuenta_priv_tipo UUID;
    v_d14_jit_decision UUID;
    v_d14_nhi_secreto_politica_rotacion UUID;
    v_d14_sesion_priv_estado UUID;
    v_d14_grabacion_storage_type UUID;
    v_priv_aseguramiento_resultado UUID;
    v_priv_atom_operacion UUID;
    v_priv_delegacion_estado UUID;
    v_priv_excepcion_reg_tipo_excepcion UUID;
    v_priv_anulacion_tipo_anulacion UUID;
    v_priv_recurso_ruta_eval UUID;
BEGIN

    -- idn_temporal_exception_exception_type_check [bauth.idn_temporal_exception]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d04.excepcion_temp.tipo_excepcion', $j${"es": "Tipo de excepción", "en": "Exception Type"}$j$, 0, false, $j${"constraint": "idn_temporal_exception_exception_type_check", "columns": ["bauth.idn_temporal_exception.exception_type"]}$j$)
    RETURNING item_id INTO v_d04_excepcion_temp_tipo_excepcion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d04_excepcion_temp_tipo_excepcion, 'd04.excepcion_temp.tipo_excepcion.ADDITIONAL_GUARD', $j${"es": "ADDITIONAL_GUARD", "en": "ADDITIONAL_GUARD"}$j$, 1, true, 10, $j${"value": "ADDITIONAL_GUARD"}$j$),
        (v_d04_excepcion_temp_tipo_excepcion, 'd04.excepcion_temp.tipo_excepcion.BLOCK', $j${"es": "BLOCK", "en": "BLOCK"}$j$, 1, true, 20, $j${"value": "BLOCK"}$j$),
        (v_d04_excepcion_temp_tipo_excepcion, 'd04.excepcion_temp.tipo_excepcion.EXTENSION', $j${"es": "EXTENSION", "en": "EXTENSION"}$j$, 1, true, 30, $j${"value": "EXTENSION"}$j$),
        (v_d04_excepcion_temp_tipo_excepcion, 'd04.excepcion_temp.tipo_excepcion.REDUCTION', $j${"es": "REDUCTION", "en": "REDUCTION"}$j$, 1, true, 40, $j${"value": "REDUCTION"}$j$);

    -- idn_temporal_shift_rotation_type_check [bauth.idn_temporal_shift]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d04.turno.tipo_rotacion', $j${"es": "Tipo de rotación", "en": "Rotation Type"}$j$, 0, false, $j${"constraint": "idn_temporal_shift_rotation_type_check", "columns": ["bauth.idn_temporal_shift.rotation_type"]}$j$)
    RETURNING item_id INTO v_d04_turno_tipo_rotacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d04_turno_tipo_rotacion, 'd04.turno.tipo_rotacion.FIXED', $j${"es": "FIXED", "en": "FIXED"}$j$, 1, true, 10, $j${"value": "FIXED"}$j$),
        (v_d04_turno_tipo_rotacion, 'd04.turno.tipo_rotacion.FLEXIBLE', $j${"es": "FLEXIBLE", "en": "FLEXIBLE"}$j$, 1, true, 20, $j${"value": "FLEXIBLE"}$j$),
        (v_d04_turno_tipo_rotacion, 'd04.turno.tipo_rotacion.GUARD', $j${"es": "GUARD", "en": "GUARD"}$j$, 1, true, 30, $j${"value": "GUARD"}$j$),
        (v_d04_turno_tipo_rotacion, 'd04.turno.tipo_rotacion.ROTATING', $j${"es": "ROTATING", "en": "ROTATING"}$j$, 1, true, 40, $j${"value": "ROTATING"}$j$);

    -- idn_temporal_window_window_type_check [bauth.idn_temporal_window]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d04.ventana_temporal.tipo_ventana', $j${"es": "Tipo de ventana temporal", "en": "Window Type"}$j$, 0, false, $j${"constraint": "idn_temporal_window_window_type_check", "columns": ["bauth.idn_temporal_window.window_type"]}$j$)
    RETURNING item_id INTO v_d04_ventana_temporal_tipo_ventana;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d04_ventana_temporal_tipo_ventana, 'd04.ventana_temporal.tipo_ventana.CUSTOM', $j${"es": "CUSTOM", "en": "CUSTOM"}$j$, 1, true, 10, $j${"value": "CUSTOM"}$j$),
        (v_d04_ventana_temporal_tipo_ventana, 'd04.ventana_temporal.tipo_ventana.DAILY', $j${"es": "DAILY", "en": "DAILY"}$j$, 1, true, 20, $j${"value": "DAILY"}$j$),
        (v_d04_ventana_temporal_tipo_ventana, 'd04.ventana_temporal.tipo_ventana.MONTHLY', $j${"es": "MONTHLY", "en": "MONTHLY"}$j$, 1, true, 30, $j${"value": "MONTHLY"}$j$),
        (v_d04_ventana_temporal_tipo_ventana, 'd04.ventana_temporal.tipo_ventana.TIME_OF_DAY', $j${"es": "TIME_OF_DAY", "en": "TIME_OF_DAY"}$j$, 1, true, 40, $j${"value": "TIME_OF_DAY"}$j$),
        (v_d04_ventana_temporal_tipo_ventana, 'd04.ventana_temporal.tipo_ventana.WEEKLY', $j${"es": "WEEKLY", "en": "WEEKLY"}$j$, 1, true, 50, $j${"value": "WEEKLY"}$j$);

    -- chk_iu_reg_method [bauth.idn_user]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.usuario.metodo_registro', $j${"es": "Método de registro", "en": "Registration Method"}$j$, 0, false, $j${"constraint": "chk_iu_reg_method", "columns": ["bauth.idn_user.registration_method"]}$j$)
    RETURNING item_id INTO v_identidad_usuario_metodo_registro;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_usuario_metodo_registro, 'identidad.usuario.metodo_registro.ADMIN', $j${"es": "ADMIN", "en": "ADMIN"}$j$, 1, true, 10, $j${"value": "ADMIN"}$j$),
        (v_identidad_usuario_metodo_registro, 'identidad.usuario.metodo_registro.FEDERATED', $j${"es": "FEDERATED", "en": "FEDERATED"}$j$, 1, true, 20, $j${"value": "FEDERATED"}$j$),
        (v_identidad_usuario_metodo_registro, 'identidad.usuario.metodo_registro.PROVISIONED', $j${"es": "PROVISIONED", "en": "PROVISIONED"}$j$, 1, true, 30, $j${"value": "PROVISIONED"}$j$),
        (v_identidad_usuario_metodo_registro, 'identidad.usuario.metodo_registro.SELF_SERVICE', $j${"es": "SELF_SERVICE", "en": "SELF_SERVICE"}$j$, 1, true, 40, $j${"value": "SELF_SERVICE"}$j$);

    -- chk_iu_status [bauth.idn_user]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.usuario.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_iu_status", "columns": ["bauth.idn_user.status"]}$j$)
    RETURNING item_id INTO v_identidad_usuario_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_usuario_estado, 'identidad.usuario.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_identidad_usuario_estado, 'identidad.usuario.estado.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_identidad_usuario_estado, 'identidad.usuario.estado.DEACTIVATED', $j${"es": "DEACTIVATED", "en": "DEACTIVATED"}$j$, 1, true, 30, $j${"value": "DEACTIVATED"}$j$),
        (v_identidad_usuario_estado, 'identidad.usuario.estado.LOCKED', $j${"es": "LOCKED", "en": "LOCKED"}$j$, 1, true, 40, $j${"value": "LOCKED"}$j$),
        (v_identidad_usuario_estado, 'identidad.usuario.estado.PENDING_ACTIVATION', $j${"es": "PENDING_ACTIVATION", "en": "PENDING_ACTIVATION"}$j$, 1, true, 50, $j${"value": "PENDING_ACTIVATION"}$j$),
        (v_identidad_usuario_estado, 'identidad.usuario.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 60, $j${"value": "SUSPENDED"}$j$);

    -- chk_iur_status [bauth.idn_user_recovery]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.recuperacion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_iur_status", "columns": ["bauth.idn_user_recovery.status"]}$j$)
    RETURNING item_id INTO v_identidad_recuperacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_recuperacion_estado, 'identidad.recuperacion.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_identidad_recuperacion_estado, 'identidad.recuperacion.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 20, $j${"value": "REVOKED"}$j$),
        (v_identidad_recuperacion_estado, 'identidad.recuperacion.estado.USED', $j${"es": "USED", "en": "USED"}$j$, 1, true, 30, $j${"value": "USED"}$j$);

    -- chk_iur_type [bauth.idn_user_recovery]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('identidad.recuperacion.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_iur_type", "columns": ["bauth.idn_user_recovery.type"]}$j$)
    RETURNING item_id INTO v_identidad_recuperacion_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_identidad_recuperacion_tipo, 'identidad.recuperacion.tipo.ADMIN_OVERRIDE', $j${"es": "ADMIN_OVERRIDE", "en": "ADMIN_OVERRIDE"}$j$, 1, true, 10, $j${"value": "ADMIN_OVERRIDE"}$j$),
        (v_identidad_recuperacion_tipo, 'identidad.recuperacion.tipo.BACKUP_EMAIL', $j${"es": "BACKUP_EMAIL", "en": "BACKUP_EMAIL"}$j$, 1, true, 20, $j${"value": "BACKUP_EMAIL"}$j$),
        (v_identidad_recuperacion_tipo, 'identidad.recuperacion.tipo.BACKUP_PHONE', $j${"es": "BACKUP_PHONE", "en": "BACKUP_PHONE"}$j$, 1, true, 30, $j${"value": "BACKUP_PHONE"}$j$),
        (v_identidad_recuperacion_tipo, 'identidad.recuperacion.tipo.TRUSTED_CONTACT', $j${"es": "TRUSTED_CONTACT", "en": "TRUSTED_CONTACT"}$j$, 1, true, 40, $j${"value": "TRUSTED_CONTACT"}$j$);

    -- chk_pbga_auth_method [bauth.pam_breakglass_activation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.breakglass.metodo_auth', $j${"es": "Método de autenticación privilegiada", "en": "Auth Method"}$j$, 0, false, $j${"constraint": "chk_pbga_auth_method", "columns": ["bauth.pam_breakglass_activation.auth_method"]}$j$)
    RETURNING item_id INTO v_d14_breakglass_metodo_auth;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_breakglass_metodo_auth, 'd14.breakglass.metodo_auth.MTLS_X509', $j${"es": "MTLS_X509", "en": "MTLS_X509"}$j$, 1, true, 10, $j${"value": "MTLS_X509"}$j$),
        (v_d14_breakglass_metodo_auth, 'd14.breakglass.metodo_auth.WEBAUTHN_PLATFORM', $j${"es": "WEBAUTHN_PLATFORM", "en": "WEBAUTHN_PLATFORM"}$j$, 1, true, 20, $j${"value": "WEBAUTHN_PLATFORM"}$j$),
        (v_d14_breakglass_metodo_auth, 'd14.breakglass.metodo_auth.WEBAUTHN_ROAMING', $j${"es": "WEBAUTHN_ROAMING", "en": "WEBAUTHN_ROAMING"}$j$, 1, true, 30, $j${"value": "WEBAUTHN_ROAMING"}$j$);

    -- chk_pbga_deactivation [bauth.pam_breakglass_activation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.breakglass.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_pbga_deactivation", "columns": ["bauth.pam_breakglass_activation.status"]}$j$)
    RETURNING item_id INTO v_d14_breakglass_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_breakglass_estado, 'd14.breakglass.estado.DEACTIVATED', $j${"es": "DEACTIVATED", "en": "DEACTIVATED"}$j$, 1, true, 10, $j${"value": "DEACTIVATED"}$j$),
        (v_d14_breakglass_estado, 'd14.breakglass.estado.REVIEWED', $j${"es": "REVIEWED", "en": "REVIEWED"}$j$, 1, true, 20, $j${"value": "REVIEWED"}$j$);

    -- chk_pbga_dual_control [bauth.pam_breakglass_activation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.breakglass.estado._control', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_pbga_dual_control", "columns": ["bauth.pam_breakglass_activation.status"]}$j$)
    RETURNING item_id INTO v_d14_breakglass_estado__control;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_breakglass_estado__control, 'd14.breakglass.estado._control.DEACTIVATED', $j${"es": "DEACTIVATED", "en": "DEACTIVATED"}$j$, 1, true, 10, $j${"value": "DEACTIVATED"}$j$),
        (v_d14_breakglass_estado__control, 'd14.breakglass.estado._control.PENDING_APPROVAL', $j${"es": "PENDING_APPROVAL", "en": "PENDING_APPROVAL"}$j$, 1, true, 20, $j${"value": "PENDING_APPROVAL"}$j$),
        (v_d14_breakglass_estado__control, 'd14.breakglass.estado._control.REVIEWED', $j${"es": "REVIEWED", "en": "REVIEWED"}$j$, 1, true, 30, $j${"value": "REVIEWED"}$j$);

    -- chk_pcref_rot [bauth.pam_credential_ref]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.credencial_priv.politica_rotacion', $j${"es": "Política de rotación", "en": "Rotation Policy"}$j$, 0, false, $j${"constraint": "chk_pcref_rot", "columns": ["bauth.pam_credential_ref.rotation_policy"]}$j$)
    RETURNING item_id INTO v_d14_credencial_priv_politica_rotacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_credencial_priv_politica_rotacion, 'd14.credencial_priv.politica_rotacion.AUTO_1Y', $j${"es": "AUTO_1Y", "en": "AUTO_1Y"}$j$, 1, true, 10, $j${"value": "AUTO_1Y"}$j$),
        (v_d14_credencial_priv_politica_rotacion, 'd14.credencial_priv.politica_rotacion.AUTO_30D', $j${"es": "AUTO_30D", "en": "AUTO_30D"}$j$, 1, true, 20, $j${"value": "AUTO_30D"}$j$),
        (v_d14_credencial_priv_politica_rotacion, 'd14.credencial_priv.politica_rotacion.AUTO_7D', $j${"es": "AUTO_7D", "en": "AUTO_7D"}$j$, 1, true, 30, $j${"value": "AUTO_7D"}$j$),
        (v_d14_credencial_priv_politica_rotacion, 'd14.credencial_priv.politica_rotacion.AUTO_90D', $j${"es": "AUTO_90D", "en": "AUTO_90D"}$j$, 1, true, 40, $j${"value": "AUTO_90D"}$j$),
        (v_d14_credencial_priv_politica_rotacion, 'd14.credencial_priv.politica_rotacion.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 50, $j${"value": "MANUAL"}$j$);

    -- chk_pcref_status [bauth.pam_credential_ref]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.credencial_priv.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_pcref_status", "columns": ["bauth.pam_credential_ref.status", "bauth.pam_nhi_secret_ref.status"]}$j$)
    RETURNING item_id INTO v_d14_credencial_priv_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_credencial_priv_estado, 'd14.credencial_priv.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d14_credencial_priv_estado, 'd14.credencial_priv.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_d14_credencial_priv_estado, 'd14.credencial_priv.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_d14_credencial_priv_estado, 'd14.credencial_priv.estado.ROTATING', $j${"es": "ROTATING", "en": "ROTATING"}$j$, 1, true, 40, $j${"value": "ROTATING"}$j$);

    -- chk_pcref_type [bauth.pam_credential_ref]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.credencial_priv.tipo_credencial', $j${"es": "Tipo de credencial", "en": "Credential Type"}$j$, 0, false, $j${"constraint": "chk_pcref_type", "columns": ["bauth.pam_credential_ref.credential_type", "bauth.pam_nhi_secret_ref.secret_type"]}$j$)
    RETURNING item_id INTO v_d14_credencial_priv_tipo_credencial;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.API_KEY', $j${"es": "API_KEY", "en": "API_KEY"}$j$, 1, true, 10, $j${"value": "API_KEY"}$j$),
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.CERT', $j${"es": "CERT", "en": "CERT"}$j$, 1, true, 20, $j${"value": "CERT"}$j$),
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.OAUTH_CLIENT', $j${"es": "OAUTH_CLIENT", "en": "OAUTH_CLIENT"}$j$, 1, true, 30, $j${"value": "OAUTH_CLIENT"}$j$),
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.PASSWORD', $j${"es": "PASSWORD", "en": "PASSWORD"}$j$, 1, true, 40, $j${"value": "PASSWORD"}$j$),
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.SSH_KEY', $j${"es": "SSH_KEY", "en": "SSH_KEY"}$j$, 1, true, 50, $j${"value": "SSH_KEY"}$j$),
        (v_d14_credencial_priv_tipo_credencial, 'd14.credencial_priv.tipo_credencial.TOKEN', $j${"es": "TOKEN", "en": "TOKEN"}$j$, 1, true, 60, $j${"value": "TOKEN"}$j$);

    -- chk_pcp_estado [bauth.pam_cuenta_privilegiada]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.cuenta_priv.estado', $j${"es": "Estado", "en": "Estado"}$j$, 0, false, $j${"constraint": "chk_pcp_estado", "columns": ["bauth.pam_cuenta_privilegiada.estado"]}$j$)
    RETURNING item_id INTO v_d14_cuenta_priv_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_cuenta_priv_estado, 'd14.cuenta_priv.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d14_cuenta_priv_estado, 'd14.cuenta_priv.estado.DECOMMISSIONED', $j${"es": "DECOMMISSIONED", "en": "DECOMMISSIONED"}$j$, 1, true, 20, $j${"value": "DECOMMISSIONED"}$j$),
        (v_d14_cuenta_priv_estado, 'd14.cuenta_priv.estado.INACTIVE', $j${"es": "INACTIVE", "en": "INACTIVE"}$j$, 1, true, 30, $j${"value": "INACTIVE"}$j$);

    -- chk_pcp_tipo [bauth.pam_cuenta_privilegiada]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.cuenta_priv.tipo', $j${"es": "Tipo", "en": "Tipo"}$j$, 0, false, $j${"constraint": "chk_pcp_tipo", "columns": ["bauth.pam_cuenta_privilegiada.tipo"]}$j$)
    RETURNING item_id INTO v_d14_cuenta_priv_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.API_KEY', $j${"es": "API_KEY", "en": "API_KEY"}$j$, 1, true, 10, $j${"value": "API_KEY"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.CERTIFICATE', $j${"es": "CERTIFICATE", "en": "CERTIFICATE"}$j$, 1, true, 20, $j${"value": "CERTIFICATE"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.CLOUD_ADMIN', $j${"es": "CLOUD_ADMIN", "en": "CLOUD_ADMIN"}$j$, 1, true, 30, $j${"value": "CLOUD_ADMIN"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.DATABASE_DBA', $j${"es": "DATABASE_DBA", "en": "DATABASE_DBA"}$j$, 1, true, 40, $j${"value": "DATABASE_DBA"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.DOMAIN_ADMIN', $j${"es": "DOMAIN_ADMIN", "en": "DOMAIN_ADMIN"}$j$, 1, true, 50, $j${"value": "DOMAIN_ADMIN"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.LOCAL_ADMIN', $j${"es": "LOCAL_ADMIN", "en": "LOCAL_ADMIN"}$j$, 1, true, 60, $j${"value": "LOCAL_ADMIN"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.ROOT', $j${"es": "ROOT", "en": "ROOT"}$j$, 1, true, 70, $j${"value": "ROOT"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.SERVICE_ACCOUNT', $j${"es": "SERVICE_ACCOUNT", "en": "SERVICE_ACCOUNT"}$j$, 1, true, 80, $j${"value": "SERVICE_ACCOUNT"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.SHARED', $j${"es": "SHARED", "en": "SHARED"}$j$, 1, true, 90, $j${"value": "SHARED"}$j$),
        (v_d14_cuenta_priv_tipo, 'd14.cuenta_priv.tipo.SSH_KEY', $j${"es": "SSH_KEY", "en": "SSH_KEY"}$j$, 1, true, 100, $j${"value": "SSH_KEY"}$j$);

    -- chk_pja_decision [bauth.pam_jit_approval]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.jit.decision', $j${"es": "Decisión", "en": "Decision"}$j$, 0, false, $j${"constraint": "chk_pja_decision", "columns": ["bauth.pam_jit_approval.decision"]}$j$)
    RETURNING item_id INTO v_d14_jit_decision;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_jit_decision, 'd14.jit.decision.APPROVED', $j${"es": "APPROVED", "en": "APPROVED"}$j$, 1, true, 10, $j${"value": "APPROVED"}$j$),
        (v_d14_jit_decision, 'd14.jit.decision.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 20, $j${"value": "REJECTED"}$j$);

    -- chk_pnsr_rotation [bauth.pam_nhi_secret_ref]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.nhi_secreto.politica_rotacion', $j${"es": "Política de rotación", "en": "Rotation Policy"}$j$, 0, false, $j${"constraint": "chk_pnsr_rotation", "columns": ["bauth.pam_nhi_secret_ref.rotation_policy"]}$j$)
    RETURNING item_id INTO v_d14_nhi_secreto_politica_rotacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_nhi_secreto_politica_rotacion, 'd14.nhi_secreto.politica_rotacion.AUTO_30D', $j${"es": "AUTO_30D", "en": "AUTO_30D"}$j$, 1, true, 10, $j${"value": "AUTO_30D"}$j$),
        (v_d14_nhi_secreto_politica_rotacion, 'd14.nhi_secreto.politica_rotacion.AUTO_7D', $j${"es": "AUTO_7D", "en": "AUTO_7D"}$j$, 1, true, 20, $j${"value": "AUTO_7D"}$j$),
        (v_d14_nhi_secreto_politica_rotacion, 'd14.nhi_secreto.politica_rotacion.AUTO_90D', $j${"es": "AUTO_90D", "en": "AUTO_90D"}$j$, 1, true, 30, $j${"value": "AUTO_90D"}$j$),
        (v_d14_nhi_secreto_politica_rotacion, 'd14.nhi_secreto.politica_rotacion.MANUAL', $j${"es": "MANUAL", "en": "MANUAL"}$j$, 1, true, 40, $j${"value": "MANUAL"}$j$),
        (v_d14_nhi_secreto_politica_rotacion, 'd14.nhi_secreto.politica_rotacion.ON_USE', $j${"es": "ON_USE", "en": "ON_USE"}$j$, 1, true, 50, $j${"value": "ON_USE"}$j$);

    -- chk_psr_status [bauth.pam_session_record]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.sesion_priv.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_psr_status", "columns": ["bauth.pam_session_record.status"]}$j$)
    RETURNING item_id INTO v_d14_sesion_priv_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_sesion_priv_estado, 'd14.sesion_priv.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_d14_sesion_priv_estado, 'd14.sesion_priv.estado.ENDED', $j${"es": "ENDED", "en": "ENDED"}$j$, 1, true, 20, $j${"value": "ENDED"}$j$),
        (v_d14_sesion_priv_estado, 'd14.sesion_priv.estado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 30, $j${"value": "ERROR"}$j$),
        (v_d14_sesion_priv_estado, 'd14.sesion_priv.estado.TERMINATED', $j${"es": "TERMINATED", "en": "TERMINATED"}$j$, 1, true, 40, $j${"value": "TERMINATED"}$j$);

    -- pam_session_recording_storage_type_check [bauth.pam_session_recording]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('d14.grabacion.storage.type', $j${"es": "Tipo de almacenamiento", "en": "Storage Type"}$j$, 0, false, $j${"constraint": "pam_session_recording_storage_type_check", "columns": ["bauth.pam_session_recording.storage_type"]}$j$)
    RETURNING item_id INTO v_d14_grabacion_storage_type;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_d14_grabacion_storage_type, 'd14.grabacion.storage.type.LOCAL', $j${"es": "LOCAL", "en": "LOCAL"}$j$, 1, true, 10, $j${"value": "LOCAL"}$j$),
        (v_d14_grabacion_storage_type, 'd14.grabacion.storage.type.MINIO', $j${"es": "MINIO", "en": "MINIO"}$j$, 1, true, 20, $j${"value": "MINIO"}$j$),
        (v_d14_grabacion_storage_type, 'd14.grabacion.storage.type.NFS', $j${"es": "NFS", "en": "NFS"}$j$, 1, true, 30, $j${"value": "NFS"}$j$),
        (v_d14_grabacion_storage_type, 'd14.grabacion.storage.type.S3', $j${"es": "S3", "en": "S3"}$j$, 1, true, 40, $j${"value": "S3"}$j$);

    -- privilege_assurance_audit_outcome_check [bauth.privilege_assurance_audit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.aseguramiento.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "privilege_assurance_audit_outcome_check", "columns": ["bauth.privilege_assurance_audit.outcome"]}$j$)
    RETURNING item_id INTO v_priv_aseguramiento_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_aseguramiento_resultado, 'priv.aseguramiento.resultado.DENIED', $j${"es": "DENIED", "en": "DENIED"}$j$, 1, true, 10, $j${"value": "DENIED"}$j$),
        (v_priv_aseguramiento_resultado, 'priv.aseguramiento.resultado.PERMIT', $j${"es": "PERMIT", "en": "PERMIT"}$j$, 1, true, 20, $j${"value": "PERMIT"}$j$),
        (v_priv_aseguramiento_resultado, 'priv.aseguramiento.resultado.STEP_UP_REQUIRED', $j${"es": "STEP_UP_REQUIRED", "en": "STEP_UP_REQUIRED"}$j$, 1, true, 30, $j${"value": "STEP_UP_REQUIRED"}$j$);

    -- privilege_atom_audit_operation_check [bauth.privilege_atom_audit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.atom.operacion', $j${"es": "Operación", "en": "Operation"}$j$, 0, false, $j${"constraint": "privilege_atom_audit_operation_check", "columns": ["bauth.privilege_atom_audit.operation", "bauth.privilege_atom_audit_2026_07.operation", "bauth.privilege_atom_audit_2026_08.operation", "bauth.privilege_atom_audit_2026_09.operation"]}$j$)
    RETURNING item_id INTO v_priv_atom_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_atom_operacion, 'priv.atom.operacion.BREAKGLASS', $j${"es": "BREAKGLASS", "en": "BREAKGLASS"}$j$, 1, true, 10, $j${"value": "BREAKGLASS"}$j$),
        (v_priv_atom_operacion, 'priv.atom.operacion.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_priv_atom_operacion, 'priv.atom.operacion.GRANTED', $j${"es": "GRANTED", "en": "GRANTED"}$j$, 1, true, 30, $j${"value": "GRANTED"}$j$),
        (v_priv_atom_operacion, 'priv.atom.operacion.MODIFIED', $j${"es": "MODIFIED", "en": "MODIFIED"}$j$, 1, true, 40, $j${"value": "MODIFIED"}$j$),
        (v_priv_atom_operacion, 'priv.atom.operacion.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 50, $j${"value": "REVOKED"}$j$),
        (v_priv_atom_operacion, 'priv.atom.operacion.STEP_UP', $j${"es": "STEP_UP", "en": "STEP_UP"}$j$, 1, true, 60, $j${"value": "STEP_UP"}$j$);

    -- chk_pd_status [bauth.privilege_delegation]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.delegacion.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_pd_status", "columns": ["bauth.privilege_delegation.status", "bauth.privilege_exception_record.status", "bauth.privilege_override.status"]}$j$)
    RETURNING item_id INTO v_priv_delegacion_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_delegacion_estado, 'priv.delegacion.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_priv_delegacion_estado, 'priv.delegacion.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_priv_delegacion_estado, 'priv.delegacion.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$);

    -- chk_per_type [bauth.privilege_exception_record]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.excepcion_reg.tipo_excepcion', $j${"es": "Tipo de excepción", "en": "Exception Type"}$j$, 0, false, $j${"constraint": "chk_per_type", "columns": ["bauth.privilege_exception_record.exception_type"]}$j$)
    RETURNING item_id INTO v_priv_excepcion_reg_tipo_excepcion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_excepcion_reg_tipo_excepcion, 'priv.excepcion_reg.tipo_excepcion.OTHER', $j${"es": "OTHER", "en": "OTHER"}$j$, 1, true, 10, $j${"value": "OTHER"}$j$),
        (v_priv_excepcion_reg_tipo_excepcion, 'priv.excepcion_reg.tipo_excepcion.SCOPE_EXCEPTION', $j${"es": "SCOPE_EXCEPTION", "en": "SCOPE_EXCEPTION"}$j$, 1, true, 20, $j${"value": "SCOPE_EXCEPTION"}$j$),
        (v_priv_excepcion_reg_tipo_excepcion, 'priv.excepcion_reg.tipo_excepcion.SOD_EXCEPTION', $j${"es": "SOD_EXCEPTION", "en": "SOD_EXCEPTION"}$j$, 1, true, 30, $j${"value": "SOD_EXCEPTION"}$j$),
        (v_priv_excepcion_reg_tipo_excepcion, 'priv.excepcion_reg.tipo_excepcion.TIER_EXCEPTION', $j${"es": "TIER_EXCEPTION", "en": "TIER_EXCEPTION"}$j$, 1, true, 40, $j${"value": "TIER_EXCEPTION"}$j$);

    -- chk_po_override_type [bauth.privilege_override]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.anulacion.tipo_anulacion', $j${"es": "Tipo de anulación", "en": "Override Type"}$j$, 0, false, $j${"constraint": "chk_po_override_type", "columns": ["bauth.privilege_override.override_type"]}$j$)
    RETURNING item_id INTO v_priv_anulacion_tipo_anulacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_anulacion_tipo_anulacion, 'priv.anulacion.tipo_anulacion.DENY_TO_PERMIT', $j${"es": "DENY_TO_PERMIT", "en": "DENY_TO_PERMIT"}$j$, 1, true, 10, $j${"value": "DENY_TO_PERMIT"}$j$),
        (v_priv_anulacion_tipo_anulacion, 'priv.anulacion.tipo_anulacion.PERMIT_TO_DENY', $j${"es": "PERMIT_TO_DENY", "en": "PERMIT_TO_DENY"}$j$, 1, true, 20, $j${"value": "PERMIT_TO_DENY"}$j$);

    -- chk_pra_eval_path [bauth.privilege_resource_atom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.recurso.ruta_eval', $j${"es": "Ruta de evaluación", "en": "Evaluation Path"}$j$, 0, false, $j${"constraint": "chk_pra_eval_path", "columns": ["bauth.privilege_resource_atom.evaluation_path"]}$j$)
    RETURNING item_id INTO v_priv_recurso_ruta_eval;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_recurso_ruta_eval, 'priv.recurso.ruta_eval.EXTERNAL', $j${"es": "EXTERNAL", "en": "EXTERNAL"}$j$, 1, true, 10, $j${"value": "EXTERNAL"}$j$),
        (v_priv_recurso_ruta_eval, 'priv.recurso.ruta_eval.FAST', $j${"es": "FAST", "en": "FAST"}$j$, 1, true, 20, $j${"value": "FAST"}$j$),
        (v_priv_recurso_ruta_eval, 'priv.recurso.ruta_eval.POLICY', $j${"es": "POLICY", "en": "POLICY"}$j$, 1, true, 30, $j${"value": "POLICY"}$j$),
        (v_priv_recurso_ruta_eval, 'priv.recurso.ruta_eval.PRECONDITION', $j${"es": "PRECONDITION", "en": "PRECONDITION"}$j$, 1, true, 40, $j${"value": "PRECONDITION"}$j$);

END $$;

-- ── Bloque 9/11 ───────────────────────────────
DO $$
DECLARE
    v_priv_recurso_estado UUID;
    v_priv_recurso_alcance_tenant UUID;
    v_priv_recurso_tipo_protocolo UUID;
    v_priv_verbo_conflicto_tipo_conflicto UUID;
    v_ses_caep_tipo_evento UUID;
    v_ses_caep_tipo_sujeto UUID;
    v_ses_sesion_motivo_fin UUID;
    v_ses_ssf_estado UUID;
    v_sig_adsib_ciclo_event UUID;
    v_sig_certificado_tipo_adsib UUID;
    v_sig_certificado_motor UUID;
    v_sig_crl_motor UUID;
    v_sig_doc_politica_engine_required UUID;
    v_sig_doc_politica_external_profile UUID;
    v_sig_doc_politica_internal_profile UUID;
    v_sig_llave_purpose UUID;
    v_sig_llave_estado UUID;
    v_sig_operacion_resultado UUID;
    v_sig_operacion_tipo_firmante UUID;
    v_vc_wallet_metodo_respaldo UUID;
    v_vc_wallet_estado UUID;
    v_vc_emision_resultado UUID;
    v_vc_emision_protocolo UUID;
    v_vc_item_estado UUID;
    v_vc_item_tipo UUID;
BEGIN

    -- chk_pra_status [bauth.privilege_resource_atom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.recurso.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_pra_status", "columns": ["bauth.privilege_resource_atom.status"]}$j$)
    RETURNING item_id INTO v_priv_recurso_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_recurso_estado, 'priv.recurso.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_priv_recurso_estado, 'priv.recurso.estado.DEPRECATED', $j${"es": "DEPRECATED", "en": "DEPRECATED"}$j$, 1, true, 20, $j${"value": "DEPRECATED"}$j$),
        (v_priv_recurso_estado, 'priv.recurso.estado.INACTIVE', $j${"es": "INACTIVE", "en": "INACTIVE"}$j$, 1, true, 30, $j${"value": "INACTIVE"}$j$);

    -- chk_pra_tenant_scope [bauth.privilege_resource_atom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.recurso.alcance_tenant', $j${"es": "Alcance de tenant", "en": "Tenant Scope"}$j$, 0, false, $j${"constraint": "chk_pra_tenant_scope", "columns": ["bauth.privilege_resource_atom.tenant_scope"]}$j$)
    RETURNING item_id INTO v_priv_recurso_alcance_tenant;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_recurso_alcance_tenant, 'priv.recurso.alcance_tenant.GLOBAL', $j${"es": "GLOBAL", "en": "GLOBAL"}$j$, 1, true, 10, $j${"value": "GLOBAL"}$j$),
        (v_priv_recurso_alcance_tenant, 'priv.recurso.alcance_tenant.TENANT_SPECIFIC', $j${"es": "TENANT_SPECIFIC", "en": "TENANT_SPECIFIC"}$j$, 1, true, 20, $j${"value": "TENANT_SPECIFIC"}$j$);

    -- chk_pra_tipo_protocolo [bauth.privilege_resource_atom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.recurso.tipo_protocolo', $j${"es": "Tipo de protocolo", "en": "Protocol Type"}$j$, 0, false, $j${"constraint": "chk_pra_tipo_protocolo", "columns": ["bauth.privilege_resource_atom.protocol_type"]}$j$)
    RETURNING item_id INTO v_priv_recurso_tipo_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_recurso_tipo_protocolo, 'priv.recurso.tipo_protocolo.GRPC', $j${"es": "GRPC", "en": "GRPC"}$j$, 1, true, 10, $j${"value": "GRPC"}$j$),
        (v_priv_recurso_tipo_protocolo, 'priv.recurso.tipo_protocolo.HTTP_EXT', $j${"es": "HTTP_EXT", "en": "HTTP_EXT"}$j$, 1, true, 20, $j${"value": "HTTP_EXT"}$j$),
        (v_priv_recurso_tipo_protocolo, 'priv.recurso.tipo_protocolo.JSON_RPC', $j${"es": "JSON_RPC", "en": "JSON_RPC"}$j$, 1, true, 30, $j${"value": "JSON_RPC"}$j$),
        (v_priv_recurso_tipo_protocolo, 'priv.recurso.tipo_protocolo.UNIX_SOCKET', $j${"es": "UNIX_SOCKET", "en": "UNIX_SOCKET"}$j$, 1, true, 40, $j${"value": "UNIX_SOCKET"}$j$),
        (v_priv_recurso_tipo_protocolo, 'priv.recurso.tipo_protocolo.WS_RPC', $j${"es": "WS_RPC", "en": "WS_RPC"}$j$, 1, true, 50, $j${"value": "WS_RPC"}$j$);

    -- chk_pvc_conflict_type [bauth.privilege_verb_conflict]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('priv.verbo_conflicto.tipo_conflicto', $j${"es": "Tipo de conflicto", "en": "Conflict Type"}$j$, 0, false, $j${"constraint": "chk_pvc_conflict_type", "columns": ["bauth.privilege_verb_conflict.conflict_type"]}$j$)
    RETURNING item_id INTO v_priv_verbo_conflicto_tipo_conflicto;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_priv_verbo_conflicto_tipo_conflicto, 'priv.verbo_conflicto.tipo_conflicto.AFFINITY', $j${"es": "AFFINITY", "en": "AFFINITY"}$j$, 1, true, 10, $j${"value": "AFFINITY"}$j$),
        (v_priv_verbo_conflicto_tipo_conflicto, 'priv.verbo_conflicto.tipo_conflicto.DYNAMIC_SOD', $j${"es": "DYNAMIC_SOD", "en": "DYNAMIC_SOD"}$j$, 1, true, 20, $j${"value": "DYNAMIC_SOD"}$j$),
        (v_priv_verbo_conflicto_tipo_conflicto, 'priv.verbo_conflicto.tipo_conflicto.STATIC_SOD', $j${"es": "STATIC_SOD", "en": "STATIC_SOD"}$j$, 1, true, 30, $j${"value": "STATIC_SOD"}$j$);

    -- chk_scel_event_type [bauth.ses_caep_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ses.caep.tipo_evento', $j${"es": "Tipo de evento", "en": "Event Type"}$j$, 0, false, $j${"constraint": "chk_scel_event_type", "columns": ["bauth.ses_caep_event_log.event_type", "bauth.ses_risk_policy.trigger_event"]}$j$)
    RETURNING item_id INTO v_ses_caep_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.assurance-level-change', $j${"es": "assurance-level-change", "en": "assurance-level-change"}$j$, 1, true, 10, $j${"value": "assurance-level-change"}$j$),
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.credential-change', $j${"es": "credential-change", "en": "credential-change"}$j$, 1, true, 20, $j${"value": "credential-change"}$j$),
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.device-compliance-change', $j${"es": "device-compliance-change", "en": "device-compliance-change"}$j$, 1, true, 30, $j${"value": "device-compliance-change"}$j$),
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.risk-level-change', $j${"es": "risk-level-change", "en": "risk-level-change"}$j$, 1, true, 40, $j${"value": "risk-level-change"}$j$),
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.session-revoked', $j${"es": "session-revoked", "en": "session-revoked"}$j$, 1, true, 50, $j${"value": "session-revoked"}$j$),
        (v_ses_caep_tipo_evento, 'ses.caep.tipo_evento.token-claims-change', $j${"es": "token-claims-change", "en": "token-claims-change"}$j$, 1, true, 60, $j${"value": "token-claims-change"}$j$);

    -- chk_scel_subject_type [bauth.ses_caep_event_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ses.caep.tipo_sujeto', $j${"es": "Tipo de sujeto", "en": "Subject Type"}$j$, 0, false, $j${"constraint": "chk_scel_subject_type", "columns": ["bauth.ses_caep_event_log.subject_type"]}$j$)
    RETURNING item_id INTO v_ses_caep_tipo_sujeto;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ses_caep_tipo_sujeto, 'ses.caep.tipo_sujeto.device', $j${"es": "device", "en": "device"}$j$, 1, true, 10, $j${"value": "device"}$j$),
        (v_ses_caep_tipo_sujeto, 'ses.caep.tipo_sujeto.oauth_client', $j${"es": "oauth_client", "en": "oauth_client"}$j$, 1, true, 20, $j${"value": "oauth_client"}$j$),
        (v_ses_caep_tipo_sujeto, 'ses.caep.tipo_sujeto.session', $j${"es": "session", "en": "session"}$j$, 1, true, 30, $j${"value": "session"}$j$),
        (v_ses_caep_tipo_sujeto, 'ses.caep.tipo_sujeto.token', $j${"es": "token", "en": "token"}$j$, 1, true, 40, $j${"value": "token"}$j$),
        (v_ses_caep_tipo_sujeto, 'ses.caep.tipo_sujeto.user', $j${"es": "user", "en": "user"}$j$, 1, true, 50, $j${"value": "user"}$j$);

    -- chk_ssl_reason [bauth.ses_session_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ses.sesion.motivo_fin', $j${"es": "Motivo de terminación", "en": "Termination Reason"}$j$, 0, false, $j${"constraint": "chk_ssl_reason", "columns": ["bauth.ses_session_log.termination_reason"]}$j$)
    RETURNING item_id INTO v_ses_sesion_motivo_fin;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ses_sesion_motivo_fin, 'ses.sesion.motivo_fin.ADMIN_REVOKE', $j${"es": "ADMIN_REVOKE", "en": "ADMIN_REVOKE"}$j$, 1, true, 10, $j${"value": "ADMIN_REVOKE"}$j$),
        (v_ses_sesion_motivo_fin, 'ses.sesion.motivo_fin.CAEP_REVOKE', $j${"es": "CAEP_REVOKE", "en": "CAEP_REVOKE"}$j$, 1, true, 20, $j${"value": "CAEP_REVOKE"}$j$),
        (v_ses_sesion_motivo_fin, 'ses.sesion.motivo_fin.EXPIRY', $j${"es": "EXPIRY", "en": "EXPIRY"}$j$, 1, true, 30, $j${"value": "EXPIRY"}$j$),
        (v_ses_sesion_motivo_fin, 'ses.sesion.motivo_fin.LOGOUT', $j${"es": "LOGOUT", "en": "LOGOUT"}$j$, 1, true, 40, $j${"value": "LOGOUT"}$j$),
        (v_ses_sesion_motivo_fin, 'ses.sesion.motivo_fin.TIMEOUT', $j${"es": "TIMEOUT", "en": "TIMEOUT"}$j$, 1, true, 50, $j${"value": "TIMEOUT"}$j$);

    -- chk_sss_status [bauth.ses_ssf_stream]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('ses.ssf.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_sss_status", "columns": ["bauth.ses_ssf_stream.status"]}$j$)
    RETURNING item_id INTO v_ses_ssf_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_ses_ssf_estado, 'ses.ssf.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_ses_ssf_estado, 'ses.ssf.estado.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 20, $j${"value": "ERROR"}$j$),
        (v_ses_ssf_estado, 'ses.ssf.estado.PAUSED', $j${"es": "PAUSED", "en": "PAUSED"}$j$, 1, true, 30, $j${"value": "PAUSED"}$j$),
        (v_ses_ssf_estado, 'ses.ssf.estado.TERMINATED', $j${"es": "TERMINATED", "en": "TERMINATED"}$j$, 1, true, 40, $j${"value": "TERMINATED"}$j$);

    -- chk_sal_event [bauth.sig_adsib_lifecycle]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.adsib_ciclo.event', $j${"es": "Tipo de evento", "en": "Event"}$j$, 0, false, $j${"constraint": "chk_sal_event", "columns": ["bauth.sig_adsib_lifecycle.event"]}$j$)
    RETURNING item_id INTO v_sig_adsib_ciclo_event;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.ACTIVATED', $j${"es": "ACTIVATED", "en": "ACTIVATED"}$j$, 1, true, 10, $j${"value": "ACTIVATED"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.ALERT_15D', $j${"es": "ALERT_15D", "en": "ALERT_15D"}$j$, 1, true, 20, $j${"value": "ALERT_15D"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.ALERT_30D', $j${"es": "ALERT_30D", "en": "ALERT_30D"}$j$, 1, true, 30, $j${"value": "ALERT_30D"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.ALERT_7D', $j${"es": "ALERT_7D", "en": "ALERT_7D"}$j$, 1, true, 40, $j${"value": "ALERT_7D"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 50, $j${"value": "EXPIRED"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.ISSUED', $j${"es": "ISSUED", "en": "ISSUED"}$j$, 1, true, 60, $j${"value": "ISSUED"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.REISSUED', $j${"es": "REISSUED", "en": "REISSUED"}$j$, 1, true, 70, $j${"value": "REISSUED"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.RENEWAL_CSR', $j${"es": "RENEWAL_CSR", "en": "RENEWAL_CSR"}$j$, 1, true, 80, $j${"value": "RENEWAL_CSR"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.RENEWED', $j${"es": "RENEWED", "en": "RENEWED"}$j$, 1, true, 90, $j${"value": "RENEWED"}$j$),
        (v_sig_adsib_ciclo_event, 'sig.adsib_ciclo.event.REVOKED_BY_CA', $j${"es": "REVOKED_BY_CA", "en": "REVOKED_BY_CA"}$j$, 1, true, 100, $j${"value": "REVOKED_BY_CA"}$j$);

    -- chk_sc_adsib [bauth.sig_certificate]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.certificado.tipo_adsib', $j${"es": "Tipo ADSIB", "en": "Adsib Type"}$j$, 0, false, $j${"constraint": "chk_sc_adsib", "columns": ["bauth.sig_certificate.adsib_type"]}$j$)
    RETURNING item_id INTO v_sig_certificado_tipo_adsib;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_certificado_tipo_adsib, 'sig.certificado.tipo_adsib.FIRMA_AUTOMATICA', $j${"es": "FIRMA_AUTOMATICA", "en": "FIRMA_AUTOMATICA"}$j$, 1, true, 10, $j${"value": "FIRMA_AUTOMATICA"}$j$),
        (v_sig_certificado_tipo_adsib, 'sig.certificado.tipo_adsib.PERSONA_JURIDICA', $j${"es": "PERSONA_JURIDICA", "en": "PERSONA_JURIDICA"}$j$, 1, true, 20, $j${"value": "PERSONA_JURIDICA"}$j$),
        (v_sig_certificado_tipo_adsib, 'sig.certificado.tipo_adsib.PERSONA_NATURAL', $j${"es": "PERSONA_NATURAL", "en": "PERSONA_NATURAL"}$j$, 1, true, 30, $j${"value": "PERSONA_NATURAL"}$j$);

    -- chk_sc_engine [bauth.sig_certificate]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.certificado.motor', $j${"es": "Motor", "en": "Engine"}$j$, 0, false, $j${"constraint": "chk_sc_engine", "columns": ["bauth.sig_certificate.engine"]}$j$)
    RETURNING item_id INTO v_sig_certificado_motor;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_certificado_motor, 'sig.certificado.motor.ENTERPRISE_PKI', $j${"es": "ENTERPRISE_PKI", "en": "ENTERPRISE_PKI"}$j$, 1, true, 10, $j${"value": "ENTERPRISE_PKI"}$j$),
        (v_sig_certificado_motor, 'sig.certificado.motor.EXTERNAL_ADSIB', $j${"es": "EXTERNAL_ADSIB", "en": "EXTERNAL_ADSIB"}$j$, 1, true, 20, $j${"value": "EXTERNAL_ADSIB"}$j$),
        (v_sig_certificado_motor, 'sig.certificado.motor.INTERNAL_VAULT', $j${"es": "INTERNAL_VAULT", "en": "INTERNAL_VAULT"}$j$, 1, true, 30, $j${"value": "INTERNAL_VAULT"}$j$);

    -- chk_scrl_engine [bauth.sig_crl]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.crl.motor', $j${"es": "Motor", "en": "Engine"}$j$, 0, false, $j${"constraint": "chk_scrl_engine", "columns": ["bauth.sig_crl.engine", "bauth.sig_key.engine", "bauth.sig_operation_log.engine"]}$j$)
    RETURNING item_id INTO v_sig_crl_motor;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_crl_motor, 'sig.crl.motor.EXTERNAL_ADSIB', $j${"es": "EXTERNAL_ADSIB", "en": "EXTERNAL_ADSIB"}$j$, 1, true, 10, $j${"value": "EXTERNAL_ADSIB"}$j$),
        (v_sig_crl_motor, 'sig.crl.motor.INTERNAL_VAULT', $j${"es": "INTERNAL_VAULT", "en": "INTERNAL_VAULT"}$j$, 1, true, 20, $j${"value": "INTERNAL_VAULT"}$j$);

    -- chk_sdp_eng [bauth.sig_document_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.doc_politica.engine.required', $j${"es": "Motor de firma requerido", "en": "Engine Required"}$j$, 0, false, $j${"constraint": "chk_sdp_eng", "columns": ["bauth.sig_document_policy.engine_required"]}$j$)
    RETURNING item_id INTO v_sig_doc_politica_engine_required;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_doc_politica_engine_required, 'sig.doc_politica.engine.required.BOTH', $j${"es": "BOTH", "en": "BOTH"}$j$, 1, true, 10, $j${"value": "BOTH"}$j$),
        (v_sig_doc_politica_engine_required, 'sig.doc_politica.engine.required.EXTERNAL_ADSIB', $j${"es": "EXTERNAL_ADSIB", "en": "EXTERNAL_ADSIB"}$j$, 1, true, 20, $j${"value": "EXTERNAL_ADSIB"}$j$),
        (v_sig_doc_politica_engine_required, 'sig.doc_politica.engine.required.INTERNAL_VAULT', $j${"es": "INTERNAL_VAULT", "en": "INTERNAL_VAULT"}$j$, 1, true, 30, $j${"value": "INTERNAL_VAULT"}$j$);

    -- chk_sdp_ext [bauth.sig_document_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.doc_politica.external.profile', $j${"es": "Perfil de firma externo", "en": "External Profile"}$j$, 0, false, $j${"constraint": "chk_sdp_ext", "columns": ["bauth.sig_document_policy.external_profile"]}$j$)
    RETURNING item_id INTO v_sig_doc_politica_external_profile;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_doc_politica_external_profile, 'sig.doc_politica.external.profile.EXT-B', $j${"es": "EXT-B", "en": "EXT-B"}$j$, 1, true, 10, $j${"value": "EXT-B"}$j$),
        (v_sig_doc_politica_external_profile, 'sig.doc_politica.external.profile.EXT-LT', $j${"es": "EXT-LT", "en": "EXT-LT"}$j$, 1, true, 20, $j${"value": "EXT-LT"}$j$),
        (v_sig_doc_politica_external_profile, 'sig.doc_politica.external.profile.EXT-LTA', $j${"es": "EXT-LTA", "en": "EXT-LTA"}$j$, 1, true, 30, $j${"value": "EXT-LTA"}$j$),
        (v_sig_doc_politica_external_profile, 'sig.doc_politica.external.profile.EXT-T', $j${"es": "EXT-T", "en": "EXT-T"}$j$, 1, true, 40, $j${"value": "EXT-T"}$j$),
        (v_sig_doc_politica_external_profile, 'sig.doc_politica.external.profile.XAdES-BES', $j${"es": "XAdES-BES", "en": "XAdES-BES"}$j$, 1, true, 50, $j${"value": "XAdES-BES"}$j$);

    -- chk_sdp_int [bauth.sig_document_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.doc_politica.internal.profile', $j${"es": "Perfil de firma interno", "en": "Internal Profile"}$j$, 0, false, $j${"constraint": "chk_sdp_int", "columns": ["bauth.sig_document_policy.internal_profile"]}$j$)
    RETURNING item_id INTO v_sig_doc_politica_internal_profile;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_doc_politica_internal_profile, 'sig.doc_politica.internal.profile.INT-B', $j${"es": "INT-B", "en": "INT-B"}$j$, 1, true, 10, $j${"value": "INT-B"}$j$),
        (v_sig_doc_politica_internal_profile, 'sig.doc_politica.internal.profile.INT-LT', $j${"es": "INT-LT", "en": "INT-LT"}$j$, 1, true, 20, $j${"value": "INT-LT"}$j$),
        (v_sig_doc_politica_internal_profile, 'sig.doc_politica.internal.profile.INT-T', $j${"es": "INT-T", "en": "INT-T"}$j$, 1, true, 30, $j${"value": "INT-T"}$j$),
        (v_sig_doc_politica_internal_profile, 'sig.doc_politica.internal.profile.JWS', $j${"es": "JWS", "en": "JWS"}$j$, 1, true, 40, $j${"value": "JWS"}$j$);

    -- chk_sk_purpose [bauth.sig_key]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.llave.purpose', $j${"es": "Propósito de la llave", "en": "Purpose"}$j$, 0, false, $j${"constraint": "chk_sk_purpose", "columns": ["bauth.sig_key.purpose"]}$j$)
    RETURNING item_id INTO v_sig_llave_purpose;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_llave_purpose, 'sig.llave.purpose.ADSIB_BILLING', $j${"es": "ADSIB_BILLING", "en": "ADSIB_BILLING"}$j$, 1, true, 10, $j${"value": "ADSIB_BILLING"}$j$),
        (v_sig_llave_purpose, 'sig.llave.purpose.ADSIB_CONTRACTS', $j${"es": "ADSIB_CONTRACTS", "en": "ADSIB_CONTRACTS"}$j$, 1, true, 20, $j${"value": "ADSIB_CONTRACTS"}$j$),
        (v_sig_llave_purpose, 'sig.llave.purpose.CODE_SIGNING', $j${"es": "CODE_SIGNING", "en": "CODE_SIGNING"}$j$, 1, true, 30, $j${"value": "CODE_SIGNING"}$j$),
        (v_sig_llave_purpose, 'sig.llave.purpose.DOCUMENT_SIGNING', $j${"es": "DOCUMENT_SIGNING", "en": "DOCUMENT_SIGNING"}$j$, 1, true, 40, $j${"value": "DOCUMENT_SIGNING"}$j$),
        (v_sig_llave_purpose, 'sig.llave.purpose.JWT_SIGNING', $j${"es": "JWT_SIGNING", "en": "JWT_SIGNING"}$j$, 1, true, 50, $j${"value": "JWT_SIGNING"}$j$),
        (v_sig_llave_purpose, 'sig.llave.purpose.TLS_CLIENT', $j${"es": "TLS_CLIENT", "en": "TLS_CLIENT"}$j$, 1, true, 60, $j${"value": "TLS_CLIENT"}$j$);

    -- chk_sk_status [bauth.sig_key]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.llave.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_sk_status", "columns": ["bauth.sig_key.status"]}$j$)
    RETURNING item_id INTO v_sig_llave_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_llave_estado, 'sig.llave.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_sig_llave_estado, 'sig.llave.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 20, $j${"value": "REVOKED"}$j$),
        (v_sig_llave_estado, 'sig.llave.estado.ROTATING', $j${"es": "ROTATING", "en": "ROTATING"}$j$, 1, true, 30, $j${"value": "ROTATING"}$j$),
        (v_sig_llave_estado, 'sig.llave.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$);

    -- chk_sol_outcome [bauth.sig_operation_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.operacion.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "chk_sol_outcome", "columns": ["bauth.sig_operation_log.outcome"]}$j$)
    RETURNING item_id INTO v_sig_operacion_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_operacion_resultado, 'sig.operacion.resultado.CERT_EXPIRED', $j${"es": "CERT_EXPIRED", "en": "CERT_EXPIRED"}$j$, 1, true, 10, $j${"value": "CERT_EXPIRED"}$j$),
        (v_sig_operacion_resultado, 'sig.operacion.resultado.CERT_REVOKED', $j${"es": "CERT_REVOKED", "en": "CERT_REVOKED"}$j$, 1, true, 20, $j${"value": "CERT_REVOKED"}$j$),
        (v_sig_operacion_resultado, 'sig.operacion.resultado.FAILURE', $j${"es": "FAILURE", "en": "FAILURE"}$j$, 1, true, 30, $j${"value": "FAILURE"}$j$),
        (v_sig_operacion_resultado, 'sig.operacion.resultado.SUCCESS', $j${"es": "SUCCESS", "en": "SUCCESS"}$j$, 1, true, 40, $j${"value": "SUCCESS"}$j$);

    -- chk_sol_stype [bauth.sig_operation_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('sig.operacion.tipo_firmante', $j${"es": "Tipo de firmante", "en": "Signer Type"}$j$, 0, false, $j${"constraint": "chk_sol_stype", "columns": ["bauth.sig_operation_log.signer_type"]}$j$)
    RETURNING item_id INTO v_sig_operacion_tipo_firmante;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_sig_operacion_tipo_firmante, 'sig.operacion.tipo_firmante.DAEMON', $j${"es": "DAEMON", "en": "DAEMON"}$j$, 1, true, 10, $j${"value": "DAEMON"}$j$),
        (v_sig_operacion_tipo_firmante, 'sig.operacion.tipo_firmante.HUMAN', $j${"es": "HUMAN", "en": "HUMAN"}$j$, 1, true, 20, $j${"value": "HUMAN"}$j$),
        (v_sig_operacion_tipo_firmante, 'sig.operacion.tipo_firmante.NHI', $j${"es": "NHI", "en": "NHI"}$j$, 1, true, 30, $j${"value": "NHI"}$j$);

    -- chk_w_backup [bauth.wallet]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.wallet.metodo_respaldo', $j${"es": "Método de respaldo", "en": "Backup Method"}$j$, 0, false, $j${"constraint": "chk_w_backup", "columns": ["bauth.wallet.backup_method"]}$j$)
    RETURNING item_id INTO v_vc_wallet_metodo_respaldo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_wallet_metodo_respaldo, 'vc.wallet.metodo_respaldo.ENCRYPTED_CLOUD', $j${"es": "ENCRYPTED_CLOUD", "en": "ENCRYPTED_CLOUD"}$j$, 1, true, 10, $j${"value": "ENCRYPTED_CLOUD"}$j$),
        (v_vc_wallet_metodo_respaldo, 'vc.wallet.metodo_respaldo.NONE', $j${"es": "NONE", "en": "NONE"}$j$, 1, true, 20, $j${"value": "NONE"}$j$);

    -- chk_w_status [bauth.wallet]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.wallet.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_w_status", "columns": ["bauth.wallet.status"]}$j$)
    RETURNING item_id INTO v_vc_wallet_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_wallet_estado, 'vc.wallet.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_vc_wallet_estado, 'vc.wallet.estado.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_vc_wallet_estado, 'vc.wallet.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 30, $j${"value": "REVOKED"}$j$),
        (v_vc_wallet_estado, 'vc.wallet.estado.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 40, $j${"value": "SUSPENDED"}$j$);

    -- chk_wil_outcome [bauth.wallet_issuance_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.emision.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "chk_wil_outcome", "columns": ["bauth.wallet_issuance_log.outcome"]}$j$)
    RETURNING item_id INTO v_vc_emision_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_emision_resultado, 'vc.emision.resultado.ISSUED', $j${"es": "ISSUED", "en": "ISSUED"}$j$, 1, true, 10, $j${"value": "ISSUED"}$j$),
        (v_vc_emision_resultado, 'vc.emision.resultado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 20, $j${"value": "PENDING"}$j$),
        (v_vc_emision_resultado, 'vc.emision.resultado.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 30, $j${"value": "REJECTED"}$j$);

    -- chk_wil_proto [bauth.wallet_issuance_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.emision.protocolo', $j${"es": "Protocolo", "en": "Protocol"}$j$, 0, false, $j${"constraint": "chk_wil_proto", "columns": ["bauth.wallet_issuance_log.protocol"]}$j$)
    RETURNING item_id INTO v_vc_emision_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_emision_protocolo, 'vc.emision.protocolo.DIRECT_ISSUE', $j${"es": "DIRECT_ISSUE", "en": "DIRECT_ISSUE"}$j$, 1, true, 10, $j${"value": "DIRECT_ISSUE"}$j$),
        (v_vc_emision_protocolo, 'vc.emision.protocolo.IMPORTED', $j${"es": "IMPORTED", "en": "IMPORTED"}$j$, 1, true, 20, $j${"value": "IMPORTED"}$j$),
        (v_vc_emision_protocolo, 'vc.emision.protocolo.OPENID4VCI', $j${"es": "OPENID4VCI", "en": "OPENID4VCI"}$j$, 1, true, 30, $j${"value": "OPENID4VCI"}$j$);

    -- chk_wi_status [bauth.wallet_item]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.item.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_wi_status", "columns": ["bauth.wallet_item.status"]}$j$)
    RETURNING item_id INTO v_vc_item_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_item_estado, 'vc.item.estado.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_vc_item_estado, 'vc.item.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 20, $j${"value": "EXPIRED"}$j$),
        (v_vc_item_estado, 'vc.item.estado.HIDDEN', $j${"es": "HIDDEN", "en": "HIDDEN"}$j$, 1, true, 30, $j${"value": "HIDDEN"}$j$),
        (v_vc_item_estado, 'vc.item.estado.REVOKED', $j${"es": "REVOKED", "en": "REVOKED"}$j$, 1, true, 40, $j${"value": "REVOKED"}$j$);

    -- chk_wi_type [bauth.wallet_item]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.item.tipo', $j${"es": "Tipo", "en": "Type"}$j$, 0, false, $j${"constraint": "chk_wi_type", "columns": ["bauth.wallet_item.type"]}$j$)
    RETURNING item_id INTO v_vc_item_tipo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_item_tipo, 'vc.item.tipo.DID_DOC', $j${"es": "DID_DOC", "en": "DID_DOC"}$j$, 1, true, 10, $j${"value": "DID_DOC"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.FIDO2', $j${"es": "FIDO2", "en": "FIDO2"}$j$, 1, true, 20, $j${"value": "FIDO2"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.LICENSE', $j${"es": "LICENSE", "en": "LICENSE"}$j$, 1, true, 30, $j${"value": "LICENSE"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.NATIONAL_ID', $j${"es": "NATIONAL_ID", "en": "NATIONAL_ID"}$j$, 1, true, 40, $j${"value": "NATIONAL_ID"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.PHYSICAL_PASS', $j${"es": "PHYSICAL_PASS", "en": "PHYSICAL_PASS"}$j$, 1, true, 50, $j${"value": "PHYSICAL_PASS"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.SIG_CERT', $j${"es": "SIG_CERT", "en": "SIG_CERT"}$j$, 1, true, 60, $j${"value": "SIG_CERT"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.VC', $j${"es": "VC", "en": "VC"}$j$, 1, true, 70, $j${"value": "VC"}$j$),
        (v_vc_item_tipo, 'vc.item.tipo.X509_CERT', $j${"es": "X509_CERT", "en": "X509_CERT"}$j$, 1, true, 80, $j${"value": "X509_CERT"}$j$);

END $$;

-- ── Bloque 10/11 ───────────────────────────────
DO $$
DECLARE
    v_vc_presentacion_resultado UUID;
    v_vc_presentacion_protocolo UUID;
    v_menu_atom_efecto_requerido UUID;
    v_bos_snapshot_alcance UUID;
    v_bos_tenant_politica_modo_politica UUID;
    v_bos_audit_operacion UUID;
    v_bos_audit_estado_anterior UUID;
    v_bos_emergencia_resultado_revision UUID;
    v_bos_emergencia_estado UUID;
    v_bos_transferencia_tipo_transferencia UUID;
    v_bos_ficha_evento_resultado UUID;
    v_bos_ficha_estado_backend UUID;
    v_bos_ficha_estado_estado UUID;
    v_bos_bootstrap_estado UUID;
    v_bos_saga_estado UUID;
    v_bos_saga_tipo_saga UUID;
    v_bos_inventario_cert_tipo_cert UUID;
    v_bos_inventario_cert_motor_emisor UUID;
    v_bos_inventario_cert_algoritmo_llave UUID;
    v_bos_inventario_cert_estado UUID;
    v_bos_evento_seg_severidad UUID;
    v_bos_evento_seg_fuente UUID;
    v_bos_evento_seg_tipo_evento UUID;
    v_bos_puerto_tipo_activo UUID;
    v_bos_puerto_tipo_puerto UUID;
BEGIN

    -- chk_wpl_outcome [bauth.wallet_presentation_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.presentacion.resultado', $j${"es": "Resultado", "en": "Outcome"}$j$, 0, false, $j${"constraint": "chk_wpl_outcome", "columns": ["bauth.wallet_presentation_log.outcome", "bauth.wallet_presentation_log_2026_07.outcome", "bauth.wallet_presentation_log_2026_08.outcome"]}$j$)
    RETURNING item_id INTO v_vc_presentacion_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_presentacion_resultado, 'vc.presentacion.resultado.ACCEPTED', $j${"es": "ACCEPTED", "en": "ACCEPTED"}$j$, 1, true, 10, $j${"value": "ACCEPTED"}$j$),
        (v_vc_presentacion_resultado, 'vc.presentacion.resultado.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 20, $j${"value": "PARTIAL"}$j$),
        (v_vc_presentacion_resultado, 'vc.presentacion.resultado.REJECTED', $j${"es": "REJECTED", "en": "REJECTED"}$j$, 1, true, 30, $j${"value": "REJECTED"}$j$);

    -- chk_wpl_proto [bauth.wallet_presentation_log]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('vc.presentacion.protocolo', $j${"es": "Protocolo", "en": "Protocol"}$j$, 0, false, $j${"constraint": "chk_wpl_proto", "columns": ["bauth.wallet_presentation_log.protocol", "bauth.wallet_presentation_log_2026_07.protocol", "bauth.wallet_presentation_log_2026_08.protocol"]}$j$)
    RETURNING item_id INTO v_vc_presentacion_protocolo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_vc_presentacion_protocolo, 'vc.presentacion.protocolo.DIRECT_API', $j${"es": "DIRECT_API", "en": "DIRECT_API"}$j$, 1, true, 10, $j${"value": "DIRECT_API"}$j$),
        (v_vc_presentacion_protocolo, 'vc.presentacion.protocolo.OPENID4VP', $j${"es": "OPENID4VP", "en": "OPENID4VP"}$j$, 1, true, 20, $j${"value": "OPENID4VP"}$j$),
        (v_vc_presentacion_protocolo, 'vc.presentacion.protocolo.SAML_ASSERTION', $j${"es": "SAML_ASSERTION", "en": "SAML_ASSERTION"}$j$, 1, true, 30, $j${"value": "SAML_ASSERTION"}$j$);

    -- menu_item_atom_required_effect_check [bglobal.menu_item_atom]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('menu.atom.efecto_requerido', $j${"es": "Efecto requerido", "en": "Required Effect"}$j$, 0, false, $j${"constraint": "menu_item_atom_required_effect_check", "columns": ["bglobal.menu_item_atom.required_effect"]}$j$)
    RETURNING item_id INTO v_menu_atom_efecto_requerido;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_menu_atom_efecto_requerido, 'menu.atom.efecto_requerido.DENY', $j${"es": "DENY", "en": "DENY"}$j$, 1, true, 10, $j${"value": "DENY"}$j$),
        (v_menu_atom_efecto_requerido, 'menu.atom.efecto_requerido.PERMIT', $j${"es": "PERMIT", "en": "PERMIT"}$j$, 1, true, 20, $j${"value": "PERMIT"}$j$);

    -- chk_cap_sn_scope [bos.cap_sistema_snapshot]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.snapshot.alcance', $j${"es": "Alcance", "en": "Scope"}$j$, 0, false, $j${"constraint": "chk_cap_sn_scope", "columns": ["bos.cap_sistema_snapshot.scope", "bos.cap_sistema_snapshot_2026_07.scope"]}$j$)
    RETURNING item_id INTO v_bos_snapshot_alcance;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_snapshot_alcance, 'bos.snapshot.alcance.GLOBAL', $j${"es": "GLOBAL", "en": "GLOBAL"}$j$, 1, true, 10, $j${"value": "GLOBAL"}$j$),
        (v_bos_snapshot_alcance, 'bos.snapshot.alcance.TENANT', $j${"es": "TENANT", "en": "TENANT"}$j$, 1, true, 20, $j${"value": "TENANT"}$j$);

    -- chk_cap_tp_mode [bos.cap_tenant_policy]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.tenant_politica.modo_politica', $j${"es": "Modo de política", "en": "Policy Mode"}$j$, 0, false, $j${"constraint": "chk_cap_tp_mode", "columns": ["bos.cap_tenant_policy.policy_mode"]}$j$)
    RETURNING item_id INTO v_bos_tenant_politica_modo_politica;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_tenant_politica_modo_politica, 'bos.tenant_politica.modo_politica.autonomous', $j${"es": "autonomous", "en": "autonomous"}$j$, 1, true, 10, $j${"value": "autonomous"}$j$),
        (v_bos_tenant_politica_modo_politica, 'bos.tenant_politica.modo_politica.block_and_alert', $j${"es": "block_and_alert", "en": "block_and_alert"}$j$, 1, true, 20, $j${"value": "block_and_alert"}$j$),
        (v_bos_tenant_politica_modo_politica, 'bos.tenant_politica.modo_politica.emergency', $j${"es": "emergency", "en": "emergency"}$j$, 1, true, 30, $j${"value": "emergency"}$j$),
        (v_bos_tenant_politica_modo_politica, 'bos.tenant_politica.modo_politica.recommend', $j${"es": "recommend", "en": "recommend"}$j$, 1, true, 40, $j${"value": "recommend"}$j$);

    -- chk_ca_operation [bos.ctx_context_audit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.audit.operacion', $j${"es": "Operación", "en": "Operation"}$j$, 0, false, $j${"constraint": "chk_ca_operation", "columns": ["bos.ctx_context_audit.operation"]}$j$)
    RETURNING item_id INTO v_bos_audit_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_audit_operacion, 'bos.audit.operacion.ADMIN_OVERRIDE', $j${"es": "ADMIN_OVERRIDE", "en": "ADMIN_OVERRIDE"}$j$, 1, true, 10, $j${"value": "ADMIN_OVERRIDE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.COMPLIANCE_VIOLATION', $j${"es": "COMPLIANCE_VIOLATION", "en": "COMPLIANCE_VIOLATION"}$j$, 1, true, 20, $j${"value": "COMPLIANCE_VIOLATION"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.CONTEXT_TRANSFER', $j${"es": "CONTEXT_TRANSFER", "en": "CONTEXT_TRANSFER"}$j$, 1, true, 30, $j${"value": "CONTEXT_TRANSFER"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.DEVICE_HEARTBEAT', $j${"es": "DEVICE_HEARTBEAT", "en": "DEVICE_HEARTBEAT"}$j$, 1, true, 40, $j${"value": "DEVICE_HEARTBEAT"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.DEVICE_REGISTER', $j${"es": "DEVICE_REGISTER", "en": "DEVICE_REGISTER"}$j$, 1, true, 50, $j${"value": "DEVICE_REGISTER"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.EMERGENCY_ACTIVATE', $j${"es": "EMERGENCY_ACTIVATE", "en": "EMERGENCY_ACTIVATE"}$j$, 1, true, 60, $j${"value": "EMERGENCY_ACTIVATE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.EMERGENCY_APPROVE', $j${"es": "EMERGENCY_APPROVE", "en": "EMERGENCY_APPROVE"}$j$, 1, true, 70, $j${"value": "EMERGENCY_APPROVE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_ARCHIVE', $j${"es": "SESSION_ARCHIVE", "en": "SESSION_ARCHIVE"}$j$, 1, true, 80, $j${"value": "SESSION_ARCHIVE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_BLOCK', $j${"es": "SESSION_BLOCK", "en": "SESSION_BLOCK"}$j$, 1, true, 90, $j${"value": "SESSION_BLOCK"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_CREATE', $j${"es": "SESSION_CREATE", "en": "SESSION_CREATE"}$j$, 1, true, 100, $j${"value": "SESSION_CREATE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_EXPIRE', $j${"es": "SESSION_EXPIRE", "en": "SESSION_EXPIRE"}$j$, 1, true, 110, $j${"value": "SESSION_EXPIRE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_INVALIDATE', $j${"es": "SESSION_INVALIDATE", "en": "SESSION_INVALIDATE"}$j$, 1, true, 120, $j${"value": "SESSION_INVALIDATE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_PROMOTE', $j${"es": "SESSION_PROMOTE", "en": "SESSION_PROMOTE"}$j$, 1, true, 130, $j${"value": "SESSION_PROMOTE"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_SUSPEND', $j${"es": "SESSION_SUSPEND", "en": "SESSION_SUSPEND"}$j$, 1, true, 140, $j${"value": "SESSION_SUSPEND"}$j$),
        (v_bos_audit_operacion, 'bos.audit.operacion.SESSION_SWITCH', $j${"es": "SESSION_SWITCH", "en": "SESSION_SWITCH"}$j$, 1, true, 150, $j${"value": "SESSION_SWITCH"}$j$);

    -- chk_ca_state [bos.ctx_context_audit]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.audit.estado_anterior', $j${"es": "Estado anterior", "en": "Old State"}$j$, 0, false, $j${"constraint": "chk_ca_state", "columns": ["bos.ctx_context_audit.old_state", "bos.ctx_context_session.state", "bos.ctx_registered_device.state"]}$j$)
    RETURNING item_id INTO v_bos_audit_estado_anterior;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.ACTIVE', $j${"es": "ACTIVE", "en": "ACTIVE"}$j$, 1, true, 10, $j${"value": "ACTIVE"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.ARCHIVED', $j${"es": "ARCHIVED", "en": "ARCHIVED"}$j$, 1, true, 20, $j${"value": "ARCHIVED"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.BLOCKED', $j${"es": "BLOCKED", "en": "BLOCKED"}$j$, 1, true, 30, $j${"value": "BLOCKED"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 40, $j${"value": "EXPIRED"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.INVALIDATED', $j${"es": "INVALIDATED", "en": "INVALIDATED"}$j$, 1, true, 50, $j${"value": "INVALIDATED"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 60, $j${"value": "PENDING"}$j$),
        (v_bos_audit_estado_anterior, 'bos.audit.estado_anterior.SUSPENDED', $j${"es": "SUSPENDED", "en": "SUSPENDED"}$j$, 1, true, 70, $j${"value": "SUSPENDED"}$j$);

    -- chk_cem_review [bos.ctx_context_emergency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.emergencia.resultado_revision', $j${"es": "Resultado de revisión", "en": "Review Outcome"}$j$, 0, false, $j${"constraint": "chk_cem_review", "columns": ["bos.ctx_context_emergency.review_outcome"]}$j$)
    RETURNING item_id INTO v_bos_emergencia_resultado_revision;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_emergencia_resultado_revision, 'bos.emergencia.resultado_revision.JUSTIFIED', $j${"es": "JUSTIFIED", "en": "JUSTIFIED"}$j$, 1, true, 10, $j${"value": "JUSTIFIED"}$j$),
        (v_bos_emergencia_resultado_revision, 'bos.emergencia.resultado_revision.POLICY_VIOLATION', $j${"es": "POLICY_VIOLATION", "en": "POLICY_VIOLATION"}$j$, 1, true, 20, $j${"value": "POLICY_VIOLATION"}$j$),
        (v_bos_emergencia_resultado_revision, 'bos.emergencia.resultado_revision.UNJUSTIFIED', $j${"es": "UNJUSTIFIED", "en": "UNJUSTIFIED"}$j$, 1, true, 30, $j${"value": "UNJUSTIFIED"}$j$);

    -- chk_cem_state [bos.ctx_context_emergency]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.emergencia.estado', $j${"es": "Estado interno", "en": "State"}$j$, 0, false, $j${"constraint": "chk_cem_state", "columns": ["bos.ctx_context_emergency.state"]}$j$)
    RETURNING item_id INTO v_bos_emergencia_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_emergencia_estado, 'bos.emergencia.estado.ACTIVATED', $j${"es": "ACTIVATED", "en": "ACTIVATED"}$j$, 1, true, 10, $j${"value": "ACTIVATED"}$j$),
        (v_bos_emergencia_estado, 'bos.emergencia.estado.CLOSED', $j${"es": "CLOSED", "en": "CLOSED"}$j$, 1, true, 20, $j${"value": "CLOSED"}$j$),
        (v_bos_emergencia_estado, 'bos.emergencia.estado.EXPIRED', $j${"es": "EXPIRED", "en": "EXPIRED"}$j$, 1, true, 30, $j${"value": "EXPIRED"}$j$),
        (v_bos_emergencia_estado, 'bos.emergencia.estado.REVIEWED', $j${"es": "REVIEWED", "en": "REVIEWED"}$j$, 1, true, 40, $j${"value": "REVIEWED"}$j$),
        (v_bos_emergencia_estado, 'bos.emergencia.estado.SESSION_CREATED', $j${"es": "SESSION_CREATED", "en": "SESSION_CREATED"}$j$, 1, true, 50, $j${"value": "SESSION_CREATED"}$j$);

    -- chk_ct_type [bos.ctx_context_transfer]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.transferencia.tipo_transferencia', $j${"es": "Tipo de transferencia", "en": "Transfer Type"}$j$, 0, false, $j${"constraint": "chk_ct_type", "columns": ["bos.ctx_context_transfer.transfer_type"]}$j$)
    RETURNING item_id INTO v_bos_transferencia_tipo_transferencia;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_transferencia_tipo_transferencia, 'bos.transferencia.tipo_transferencia.ADMIN_TRANSFER', $j${"es": "ADMIN_TRANSFER", "en": "ADMIN_TRANSFER"}$j$, 1, true, 10, $j${"value": "ADMIN_TRANSFER"}$j$),
        (v_bos_transferencia_tipo_transferencia, 'bos.transferencia.tipo_transferencia.AUTO_CONTINUITY', $j${"es": "AUTO_CONTINUITY", "en": "AUTO_CONTINUITY"}$j$, 1, true, 20, $j${"value": "AUTO_CONTINUITY"}$j$),
        (v_bos_transferencia_tipo_transferencia, 'bos.transferencia.tipo_transferencia.BREAKGLASS', $j${"es": "BREAKGLASS", "en": "BREAKGLASS"}$j$, 1, true, 30, $j${"value": "BREAKGLASS"}$j$),
        (v_bos_transferencia_tipo_transferencia, 'bos.transferencia.tipo_transferencia.USER_INITIATED', $j${"es": "USER_INITIATED", "en": "USER_INITIATED"}$j$, 1, true, 40, $j${"value": "USER_INITIATED"}$j$);

    -- chk_fch_e_result [bos.fch_ficha_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.ficha_evento.resultado', $j${"es": "Resultado", "en": "Result"}$j$, 0, false, $j${"constraint": "chk_fch_e_result", "columns": ["bos.fch_ficha_event.result", "bos.ins_bootstrap_event.result"]}$j$)
    RETURNING item_id INTO v_bos_ficha_evento_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_ficha_evento_resultado, 'bos.ficha_evento.resultado.FAIL', $j${"es": "FAIL", "en": "FAIL"}$j$, 1, true, 10, $j${"value": "FAIL"}$j$),
        (v_bos_ficha_evento_resultado, 'bos.ficha_evento.resultado.OK', $j${"es": "OK", "en": "OK"}$j$, 1, true, 20, $j${"value": "OK"}$j$),
        (v_bos_ficha_evento_resultado, 'bos.ficha_evento.resultado.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 30, $j${"value": "PARTIAL"}$j$),
        (v_bos_ficha_evento_resultado, 'bos.ficha_evento.resultado.SKIPPED', $j${"es": "SKIPPED", "en": "SKIPPED"}$j$, 1, true, 40, $j${"value": "SKIPPED"}$j$);

    -- chk_fch_s_backend [bos.fch_ficha_state]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.ficha_estado.backend', $j${"es": "Backend de ejecución", "en": "Backend"}$j$, 0, false, $j${"constraint": "chk_fch_s_backend", "columns": ["bos.fch_ficha_state.backend"]}$j$)
    RETURNING item_id INTO v_bos_ficha_estado_backend;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_ficha_estado_backend, 'bos.ficha_estado.backend.bash', $j${"es": "bash", "en": "bash"}$j$, 1, true, 10, $j${"value": "bash"}$j$),
        (v_bos_ficha_estado_backend, 'bos.ficha_estado.backend.binary', $j${"es": "binary", "en": "binary"}$j$, 1, true, 20, $j${"value": "binary"}$j$),
        (v_bos_ficha_estado_backend, 'bos.ficha_estado.backend.k8s', $j${"es": "k8s", "en": "k8s"}$j$, 1, true, 30, $j${"value": "k8s"}$j$),
        (v_bos_ficha_estado_backend, 'bos.ficha_estado.backend.python', $j${"es": "python", "en": "python"}$j$, 1, true, 40, $j${"value": "python"}$j$);

    -- chk_fch_s_state [bos.fch_ficha_state]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.ficha_estado.estado', $j${"es": "Estado interno", "en": "State"}$j$, 0, false, $j${"constraint": "chk_fch_s_state", "columns": ["bos.fch_ficha_state.state"]}$j$)
    RETURNING item_id INTO v_bos_ficha_estado_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.CLEANUP', $j${"es": "CLEANUP", "en": "CLEANUP"}$j$, 1, true, 10, $j${"value": "CLEANUP"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.DEGRADED', $j${"es": "DEGRADED", "en": "DEGRADED"}$j$, 1, true, 20, $j${"value": "DEGRADED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.INSTALLED', $j${"es": "INSTALLED", "en": "INSTALLED"}$j$, 1, true, 30, $j${"value": "INSTALLED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.INSTALLING', $j${"es": "INSTALLING", "en": "INSTALLING"}$j$, 1, true, 40, $j${"value": "INSTALLING"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.INSTALL_FAILED', $j${"es": "INSTALL_FAILED", "en": "INSTALL_FAILED"}$j$, 1, true, 50, $j${"value": "INSTALL_FAILED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.LOGICAL_ERROR', $j${"es": "LOGICAL_ERROR", "en": "LOGICAL_ERROR"}$j$, 1, true, 60, $j${"value": "LOGICAL_ERROR"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.PAUSED', $j${"es": "PAUSED", "en": "PAUSED"}$j$, 1, true, 70, $j${"value": "PAUSED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 80, $j${"value": "PENDING"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.PHYSICAL_ERROR', $j${"es": "PHYSICAL_ERROR", "en": "PHYSICAL_ERROR"}$j$, 1, true, 90, $j${"value": "PHYSICAL_ERROR"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.READY', $j${"es": "READY", "en": "READY"}$j$, 1, true, 100, $j${"value": "READY"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.REPAIRING', $j${"es": "REPAIRING", "en": "REPAIRING"}$j$, 1, true, 110, $j${"value": "REPAIRING"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.ROLLBACK', $j${"es": "ROLLBACK", "en": "ROLLBACK"}$j$, 1, true, 120, $j${"value": "ROLLBACK"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UNINSTALLED', $j${"es": "UNINSTALLED", "en": "UNINSTALLED"}$j$, 1, true, 130, $j${"value": "UNINSTALLED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UNRECOVERABLE', $j${"es": "UNRECOVERABLE", "en": "UNRECOVERABLE"}$j$, 1, true, 140, $j${"value": "UNRECOVERABLE"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UPDATE_APPROVED', $j${"es": "UPDATE_APPROVED", "en": "UPDATE_APPROVED"}$j$, 1, true, 150, $j${"value": "UPDATE_APPROVED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UPDATE_AVAILABLE', $j${"es": "UPDATE_AVAILABLE", "en": "UPDATE_AVAILABLE"}$j$, 1, true, 160, $j${"value": "UPDATE_AVAILABLE"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UPDATE_FAILED', $j${"es": "UPDATE_FAILED", "en": "UPDATE_FAILED"}$j$, 1, true, 170, $j${"value": "UPDATE_FAILED"}$j$),
        (v_bos_ficha_estado_estado, 'bos.ficha_estado.estado.UPDATING', $j${"es": "UPDATING", "en": "UPDATING"}$j$, 1, true, 180, $j${"value": "UPDATING"}$j$);

    -- chk_ins_be_state [bos.ins_bootstrap_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.bootstrap.estado', $j${"es": "Estado interno", "en": "State"}$j$, 0, false, $j${"constraint": "chk_ins_be_state", "columns": ["bos.ins_bootstrap_event.state"]}$j$)
    RETURNING item_id INTO v_bos_bootstrap_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_bootstrap_estado, 'bos.bootstrap.estado.COMPLETED', $j${"es": "COMPLETED", "en": "COMPLETED"}$j$, 1, true, 10, $j${"value": "COMPLETED"}$j$),
        (v_bos_bootstrap_estado, 'bos.bootstrap.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 20, $j${"value": "FAILED"}$j$),
        (v_bos_bootstrap_estado, 'bos.bootstrap.estado.RETRYING', $j${"es": "RETRYING", "en": "RETRYING"}$j$, 1, true, 30, $j${"value": "RETRYING"}$j$),
        (v_bos_bootstrap_estado, 'bos.bootstrap.estado.SKIPPED', $j${"es": "SKIPPED", "en": "SKIPPED"}$j$, 1, true, 40, $j${"value": "SKIPPED"}$j$),
        (v_bos_bootstrap_estado, 'bos.bootstrap.estado.STARTED', $j${"es": "STARTED", "en": "STARTED"}$j$, 1, true, 50, $j${"value": "STARTED"}$j$);

    -- chk_ins_se_state [bos.ins_saga_execution]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.saga.estado', $j${"es": "Estado interno", "en": "State"}$j$, 0, false, $j${"constraint": "chk_ins_se_state", "columns": ["bos.ins_saga_execution.state"]}$j$)
    RETURNING item_id INTO v_bos_saga_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_saga_estado, 'bos.saga.estado.COMPENSATED', $j${"es": "COMPENSATED", "en": "COMPENSATED"}$j$, 1, true, 10, $j${"value": "COMPENSATED"}$j$),
        (v_bos_saga_estado, 'bos.saga.estado.COMPENSATING', $j${"es": "COMPENSATING", "en": "COMPENSATING"}$j$, 1, true, 20, $j${"value": "COMPENSATING"}$j$),
        (v_bos_saga_estado, 'bos.saga.estado.COMPLETED', $j${"es": "COMPLETED", "en": "COMPLETED"}$j$, 1, true, 30, $j${"value": "COMPLETED"}$j$),
        (v_bos_saga_estado, 'bos.saga.estado.FAILED', $j${"es": "FAILED", "en": "FAILED"}$j$, 1, true, 40, $j${"value": "FAILED"}$j$),
        (v_bos_saga_estado, 'bos.saga.estado.RUNNING', $j${"es": "RUNNING", "en": "RUNNING"}$j$, 1, true, 50, $j${"value": "RUNNING"}$j$);

    -- chk_ins_se_type [bos.ins_saga_execution]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.saga.tipo_saga', $j${"es": "Tipo de saga", "en": "Saga Type"}$j$, 0, false, $j${"constraint": "chk_ins_se_type", "columns": ["bos.ins_saga_execution.saga_type"]}$j$)
    RETURNING item_id INTO v_bos_saga_tipo_saga;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.deploy_tenant', $j${"es": "deploy_tenant", "en": "deploy_tenant"}$j$, 1, true, 10, $j${"value": "deploy_tenant"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.install', $j${"es": "install", "en": "install"}$j$, 1, true, 20, $j${"value": "install"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.remove', $j${"es": "remove", "en": "remove"}$j$, 1, true, 30, $j${"value": "remove"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.remove_tenant', $j${"es": "remove_tenant", "en": "remove_tenant"}$j$, 1, true, 40, $j${"value": "remove_tenant"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.repair', $j${"es": "repair", "en": "repair"}$j$, 1, true, 50, $j${"value": "repair"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.suspend_tenant', $j${"es": "suspend_tenant", "en": "suspend_tenant"}$j$, 1, true, 60, $j${"value": "suspend_tenant"}$j$),
        (v_bos_saga_tipo_saga, 'bos.saga.tipo_saga.update', $j${"es": "update", "en": "update"}$j$, 1, true, 70, $j${"value": "update"}$j$);

    -- chk_net_ci_cert_type [bos.net_cert_inventory]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.inventario_cert.tipo_cert', $j${"es": "Tipo de certificado", "en": "Cert Type"}$j$, 0, false, $j${"constraint": "chk_net_ci_cert_type", "columns": ["bos.net_cert_inventory.cert_type"]}$j$)
    RETURNING item_id INTO v_bos_inventario_cert_tipo_cert;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.ca_internal', $j${"es": "ca_internal", "en": "ca_internal"}$j$, 1, true, 10, $j${"value": "ca_internal"}$j$),
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.daemon_host', $j${"es": "daemon_host", "en": "daemon_host"}$j$, 1, true, 20, $j${"value": "daemon_host"}$j$),
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.external_wildcard', $j${"es": "external_wildcard", "en": "external_wildcard"}$j$, 1, true, 30, $j${"value": "external_wildcard"}$j$),
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.ficha_k8s', $j${"es": "ficha_k8s", "en": "ficha_k8s"}$j$, 1, true, 40, $j${"value": "ficha_k8s"}$j$),
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.kong_tls', $j${"es": "kong_tls", "en": "kong_tls"}$j$, 1, true, 50, $j${"value": "kong_tls"}$j$),
        (v_bos_inventario_cert_tipo_cert, 'bos.inventario_cert.tipo_cert.spiffe_svid', $j${"es": "spiffe_svid", "en": "spiffe_svid"}$j$, 1, true, 60, $j${"value": "spiffe_svid"}$j$);

    -- chk_net_ci_issuer_engine [bos.net_cert_inventory]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.inventario_cert.motor_emisor', $j${"es": "Motor emisor de certificado", "en": "Issuer Engine"}$j$, 0, false, $j${"constraint": "chk_net_ci_issuer_engine", "columns": ["bos.net_cert_inventory.issuer_engine"]}$j$)
    RETURNING item_id INTO v_bos_inventario_cert_motor_emisor;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_inventario_cert_motor_emisor, 'bos.inventario_cert.motor_emisor.acme_le', $j${"es": "acme_le", "en": "acme_le"}$j$, 1, true, 10, $j${"value": "acme_le"}$j$),
        (v_bos_inventario_cert_motor_emisor, 'bos.inventario_cert.motor_emisor.cert_manager', $j${"es": "cert_manager", "en": "cert_manager"}$j$, 1, true, 20, $j${"value": "cert_manager"}$j$),
        (v_bos_inventario_cert_motor_emisor, 'bos.inventario_cert.motor_emisor.manual', $j${"es": "manual", "en": "manual"}$j$, 1, true, 30, $j${"value": "manual"}$j$),
        (v_bos_inventario_cert_motor_emisor, 'bos.inventario_cert.motor_emisor.spire', $j${"es": "spire", "en": "spire"}$j$, 1, true, 40, $j${"value": "spire"}$j$),
        (v_bos_inventario_cert_motor_emisor, 'bos.inventario_cert.motor_emisor.vault_pki', $j${"es": "vault_pki", "en": "vault_pki"}$j$, 1, true, 50, $j${"value": "vault_pki"}$j$);

    -- chk_net_ci_key_algo [bos.net_cert_inventory]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.inventario_cert.algoritmo_llave', $j${"es": "Algoritmo de llave", "en": "Key Algorithm"}$j$, 0, false, $j${"constraint": "chk_net_ci_key_algo", "columns": ["bos.net_cert_inventory.key_algorithm"]}$j$)
    RETURNING item_id INTO v_bos_inventario_cert_algoritmo_llave;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_inventario_cert_algoritmo_llave, 'bos.inventario_cert.algoritmo_llave.ECDSA', $j${"es": "ECDSA", "en": "ECDSA"}$j$, 1, true, 10, $j${"value": "ECDSA"}$j$),
        (v_bos_inventario_cert_algoritmo_llave, 'bos.inventario_cert.algoritmo_llave.Ed25519', $j${"es": "Ed25519", "en": "Ed25519"}$j$, 1, true, 20, $j${"value": "Ed25519"}$j$),
        (v_bos_inventario_cert_algoritmo_llave, 'bos.inventario_cert.algoritmo_llave.RSA', $j${"es": "RSA", "en": "RSA"}$j$, 1, true, 30, $j${"value": "RSA"}$j$);

    -- chk_net_ci_status [bos.net_cert_inventory]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.inventario_cert.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_net_ci_status", "columns": ["bos.net_cert_inventory.status"]}$j$)
    RETURNING item_id INTO v_bos_inventario_cert_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_inventario_cert_estado, 'bos.inventario_cert.estado.active', $j${"es": "active", "en": "active"}$j$, 1, true, 10, $j${"value": "active"}$j$),
        (v_bos_inventario_cert_estado, 'bos.inventario_cert.estado.expired', $j${"es": "expired", "en": "expired"}$j$, 1, true, 20, $j${"value": "expired"}$j$),
        (v_bos_inventario_cert_estado, 'bos.inventario_cert.estado.expiring_soon', $j${"es": "expiring_soon", "en": "expiring_soon"}$j$, 1, true, 30, $j${"value": "expiring_soon"}$j$),
        (v_bos_inventario_cert_estado, 'bos.inventario_cert.estado.revoked', $j${"es": "revoked", "en": "revoked"}$j$, 1, true, 40, $j${"value": "revoked"}$j$),
        (v_bos_inventario_cert_estado, 'bos.inventario_cert.estado.superseded', $j${"es": "superseded", "en": "superseded"}$j$, 1, true, 50, $j${"value": "superseded"}$j$);

    -- chk_net_se_severity [bos.net_security_events]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.evento_seg.severidad', $j${"es": "Severidad", "en": "Severity"}$j$, 0, false, $j${"constraint": "chk_net_se_severity", "columns": ["bos.net_security_events.severity", "bos.net_security_events_default.severity"]}$j$)
    RETURNING item_id INTO v_bos_evento_seg_severidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_evento_seg_severidad, 'bos.evento_seg.severidad.critical', $j${"es": "critical", "en": "critical"}$j$, 1, true, 10, $j${"value": "critical"}$j$),
        (v_bos_evento_seg_severidad, 'bos.evento_seg.severidad.high', $j${"es": "high", "en": "high"}$j$, 1, true, 20, $j${"value": "high"}$j$),
        (v_bos_evento_seg_severidad, 'bos.evento_seg.severidad.info', $j${"es": "info", "en": "info"}$j$, 1, true, 30, $j${"value": "info"}$j$),
        (v_bos_evento_seg_severidad, 'bos.evento_seg.severidad.warn', $j${"es": "warn", "en": "warn"}$j$, 1, true, 40, $j${"value": "warn"}$j$);

    -- chk_net_se_source [bos.net_security_events]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.evento_seg.fuente', $j${"es": "Fuente", "en": "Source"}$j$, 0, false, $j${"constraint": "chk_net_se_source", "columns": ["bos.net_security_events.source", "bos.net_security_events_default.source"]}$j$)
    RETURNING item_id INTO v_bos_evento_seg_fuente;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.bos_daemon', $j${"es": "bos_daemon", "en": "bos_daemon"}$j$, 1, true, 10, $j${"value": "bos_daemon"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.certman', $j${"es": "certman", "en": "certman"}$j$, 1, true, 20, $j${"value": "certman"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.crowdsec', $j${"es": "crowdsec", "en": "crowdsec"}$j$, 1, true, 30, $j${"value": "crowdsec"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.fail2ban', $j${"es": "fail2ban", "en": "fail2ban"}$j$, 1, true, 40, $j${"value": "fail2ban"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.fwman', $j${"es": "fwman", "en": "fwman"}$j$, 1, true, 50, $j${"value": "fwman"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.ips', $j${"es": "ips", "en": "ips"}$j$, 1, true, 60, $j${"value": "ips"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.portman', $j${"es": "portman", "en": "portman"}$j$, 1, true, 70, $j${"value": "portman"}$j$),
        (v_bos_evento_seg_fuente, 'bos.evento_seg.fuente.psad', $j${"es": "psad", "en": "psad"}$j$, 1, true, 80, $j${"value": "psad"}$j$);

    -- chk_net_se_type [bos.net_security_events]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.evento_seg.tipo_evento', $j${"es": "Tipo de evento", "en": "Event Type"}$j$, 0, false, $j${"constraint": "chk_net_se_type", "columns": ["bos.net_security_events.event_type", "bos.net_security_events_default.event_type"]}$j$)
    RETURNING item_id INTO v_bos_evento_seg_tipo_evento;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.brute_force_detected', $j${"es": "brute_force_detected", "en": "brute_force_detected"}$j$, 1, true, 10, $j${"value": "brute_force_detected"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.cert_expiring', $j${"es": "cert_expiring", "en": "cert_expiring"}$j$, 1, true, 20, $j${"value": "cert_expiring"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.cert_issued', $j${"es": "cert_issued", "en": "cert_issued"}$j$, 1, true, 30, $j${"value": "cert_issued"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.cert_renewed', $j${"es": "cert_renewed", "en": "cert_renewed"}$j$, 1, true, 40, $j${"value": "cert_renewed"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.cert_revoked', $j${"es": "cert_revoked", "en": "cert_revoked"}$j$, 1, true, 50, $j${"value": "cert_revoked"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.crowdsec_ban', $j${"es": "crowdsec_ban", "en": "crowdsec_ban"}$j$, 1, true, 60, $j${"value": "crowdsec_ban"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.crowdsec_unban', $j${"es": "crowdsec_unban", "en": "crowdsec_unban"}$j$, 1, true, 70, $j${"value": "crowdsec_unban"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.ddos_detected', $j${"es": "ddos_detected", "en": "ddos_detected"}$j$, 1, true, 80, $j${"value": "ddos_detected"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.fail2ban_ban', $j${"es": "fail2ban_ban", "en": "fail2ban_ban"}$j$, 1, true, 90, $j${"value": "fail2ban_ban"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.fail2ban_unban', $j${"es": "fail2ban_unban", "en": "fail2ban_unban"}$j$, 1, true, 100, $j${"value": "fail2ban_unban"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.fw_drift_detected', $j${"es": "fw_drift_detected", "en": "fw_drift_detected"}$j$, 1, true, 110, $j${"value": "fw_drift_detected"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.fw_rule_added', $j${"es": "fw_rule_added", "en": "fw_rule_added"}$j$, 1, true, 120, $j${"value": "fw_rule_added"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.fw_rule_removed', $j${"es": "fw_rule_removed", "en": "fw_rule_removed"}$j$, 1, true, 130, $j${"value": "fw_rule_removed"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.ips_block', $j${"es": "ips_block", "en": "ips_block"}$j$, 1, true, 140, $j${"value": "ips_block"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.ips_unblock', $j${"es": "ips_unblock", "en": "ips_unblock"}$j$, 1, true, 150, $j${"value": "ips_unblock"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.netpol_synced', $j${"es": "netpol_synced", "en": "netpol_synced"}$j$, 1, true, 160, $j${"value": "netpol_synced"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.port_assigned', $j${"es": "port_assigned", "en": "port_assigned"}$j$, 1, true, 170, $j${"value": "port_assigned"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.port_conflict', $j${"es": "port_conflict", "en": "port_conflict"}$j$, 1, true, 180, $j${"value": "port_conflict"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.port_released', $j${"es": "port_released", "en": "port_released"}$j$, 1, true, 190, $j${"value": "port_released"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.port_scan_detected', $j${"es": "port_scan_detected", "en": "port_scan_detected"}$j$, 1, true, 200, $j${"value": "port_scan_detected"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.port_validated', $j${"es": "port_validated", "en": "port_validated"}$j$, 1, true, 210, $j${"value": "port_validated"}$j$),
        (v_bos_evento_seg_tipo_evento, 'bos.evento_seg.tipo_evento.replay_detected', $j${"es": "replay_detected", "en": "replay_detected"}$j$, 1, true, 220, $j${"value": "replay_detected"}$j$);

    -- chk_prt_pa_asset [bos.prt_port_assignment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.puerto.tipo_activo', $j${"es": "Tipo de activo de red", "en": "Asset Type"}$j$, 0, false, $j${"constraint": "chk_prt_pa_asset", "columns": ["bos.prt_port_assignment.asset_type"]}$j$)
    RETURNING item_id INTO v_bos_puerto_tipo_activo;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.daemon', $j${"es": "daemon", "en": "daemon"}$j$, 1, true, 10, $j${"value": "daemon"}$j$),
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.ficha', $j${"es": "ficha", "en": "ficha"}$j$, 1, true, 20, $j${"value": "ficha"}$j$),
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.k8s_node', $j${"es": "k8s_node", "en": "k8s_node"}$j$, 1, true, 30, $j${"value": "k8s_node"}$j$),
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.k8s_service', $j${"es": "k8s_service", "en": "k8s_service"}$j$, 1, true, 40, $j${"value": "k8s_service"}$j$),
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.kong_route', $j${"es": "kong_route", "en": "kong_route"}$j$, 1, true, 50, $j${"value": "kong_route"}$j$),
        (v_bos_puerto_tipo_activo, 'bos.puerto.tipo_activo.logical_server', $j${"es": "logical_server", "en": "logical_server"}$j$, 1, true, 60, $j${"value": "logical_server"}$j$);

    -- chk_prt_pa_port_type [bos.prt_port_assignment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.puerto.tipo_puerto', $j${"es": "Tipo de puerto", "en": "Port Type"}$j$, 0, false, $j${"constraint": "chk_prt_pa_port_type", "columns": ["bos.prt_port_assignment.port_type"]}$j$)
    RETURNING item_id INTO v_bos_puerto_tipo_puerto;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_puerto_tipo_puerto, 'bos.puerto.tipo_puerto.HOST_LOGICAL', $j${"es": "HOST_LOGICAL", "en": "HOST_LOGICAL"}$j$, 1, true, 10, $j${"value": "HOST_LOGICAL"}$j$),
        (v_bos_puerto_tipo_puerto, 'bos.puerto.tipo_puerto.HOST_PHYSICAL', $j${"es": "HOST_PHYSICAL", "en": "HOST_PHYSICAL"}$j$, 1, true, 20, $j${"value": "HOST_PHYSICAL"}$j$),
        (v_bos_puerto_tipo_puerto, 'bos.puerto.tipo_puerto.K8S_CLUSTER_IP', $j${"es": "K8S_CLUSTER_IP", "en": "K8S_CLUSTER_IP"}$j$, 1, true, 30, $j${"value": "K8S_CLUSTER_IP"}$j$),
        (v_bos_puerto_tipo_puerto, 'bos.puerto.tipo_puerto.K8S_LOAD_BALANCER', $j${"es": "K8S_LOAD_BALANCER", "en": "K8S_LOAD_BALANCER"}$j$, 1, true, 40, $j${"value": "K8S_LOAD_BALANCER"}$j$),
        (v_bos_puerto_tipo_puerto, 'bos.puerto.tipo_puerto.K8S_NODE_PORT', $j${"es": "K8S_NODE_PORT", "en": "K8S_NODE_PORT"}$j$, 1, true, 50, $j${"value": "K8S_NODE_PORT"}$j$);

END $$;

-- ── Bloque 11/11 ───────────────────────────────
DO $$
DECLARE
    v_bos_puerto_estado UUID;
    v_bos_puerto_transporte UUID;
    v_bos_release_channel UUID;
    v_bos_release_operacion UUID;
    v_bos_release_resultado UUID;
    v_bos_release_disparado_por UUID;
    v_bos_watchdog_accion_tomada UUID;
    v_bos_watchdog_capa_verificacion UUID;
    v_bos_watchdog_tipo_recurso UUID;
    v_bos_watchdog_resultado_accion UUID;
    v_bos_watchdog_severidad UUID;
BEGIN

    -- chk_prt_pa_status [bos.prt_port_assignment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.puerto.estado', $j${"es": "Estado", "en": "Status"}$j$, 0, false, $j${"constraint": "chk_prt_pa_status", "columns": ["bos.prt_port_assignment.status"]}$j$)
    RETURNING item_id INTO v_bos_puerto_estado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_puerto_estado, 'bos.puerto.estado.assigned', $j${"es": "assigned", "en": "assigned"}$j$, 1, true, 10, $j${"value": "assigned"}$j$),
        (v_bos_puerto_estado, 'bos.puerto.estado.conflict', $j${"es": "conflict", "en": "conflict"}$j$, 1, true, 20, $j${"value": "conflict"}$j$),
        (v_bos_puerto_estado, 'bos.puerto.estado.released', $j${"es": "released", "en": "released"}$j$, 1, true, 30, $j${"value": "released"}$j$),
        (v_bos_puerto_estado, 'bos.puerto.estado.revoked', $j${"es": "revoked", "en": "revoked"}$j$, 1, true, 40, $j${"value": "revoked"}$j$);

    -- chk_prt_pa_transport [bos.prt_port_assignment]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.puerto.transporte', $j${"es": "Protocolo de transporte", "en": "Transport"}$j$, 0, false, $j${"constraint": "chk_prt_pa_transport", "columns": ["bos.prt_port_assignment.transport"]}$j$)
    RETURNING item_id INTO v_bos_puerto_transporte;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_puerto_transporte, 'bos.puerto.transporte.DCCP', $j${"es": "DCCP", "en": "DCCP"}$j$, 1, true, 10, $j${"value": "DCCP"}$j$),
        (v_bos_puerto_transporte, 'bos.puerto.transporte.SCTP', $j${"es": "SCTP", "en": "SCTP"}$j$, 1, true, 20, $j${"value": "SCTP"}$j$),
        (v_bos_puerto_transporte, 'bos.puerto.transporte.TCP', $j${"es": "TCP", "en": "TCP"}$j$, 1, true, 30, $j${"value": "TCP"}$j$),
        (v_bos_puerto_transporte, 'bos.puerto.transporte.UDP', $j${"es": "UDP", "en": "UDP"}$j$, 1, true, 40, $j${"value": "UDP"}$j$);

    -- chk_rel_re_channel [bos.rel_release_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.release.channel', $j${"es": "Canal de liberación", "en": "Channel"}$j$, 0, false, $j${"constraint": "chk_rel_re_channel", "columns": ["bos.rel_release_event.channel", "bos.rel_release_manifest.channel"]}$j$)
    RETURNING item_id INTO v_bos_release_channel;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_release_channel, 'bos.release.channel.canary', $j${"es": "canary", "en": "canary"}$j$, 1, true, 10, $j${"value": "canary"}$j$),
        (v_bos_release_channel, 'bos.release.channel.early', $j${"es": "early", "en": "early"}$j$, 1, true, 20, $j${"value": "early"}$j$),
        (v_bos_release_channel, 'bos.release.channel.stable', $j${"es": "stable", "en": "stable"}$j$, 1, true, 30, $j${"value": "stable"}$j$);

    -- chk_rel_re_op [bos.rel_release_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.release.operacion', $j${"es": "Operación", "en": "Operation"}$j$, 0, false, $j${"constraint": "chk_rel_re_op", "columns": ["bos.rel_release_event.operation"]}$j$)
    RETURNING item_id INTO v_bos_release_operacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_release_operacion, 'bos.release.operacion.INSTALL', $j${"es": "INSTALL", "en": "INSTALL"}$j$, 1, true, 10, $j${"value": "INSTALL"}$j$),
        (v_bos_release_operacion, 'bos.release.operacion.ROLLBACK', $j${"es": "ROLLBACK", "en": "ROLLBACK"}$j$, 1, true, 20, $j${"value": "ROLLBACK"}$j$),
        (v_bos_release_operacion, 'bos.release.operacion.UPDATE', $j${"es": "UPDATE", "en": "UPDATE"}$j$, 1, true, 30, $j${"value": "UPDATE"}$j$);

    -- chk_rel_re_result [bos.rel_release_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.release.resultado', $j${"es": "Resultado", "en": "Result"}$j$, 0, false, $j${"constraint": "chk_rel_re_result", "columns": ["bos.rel_release_event.result"]}$j$)
    RETURNING item_id INTO v_bos_release_resultado;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_release_resultado, 'bos.release.resultado.FAIL', $j${"es": "FAIL", "en": "FAIL"}$j$, 1, true, 10, $j${"value": "FAIL"}$j$),
        (v_bos_release_resultado, 'bos.release.resultado.OK', $j${"es": "OK", "en": "OK"}$j$, 1, true, 20, $j${"value": "OK"}$j$),
        (v_bos_release_resultado, 'bos.release.resultado.PARTIAL', $j${"es": "PARTIAL", "en": "PARTIAL"}$j$, 1, true, 30, $j${"value": "PARTIAL"}$j$);

    -- chk_rel_re_trigger [bos.rel_release_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.release.disparado_por', $j${"es": "Disparado por", "en": "Triggered By"}$j$, 0, false, $j${"constraint": "chk_rel_re_trigger", "columns": ["bos.rel_release_event.triggered_by"]}$j$)
    RETURNING item_id INTO v_bos_release_disparado_por;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_release_disparado_por, 'bos.release.disparado_por.human', $j${"es": "human", "en": "human"}$j$, 1, true, 10, $j${"value": "human"}$j$),
        (v_bos_release_disparado_por, 'bos.release.disparado_por.scheduler', $j${"es": "scheduler", "en": "scheduler"}$j$, 1, true, 20, $j${"value": "scheduler"}$j$),
        (v_bos_release_disparado_por, 'bos.release.disparado_por.watchdog', $j${"es": "watchdog", "en": "watchdog"}$j$, 1, true, 30, $j${"value": "watchdog"}$j$);

    -- chk_wdg_we_action [bos.wdg_watchdog_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.watchdog.accion_tomada', $j${"es": "Acción tomada", "en": "Action Taken"}$j$, 0, false, $j${"constraint": "chk_wdg_we_action", "columns": ["bos.wdg_watchdog_event.action_taken"]}$j$)
    RETURNING item_id INTO v_bos_watchdog_accion_tomada;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_watchdog_accion_tomada, 'bos.watchdog.accion_tomada.auto_repair', $j${"es": "auto_repair", "en": "auto_repair"}$j$, 1, true, 10, $j${"value": "auto_repair"}$j$),
        (v_bos_watchdog_accion_tomada, 'bos.watchdog.accion_tomada.daemon_restart', $j${"es": "daemon_restart", "en": "daemon_restart"}$j$, 1, true, 20, $j${"value": "daemon_restart"}$j$),
        (v_bos_watchdog_accion_tomada, 'bos.watchdog.accion_tomada.hitl_escalated', $j${"es": "hitl_escalated", "en": "hitl_escalated"}$j$, 1, true, 30, $j${"value": "hitl_escalated"}$j$),
        (v_bos_watchdog_accion_tomada, 'bos.watchdog.accion_tomada.none', $j${"es": "none", "en": "none"}$j$, 1, true, 40, $j${"value": "none"}$j$),
        (v_bos_watchdog_accion_tomada, 'bos.watchdog.accion_tomada.rollback', $j${"es": "rollback", "en": "rollback"}$j$, 1, true, 50, $j${"value": "rollback"}$j$);

    -- chk_wdg_we_layer [bos.wdg_watchdog_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.watchdog.capa_verificacion', $j${"es": "Capa de verificación (watchdog)", "en": "Check Layer"}$j$, 0, false, $j${"constraint": "chk_wdg_we_layer", "columns": ["bos.wdg_watchdog_event.check_layer"]}$j$)
    RETURNING item_id INTO v_bos_watchdog_capa_verificacion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_watchdog_capa_verificacion, 'bos.watchdog.capa_verificacion.bos_fichas', $j${"es": "bos_fichas", "en": "bos_fichas"}$j$, 1, true, 10, $j${"value": "bos_fichas"}$j$),
        (v_bos_watchdog_capa_verificacion, 'bos.watchdog.capa_verificacion.k8s_cluster', $j${"es": "k8s_cluster", "en": "k8s_cluster"}$j$, 1, true, 20, $j${"value": "k8s_cluster"}$j$),
        (v_bos_watchdog_capa_verificacion, 'bos.watchdog.capa_verificacion.ubuntu_host', $j${"es": "ubuntu_host", "en": "ubuntu_host"}$j$, 1, true, 30, $j${"value": "ubuntu_host"}$j$);

    -- chk_wdg_we_resource [bos.wdg_watchdog_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.watchdog.tipo_recurso', $j${"es": "Tipo de recurso", "en": "Resource Type"}$j$, 0, false, $j${"constraint": "chk_wdg_we_resource", "columns": ["bos.wdg_watchdog_event.resource_type"]}$j$)
    RETURNING item_id INTO v_bos_watchdog_tipo_recurso;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_watchdog_tipo_recurso, 'bos.watchdog.tipo_recurso.daemon', $j${"es": "daemon", "en": "daemon"}$j$, 1, true, 10, $j${"value": "daemon"}$j$),
        (v_bos_watchdog_tipo_recurso, 'bos.watchdog.tipo_recurso.ficha', $j${"es": "ficha", "en": "ficha"}$j$, 1, true, 20, $j${"value": "ficha"}$j$),
        (v_bos_watchdog_tipo_recurso, 'bos.watchdog.tipo_recurso.host', $j${"es": "host", "en": "host"}$j$, 1, true, 30, $j${"value": "host"}$j$),
        (v_bos_watchdog_tipo_recurso, 'bos.watchdog.tipo_recurso.node', $j${"es": "node", "en": "node"}$j$, 1, true, 40, $j${"value": "node"}$j$),
        (v_bos_watchdog_tipo_recurso, 'bos.watchdog.tipo_recurso.pod', $j${"es": "pod", "en": "pod"}$j$, 1, true, 50, $j${"value": "pod"}$j$);

    -- chk_wdg_we_result [bos.wdg_watchdog_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.watchdog.resultado_accion', $j${"es": "Resultado de la acción", "en": "Action Result"}$j$, 0, false, $j${"constraint": "chk_wdg_we_result", "columns": ["bos.wdg_watchdog_event.action_result"]}$j$)
    RETURNING item_id INTO v_bos_watchdog_resultado_accion;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_watchdog_resultado_accion, 'bos.watchdog.resultado_accion.FAIL', $j${"es": "FAIL", "en": "FAIL"}$j$, 1, true, 10, $j${"value": "FAIL"}$j$),
        (v_bos_watchdog_resultado_accion, 'bos.watchdog.resultado_accion.OK', $j${"es": "OK", "en": "OK"}$j$, 1, true, 20, $j${"value": "OK"}$j$),
        (v_bos_watchdog_resultado_accion, 'bos.watchdog.resultado_accion.PENDING', $j${"es": "PENDING", "en": "PENDING"}$j$, 1, true, 30, $j${"value": "PENDING"}$j$);

    -- chk_wdg_we_severity [bos.wdg_watchdog_event]
    INSERT INTO bglobal.menu_item (code, label, depth, is_leaf, metadata)
    VALUES ('bos.watchdog.severidad', $j${"es": "Severidad", "en": "Severity"}$j$, 0, false, $j${"constraint": "chk_wdg_we_severity", "columns": ["bos.wdg_watchdog_event.severity"]}$j$)
    RETURNING item_id INTO v_bos_watchdog_severidad;

    INSERT INTO bglobal.menu_item (parent_id, code, label, depth, is_leaf, sort_order, metadata)
    VALUES
        (v_bos_watchdog_severidad, 'bos.watchdog.severidad.CRITICAL', $j${"es": "CRITICAL", "en": "CRITICAL"}$j$, 1, true, 10, $j${"value": "CRITICAL"}$j$),
        (v_bos_watchdog_severidad, 'bos.watchdog.severidad.ERROR', $j${"es": "ERROR", "en": "ERROR"}$j$, 1, true, 20, $j${"value": "ERROR"}$j$),
        (v_bos_watchdog_severidad, 'bos.watchdog.severidad.INFO', $j${"es": "INFO", "en": "INFO"}$j$, 1, true, 30, $j${"value": "INFO"}$j$),
        (v_bos_watchdog_severidad, 'bos.watchdog.severidad.WARN', $j${"es": "WARN", "en": "WARN"}$j$, 1, true, 40, $j${"value": "WARN"}$j$);

END $$;

-- ── Verificación total acumulada ─────────────────────────────────────────────
SELECT resumen FROM (
  SELECT 1 AS ord, 'menu_context total (ENUMs formales + CHECKs): ' || COUNT(*) AS resumen
    FROM bglobal.menu_context
  UNION ALL
  SELECT 2, 'menu_item raíz total (depth=0): ' || COUNT(*) FROM bglobal.menu_item WHERE depth=0
  UNION ALL
  SELECT 3, 'menu_item valores (depth=1): '  || COUNT(*) FROM bglobal.menu_item WHERE depth=1
) t ORDER BY ord;
