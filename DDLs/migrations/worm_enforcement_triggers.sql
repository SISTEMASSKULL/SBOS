-- worm_enforcement_triggers.sql
-- Cierra: GAP-OP-02 / GAP-PCI-01 (A.73 v1.1.0)
-- Normas: ISO 27001:2022 A.8.15 · NIST SP 800-53 AU-9 · PCI DSS 4.0 Req 10.3.2
-- Propósito: WORM enforcement activo a nivel base de datos.
--   El DDL tenía REVOKE UPDATE/DELETE preventivos (no retroactivos cuando el rol nunca
--   tuvo esos permisos). Este script añade triggers BEFORE UPDATE OR DELETE que lanzan
--   RAISE EXCEPTION en cada tabla append-only, garantizando rechazo activo en la BD.
-- Tablas excluidas (ya tienen trigger hash-chain implementado en el DDL base):
--   - bauth.idn_roles_rol_lifecycle_event   (trg_irle_worm)
--   - bauth.idn_roles_ver_b01_audit_log     (trg_irvb01al_worm)
-- Idempotente: DROP TRIGGER IF EXISTS + CREATE TRIGGER — seguro de ejecutar múltiples veces.
-- Autor: bAuth DDL · 2026-08-02

SET lock_timeout = '5s';

-- =============================================================================
-- §1 FUNCIÓN WORM COMPARTIDA
-- Un único punto de enforcement para todos los schemas.
-- No es SECURITY DEFINER: el rechazo aplica a cualquier usuario, incluyendo superusuarios
-- que invoquen por error (el mensaje orienta al DBA hacia la causa correcta).
-- =============================================================================

CREATE OR REPLACE FUNCTION bauth.fn_worm_enforce()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'WORM_VIOLATION: %.% es una tabla de solo inserción (append-only). '
        'Operación % rechazada por enforcer activo. '
        'Norma: ISO 27001:2022 A.8.15 · NIST AU-9 · PCI DSS 10.3.2. '
        'Si necesita corregir un registro, contacte al DBA con justificación auditada.',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP;
END;
$$;

COMMENT ON FUNCTION bauth.fn_worm_enforce() IS
'Función WORM compartida. Rechaza UPDATE y DELETE en tablas append-only con RAISE EXCEPTION.
ISO 27001:2022 A.8.15 — protección de registros de auditoría. Referenciada por trg_worm en
29 tablas de los schemas bauth, bcalendar y bos.';

-- =============================================================================
-- §2 TRIGGERS WORM — schema bauth (27 tablas)
-- =============================================================================

-- T-196: bindings DPoP de un solo uso
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_network_dpop_binding;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_network_dpop_binding
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-202: historial inmutable de contraseñas (NIST 800-63B §5.1.1.2 no-reutilización)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_credential_password_history;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_credential_password_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-226: evidencia de evacuación física (evidencia forense y responsabilidad legal)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_physical_access_evacuation;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_physical_access_evacuation
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-419: log de uso de delegaciones (evidencia forense del comportamiento del grantee)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_delegation_usage_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_delegation_usage_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-424: log multi-dominio de auditoría (append-only con hash chain SHA-256)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_audit_event_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_audit_event_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-425: ancla blockchain extendida (refleja inmutabilidad del registro distribuido)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_blockchain_anchor_ext;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_blockchain_anchor_ext
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-443: log de verificaciones de firma (evidencia forense de validez en el tiempo)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_signature_verification_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_signature_verification_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- T-445: evidencia LTV (estado PKI en un instante — photo forense)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_signature_ltv_evidence;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_signature_ltv_evidence
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Historial de usuarios (JML audit trail — NIST SP 800-53 AC-2)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_user_history;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_user_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Historial de atributos de identidad (chain de auditoría por clave de atributo)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_identity_attribute_history;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_identity_attribute_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Consentimiento de privacidad (GDPR Art. 7 — el consentimiento otorgado es evidencia permanente)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_identity_consent;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_identity_consent
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Historial de plantillas de rol (auditoría de cambios en configuración de roles)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_roles_template_history;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_roles_template_history
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de ciclo de vida de NHI (Non-Human Identities — M2M lifecycle events)
DROP TRIGGER IF EXISTS trg_worm ON bauth.idn_roles_nhi_lifecycle_event;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.idn_roles_nhi_lifecycle_event
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Auditoría de átomos de privilegio (log de cambios en el motor BitMask)
DROP TRIGGER IF EXISTS trg_worm ON bauth.privilege_atom_audit;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.privilege_atom_audit
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Binding de credencial a dispositivo (FIDO2 device binding — acceso físico)
DROP TRIGGER IF EXISTS trg_worm ON bauth.auth_device_credential_binding;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.auth_device_credential_binding
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de intentos de autenticación (PARTICIONADA — trigger se propaga a particiones)
DROP TRIGGER IF EXISTS trg_worm ON bauth.auth_attempt_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.auth_attempt_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log CAEP de sesión (CAEP events — RFC 8935 Continuous Access Evaluation)
DROP TRIGGER IF EXISTS trg_worm ON bauth.ses_caep_event_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.ses_caep_event_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de entregas SSF (RFC 8936 — Security Event Token delivery)
DROP TRIGGER IF EXISTS trg_worm ON bauth.ses_ssf_delivery_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.ses_ssf_delivery_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Sello de tiempo de firma (RFC 3161 TSA — evidencia jurídica de firma Ley 164)
DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_timestamp;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.sig_timestamp
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de operaciones de firma digital (evidencia legal Ley 164 Bolivia)
DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_operation_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.sig_operation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Hashes de documentos firmados (integridad post-firma — cadena de custodia Ley 164)
DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_document_hash;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.sig_document_hash
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Historial de ciclo de vida del certificado ADSIB (evidencia ante ADSIB Bolivia)
DROP TRIGGER IF EXISTS trg_worm ON bauth.sig_adsib_lifecycle;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.sig_adsib_lifecycle
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Ancla blockchain (prueba de existencia del batch — verificable externamente)
DROP TRIGGER IF EXISTS trg_worm ON bauth.blk_anchor;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.blk_anchor
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Hoja del árbol Merkle (base matemática de la prueba de integridad)
DROP TRIGGER IF EXISTS trg_worm ON bauth.blk_merkle_leaf;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.blk_merkle_leaf
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- IOC — log de correlaciones de amenazas (T-526 — ISO 27001:2022 A.5.7)
DROP TRIGGER IF EXISTS trg_worm ON bauth.thi_correlation_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.thi_correlation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de presentaciones de wallet VC (PARTICIONADA — evidencia de consentimiento)
DROP TRIGGER IF EXISTS trg_worm ON bauth.wallet_presentation_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.wallet_presentation_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- Log de emisión de VCs (evidencia irrefutable del proceso de issuance)
DROP TRIGGER IF EXISTS trg_worm ON bauth.wallet_issuance_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bauth.wallet_issuance_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- =============================================================================
-- §3 TRIGGERS WORM — schema bcalendar (1 tabla)
-- =============================================================================

-- T-017: log de notificaciones de calendario (evidencia de comunicaciones del sistema)
DROP TRIGGER IF EXISTS trg_worm ON bcalendar.cal_notification_log;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bcalendar.cal_notification_log
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- =============================================================================
-- §4 TRIGGERS WORM — schema bos (1 tabla)
-- =============================================================================

-- T-397: log de auditoría del Context Plane (WORM hash-chain — NIST SP 800-207)
DROP TRIGGER IF EXISTS trg_worm ON bos.ctx_context_audit;
CREATE TRIGGER trg_worm
    BEFORE UPDATE OR DELETE ON bos.ctx_context_audit
    FOR EACH STATEMENT EXECUTE FUNCTION bauth.fn_worm_enforce();

-- =============================================================================
-- §5 VERIFICACIÓN
-- =============================================================================

-- Conteo de triggers trg_worm creados (esperado: 29)
SELECT
    n.nspname AS schema,
    c.relname AS tabla,
    t.tgname  AS trigger
FROM pg_trigger t
JOIN pg_class c     ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE t.tgname = 'trg_worm'
  AND NOT t.tgisinternal
ORDER BY n.nspname, c.relname;

SELECT COUNT(*) AS triggers_worm_activos,
       '(esperado: 29 + N particiones)' AS nota
FROM pg_trigger t
JOIN pg_class c     ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE t.tgname = 'trg_worm'
  AND NOT t.tgisinternal
  AND n.nspname IN ('bauth', 'bcalendar', 'bos');

-- Prueba funcional FOR EACH STATEMENT: activa incluso sin filas (WHERE FALSE)
-- Nota: FOR EACH ROW no se activa sin filas; FOR EACH STATEMENT sí — éste es el comportamiento correcto.
DO $$
BEGIN
    BEGIN
        UPDATE bauth.thi_correlation_log SET corr_id = corr_id WHERE FALSE;
        RAISE EXCEPTION 'FALLO: UPDATE debería haber sido rechazado por trigger WORM';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE 'WORM_VIOLATION%' THEN
                RAISE NOTICE 'OK: trigger WORM STATEMENT activo en thi_correlation_log — UPDATE rechazado correctamente';
            ELSE
                RAISE;
            END IF;
    END;

    BEGIN
        DELETE FROM bauth.thi_correlation_log WHERE FALSE;
        RAISE EXCEPTION 'FALLO: DELETE debería haber sido rechazado por trigger WORM';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE 'WORM_VIOLATION%' THEN
                RAISE NOTICE 'OK: trigger WORM STATEMENT activo en thi_correlation_log — DELETE rechazado correctamente';
            ELSE
                RAISE;
            END IF;
    END;
END $$;
