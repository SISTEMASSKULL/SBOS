-- ============================================================
-- bauth_db DDL — FASE 2: Índices + Constraints FK
-- build_ddl.sh v9 · 2026-06-23T03:50:40Z
-- Se ejecuta DESPUÉS de FASE 1 (todas las tablas creadas)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tenant_status     ON bauth.bos_tenant(status);

CREATE INDEX IF NOT EXISTS idx_tenant_verif      ON bauth.bos_tenant(verification_status);

CREATE INDEX IF NOT EXISTS idx_tenant_type       ON bauth.bos_tenant(tenant_type);

CREATE INDEX IF NOT EXISTS idx_tenant_sub        ON bauth.bos_tenant(subscription_status);

CREATE INDEX IF NOT EXISTS idx_btv_tenant ON bauth.bos_tenant_verification(tenant_id, step);

CREATE INDEX IF NOT EXISTS idx_ciudad_pais ON bauth.bos_ciudad(pais_iso);

CREATE INDEX IF NOT EXISTS idx_btd_tenant ON bauth.bos_tenant_domain(tenant_id);

CREATE INDEX IF NOT EXISTS idx_btd_active ON bauth.bos_tenant_domain(active) WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_btn_tenant ON bauth.bos_tenant_network(tenant_id);

CREATE INDEX IF NOT EXISTS idx_btc_tenant ON bauth.bos_tenant_currency(tenant_id);

CREATE INDEX IF NOT EXISTS idx_btl_tenant ON bauth.bos_tenant_language(tenant_id);

CREATE INDEX IF NOT EXISTS idx_btg_tenant   ON bauth.bos_tenant_gestion(tenant_id);

CREATE INDEX IF NOT EXISTS idx_btg_empresa  ON bauth.bos_tenant_gestion(empresa_id);

CREATE INDEX IF NOT EXISTS idx_btg_corriente ON bauth.bos_tenant_gestion(tenant_id, empresa_id) WHERE es_gestion_corriente = true;

CREATE INDEX IF NOT EXISTS idx_btg_estado   ON bauth.bos_tenant_gestion(estado);

CREATE INDEX IF NOT EXISTS idx_bgc_gestion ON bauth.bos_gestion_calendario(gestion_id, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_bgc_empresa ON bauth.bos_gestion_calendario(empresa_id);

CREATE INDEX IF NOT EXISTS idx_bgc_tipo    ON bauth.bos_gestion_calendario(tipo, fecha_inicio);

CREATE INDEX IF NOT EXISTS idx_bsch_tenant   ON bauth.bos_schedule(tenant_id);

CREATE INDEX IF NOT EXISTS idx_bsch_empresa  ON bauth.bos_schedule(empresa_id);

CREATE INDEX IF NOT EXISTS idx_bsch_sucursal ON bauth.bos_schedule(sucursal_id);

CREATE INDEX IF NOT EXISTS idx_bsch_default  ON bauth.bos_schedule(tenant_id, empresa_id, sucursal_id) WHERE es_default = true;

CREATE INDEX IF NOT EXISTS idx_sf_tenant ON bauth.bos_sitio_fisico(tenant_id);

CREATE INDEX IF NOT EXISTS idx_edif_sitio ON bauth.bos_edificio(sitio_id);

CREATE INDEX IF NOT EXISTS idx_piso_edif ON bauth.bos_piso(edificio_id);

CREATE INDEX IF NOT EXISTS idx_area_piso ON bauth.bos_area_fisica(piso_id);

CREATE INDEX IF NOT EXISTS idx_df_area     ON bauth.bos_dispositivo_fisico(area_id);

CREATE INDEX IF NOT EXISTS idx_df_tipo     ON bauth.bos_dispositivo_fisico(tipo);

CREATE INDEX IF NOT EXISTS idx_df_proto    ON bauth.bos_dispositivo_fisico(protocolo);

CREATE INDEX IF NOT EXISTS idx_df_pos      ON bauth.bos_dispositivo_fisico(pos_logico_id) WHERE pos_logico_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_df_estado   ON bauth.bos_dispositivo_fisico(estado) WHERE estado IN ('ALARMA','FALLO');

CREATE INDEX IF NOT EXISTS idx_fl_rol ON bauth.bos_financial_limit(tenant_id, rol_id);

CREATE INDEX IF NOT EXISTS idx_fl_empresa ON bauth.bos_financial_limit(empresa_id);

CREATE INDEX IF NOT EXISTS idx_fdm_empresa ON bauth.bos_financial_decision_matrix(empresa_id);

CREATE INDEX IF NOT EXISTS idx_fa_empresa   ON bauth.bos_financial_approval(empresa_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fa_solicitud ON bauth.bos_financial_approval(solicitante_uuid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fa_pendiente ON bauth.bos_financial_approval(estado) WHERE estado IN ('PENDIENTE','EN_REVISION','ESCALADO');

CREATE INDEX IF NOT EXISTS idx_fa_referencia ON bauth.bos_financial_approval(referencia);

CREATE INDEX IF NOT EXISTS idx_frp_rol ON bauth.bos_financial_role_permission(rol_id);

CREATE INDEX IF NOT EXISTS idx_pl_rol  ON bauth.bos_permiso_logico(rol_id);

CREATE INDEX IF NOT EXISTS idx_pl_zona ON bauth.bos_permiso_logico(zona_id);

CREATE INDEX IF NOT EXISTS idx_crl_user ON bauth.bos_credential_rotation_log(user_uuid, rotado_en DESC);

CREATE INDEX IF NOT EXISTS idx_crl_tipo ON bauth.bos_credential_rotation_log(credential_type, rotado_en DESC);

CREATE INDEX IF NOT EXISTS idx_empresa_tenant ON bauth.bos_empresa(tenant_id);

CREATE INDEX IF NOT EXISTS idx_empresa_nit    ON bauth.bos_empresa(nit);

CREATE INDEX IF NOT EXISTS idx_sucursal_empresa ON bauth.bos_sucursal(empresa_id);

CREATE INDEX IF NOT EXISTS idx_sucursal_tenant  ON bauth.bos_sucursal(tenant_id);

CREATE INDEX IF NOT EXISTS idx_pos_sucursal    ON bauth.bos_pos_logico(sucursal_id);

CREATE INDEX IF NOT EXISTS idx_pos_empresa     ON bauth.bos_pos_logico(empresa_id);

CREATE INDEX IF NOT EXISTS idx_pos_tenant      ON bauth.bos_pos_logico(tenant_id);

CREATE INDEX IF NOT EXISTS idx_pos_device      ON bauth.bos_pos_logico(device_id) WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pos_sin_estado  ON bauth.bos_pos_logico(estado_dosificacion) WHERE estado_dosificacion IN ('ACTIVA','VENCIDA');

CREATE INDEX IF NOT EXISTS idx_pos_cufd        ON bauth.bos_pos_logico(cufd_vigencia) WHERE cufd IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_brt_tenant      ON bauth.bos_rol_template(tenant_id);

CREATE INDEX IF NOT EXISTS idx_brt_parent      ON bauth.bos_rol_template(parent_id) WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_brt_status      ON bauth.bos_rol_template(status);

CREATE INDEX IF NOT EXISTS idx_brt_tier        ON bauth.bos_rol_template(tier);

CREATE INDEX IF NOT EXISTS idx_brt_template_gin ON bauth.bos_rol_template USING GIN(template);

CREATE INDEX IF NOT EXISTS idx_brth_rol ON bauth.bos_rol_template_history(rol_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_but_tenant      ON bauth.bos_user_template(tenant_id);

CREATE INDEX IF NOT EXISTS idx_but_empresa     ON bauth.bos_user_template(empresa_id);

CREATE INDEX IF NOT EXISTS idx_but_sucursal    ON bauth.bos_user_template(sucursal_id);

CREATE INDEX IF NOT EXISTS idx_but_roles       ON bauth.bos_user_template USING GIN(rol_ids);

CREATE INDEX IF NOT EXISTS idx_but_kc          ON bauth.bos_user_template(kc_user_id);

CREATE INDEX IF NOT EXISTS idx_but_status      ON bauth.bos_user_template(status);

CREATE INDEX IF NOT EXISTS idx_but_template_gin ON bauth.bos_user_template USING GIN(template);

CREATE INDEX IF NOT EXISTS idx_rc_desc ON bauth.bos_rol_closure(descendiente_id);

CREATE INDEX IF NOT EXISTS idx_rc_anc  ON bauth.bos_rol_closure(ancestro_id);

CREATE INDEX IF NOT EXISTS idx_bdl_active   ON bauth.bos_delegation_log(valid_until) WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_bdl_from     ON bauth.bos_delegation_log(from_user_uuid);

CREATE INDEX IF NOT EXISTS idx_biot_user ON bauth.bos_biometric_templates(user_uuid);

CREATE UNIQUE INDEX IF NOT EXISTS idx_biot_unique_null ON bauth.bos_biometric_templates(user_uuid, biometric_type) WHERE finger IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_biot_unique_finger ON bauth.bos_biometric_templates(user_uuid, biometric_type, finger) WHERE finger IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bph_user ON bauth.bos_password_history(user_uuid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bme_user ON bauth.bos_mfa_enrollments(user_uuid);

CREATE INDEX IF NOT EXISTS idx_bae_ctx      ON bauth.bos_audit_events(ctx_id);

CREATE INDEX IF NOT EXISTS idx_bae_user     ON bauth.bos_audit_events(user_uuid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bae_type     ON bauth.bos_audit_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bae_tenant   ON bauth.bos_audit_events(tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cs_user    ON bauth.bos_context_sessions(user_uuid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cs_expiry  ON bauth.bos_context_sessions(expires_at) WHERE state = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_cs_tenant  ON bauth.bos_context_sessions(tenant_id);

CREATE INDEX IF NOT EXISTS idx_cs_empresa ON bauth.bos_context_sessions(empresa_id);

CREATE INDEX IF NOT EXISTS idx_csw_user ON bauth.bos_context_switches(user_uuid, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_csw_ctx  ON bauth.bos_context_switches(ctx_id_nuevo);

CREATE INDEX IF NOT EXISTS idx_bsl_status ON bauth.bos_sync_log(status) WHERE status IN ('ERROR','PENDING');

CREATE INDEX IF NOT EXISTS idx_bsl_retry  ON bauth.bos_sync_log(next_retry_at) WHERE next_retry_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bsc_active ON bauth.bos_superuser_contexts(expires_at) WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_bar_due ON bauth.bos_access_reviews(due_date) WHERE decision IS NULL;

CREATE INDEX IF NOT EXISTS idx_bga_detected ON bauth.bos_ghost_accounts(detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_bkrl_key ON bauth.bos_key_rotation_log(key_type, performed_at DESC);

CREATE INDEX IF NOT EXISTS ix_bos_role_atom_role ON bos_privilege.bos_role_atom (role_id, allowed) WHERE allowed = TRUE;

CREATE INDEX IF NOT EXISTS ix_atom_policy_data ON bos_privilege.bos_atom_policy USING GIN (policy_data jsonb_path_ops);

CREATE INDEX IF NOT EXISTS ix_atom_policy_priority ON bos_privilege.bos_atom_policy (policy_domain, ((policy_data ->> 'priority')::integer), active) WHERE active = TRUE;

CREATE INDEX IF NOT EXISTS idx_merkle_leaf_batch ON bos_blockchain.bos_merkle_leaf USING btree (batch_id);

CREATE INDEX IF NOT EXISTS idx_anchor_log_batch ON bos_blockchain.bos_blockchain_anchor_log USING btree (batch_id);

CREATE INDEX IF NOT EXISTS idx_anchor_log_status ON bos_blockchain.bos_blockchain_anchor_log USING btree (status);

CREATE INDEX IF NOT EXISTS idx_settlement_status ON bos_blockchain.bos_onchain_settlement USING btree (status);

CREATE INDEX IF NOT EXISTS idx_reconciliation_account ON bos_blockchain.bos_reconciliation_log USING btree (account_id);

CREATE INDEX IF NOT EXISTS idx_brecm_user ON bauth.bos_recovery_method(user_uuid);

CREATE INDEX IF NOT EXISTS idx_bind_user ON bauth.bos_authenticator_binding(user_uuid);

CREATE INDEX IF NOT EXISTS idx_brev_user ON bauth.bos_authenticator_revocation(user_uuid, revoked_at DESC);

CREATE INDEX IF NOT EXISTS idx_bla_user ON bauth.bos_login_attempt(user_uuid, attempt_at DESC) WHERE success = FALSE;

CREATE INDEX IF NOT EXISTS idx_bla_ip   ON bauth.bos_login_attempt(source_ip, attempt_at DESC) WHERE success = FALSE;

CREATE INDEX IF NOT EXISTS idx_brch_user ON bauth.bos_recovery_challenge(user_uuid);

CREATE INDEX IF NOT EXISTS idx_bpsl_user ON bauth.bos_password_screening_log(user_uuid, screened_at DESC);

CREATE INDEX IF NOT EXISTS idx_sod_bits ON bauth.bos_sod_conflict_matrix(bit_a, bit_b);

