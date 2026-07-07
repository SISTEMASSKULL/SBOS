-- ======================================================================
-- DDL_framework_unified.sql — Biblioteca Unificada de Políticas y Configs
-- Schema: bauth (Identity Governance & Audit Platform)
-- Tabla: bauth.cfg_policy_library
-- Función: bauth.jsonb_explode(node jsonb)
-- Tabla soporte: bauth.cfg_key_translation
-- Dependencia: DDL_skSBOS_db.sql (schemas, lock_timeout)
-- ======================================================================

SET lock_timeout = '5s';
SET client_min_messages = WARNING;

-- ══════════════════════════════════════════════════════════════════════
-- Tabla: framework_raw — Carga de JSON fuente para CTE de descomposición
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.framework_raw (
    id          serial PRIMARY KEY,
    source_name text NOT NULL UNIQUE,
    content     jsonb NOT NULL,
    loaded_at   timestamptz DEFAULT now()
);
COMMENT ON TABLE bauth.framework_raw IS 'JSON fuente para alimentar el CTE recursivo que descompone en cfg_policy_library.';

-- ══════════════════════════════════════════════════════════════════════
-- Tabla: cfg_policy_library — Biblioteca jerárquica de políticas/configs
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.cfg_policy_library (
    -- Identidad jerárquica
    section_id          serial PRIMARY KEY,
    section_name        text NOT NULL,
    parent_path         text,
    json_path           text NOT NULL,
    depth               integer DEFAULT 1 NOT NULL CHECK (depth >= 1),
    order_index         integer DEFAULT 1 NOT NULL CHECK (order_index >= 1),
    array_index         bigint DEFAULT 0 CHECK (array_index >= 0),

    -- Clasificación estructural
    node_type           text NOT NULL CHECK (node_type IN ('section','group','policy','config')),

    -- Clasificación semántica
    semantic_type       text CHECK (semantic_type IN ('policy','configuration','method','standard','guideline','group')),
    domain_map          text[],

    -- Origen y trazabilidad
    source              text NOT NULL,
    standard_ref        text,
    industry_source     text,
    compliance_ref      text[],

    -- Contenido multilingüe
    content             jsonb NOT NULL,
    content_en          jsonb NOT NULL,
    content_es          jsonb NOT NULL,
    help_text           jsonb,
    description         text,

    -- Metadatos de clasificación avanzada
    enforcement         text CHECK (enforcement IN ('mandatory','recommended','optional')),
    risk_level          text CHECK (risk_level IN ('critical','high','medium','low')),
    lifecycle           text CHECK (lifecycle IN ('active','deprecated','draft','proposed')),
    applicability       text[],
    assurance_level     text CHECK (assurance_level IN ('AAL1','AAL2','AAL3')),
    auth_factor         text CHECK (auth_factor IN ('knowledge','possession','inherence','context','multi')),
    phishing_resistant  boolean,
    session_timeout     integer,
    mfa_required        boolean,

    -- Auditoría
    created_at          timestamptz DEFAULT now()
);

-- Índices de unicidad
CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_json_path ON bauth.cfg_policy_library (json_path);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_section_parent_source ON bauth.cfg_policy_library (section_name, COALESCE(parent_path, ''), source);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cfg_library_json_path_source ON bauth.cfg_policy_library (json_path, source);

-- Índices de búsqueda
CREATE INDEX IF NOT EXISTS idx_cfg_library_parent ON bauth.cfg_policy_library (parent_path, source);
CREATE INDEX IF NOT EXISTS idx_cfg_library_node_type ON bauth.cfg_policy_library (node_type);
CREATE INDEX IF NOT EXISTS idx_cfg_library_source ON bauth.cfg_policy_library (source);
CREATE INDEX IF NOT EXISTS idx_cfg_library_domain ON bauth.cfg_policy_library USING gin (domain_map);

-- Índices de filtrado
CREATE INDEX IF NOT EXISTS idx_cfg_library_semantic ON bauth.cfg_policy_library (semantic_type);
CREATE INDEX IF NOT EXISTS idx_cfg_library_enforcement ON bauth.cfg_policy_library (enforcement);
CREATE INDEX IF NOT EXISTS idx_cfg_library_risk ON bauth.cfg_policy_library (risk_level);
CREATE INDEX IF NOT EXISTS idx_cfg_library_assurance ON bauth.cfg_policy_library (assurance_level);
CREATE INDEX IF NOT EXISTS idx_cfg_library_lifecycle ON bauth.cfg_policy_library (lifecycle);
CREATE INDEX IF NOT EXISTS idx_cfg_library_mfa ON bauth.cfg_policy_library (mfa_required);
CREATE INDEX IF NOT EXISTS idx_cfg_library_phish ON bauth.cfg_policy_library (phishing_resistant);

-- FK autoreferencial: parent_path + source → json_path + source
ALTER TABLE bauth.cfg_policy_library DROP CONSTRAINT IF EXISTS fk_cfg_library_parent;
ALTER TABLE bauth.cfg_policy_library ADD CONSTRAINT fk_cfg_library_parent
    FOREIGN KEY (parent_path, source) REFERENCES bauth.cfg_policy_library (json_path, source) NOT VALID;

COMMENT ON TABLE bauth.cfg_policy_library IS 'Biblioteca unificada de políticas, configuraciones y métodos de autenticación. 16 fuentes, 13 dominios D1-D12+SEC.';
COMMENT ON COLUMN bauth.cfg_policy_library.json_path IS 'Ruta completa en el JSON fuente. Identificador único global.';
COMMENT ON COLUMN bauth.cfg_policy_library.node_type IS 'Estructura JSON: section, group, policy, config.';
COMMENT ON COLUMN bauth.cfg_policy_library.semantic_type IS 'Significado de negocio: policy, configuration, method, standard, guideline, group.';
COMMENT ON COLUMN bauth.cfg_policy_library.compliance_ref IS 'IDs de controles específicos: PCI DSS 4.0 Req 7.2.4, ISO 27001:2022 A.8.5, NIST 800-53 AC-2.';

-- ══════════════════════════════════════════════════════════════════════
-- Tabla: cfg_key_translation — Mapeo de claves inglés → español
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS bauth.cfg_key_translation (
    key_en  text PRIMARY KEY,
    key_es  text NOT NULL
);

COMMENT ON TABLE bauth.cfg_key_translation IS 'Mapeo manual de ~221 claves JSON inglés→español para content_es.';

TRUNCATE TABLE bauth.cfg_key_translation;
-- [datos movidos a seed_cfg_key_translation — ORQUESTA-050]
-- INSERT INTO bauth.cfg_key_translation (key_en, key_es) VALUES
-- ('enabled','habilitado'),('disabled','deshabilitado'),('required','requerido'),('optional','opcional'),
-- ('active','activo'),('inactive','inactivo'),('description','descripcion'),('status','estado'),
-- ('level','nivel'),('type','tipo'),('mode','modo'),('key','clave'),('name','nombre'),('value','valor'),
-- ('source','fuente'),('target','destino'),('security','seguridad'),('policies','politicas'),
-- ('rules','reglas'),('actions','acciones'),('events','eventos'),('alerts','alertas'),
-- ('frequency','frecuencia'),('period','periodo'),('duration','duracion'),('interval','intervalo'),
-- ('timeout','tiempoEspera'),('threshold','umbral'),('limit','limite'),('weight','peso'),
-- ('priority','prioridad'),('access','acceso'),('control','control'),('authentication','autenticacion'),
-- ('authorization','autorizacion'),('identity','identidad'),('session','sesion'),('token','token'),
-- ('password','contrasena'),('credential','credencial'),('certificate','certificado'),
-- ('encryption','cifrado'),('signature','firma'),('algorithm','algoritmo'),('protocol','protocolo'),
-- ('standard','estandar'),('compliance','cumplimiento'),('audit','auditoria'),('log','registro'),
-- ('monitoring','monitoreo'),('review','revision'),('approval','aprobacion'),('risk','riesgo'),
-- ('threat','amenaza'),('trust','confianza'),('privacy','privacidad'),('integrity','integridad'),
-- ('confidentiality','confidencialidad'),('availability','disponibilidad'),('resilience','resiliencia'),
-- ('recovery','recuperacion'),('backup','respaldo'),('rotation','rotacion'),('expiration','expiracion'),
-- ('revocation','revocacion'),('provisioning','aprovisionamiento'),('delegation','delegacion'),
-- ('segregation','segregacion'),('separation','separacion'),('minimum','minimo'),('maximum','maximo'),
-- ('default','porDefecto'),('custom','personalizado'),('internal','interno'),('external','externo'),
-- ('public','publico'),('private','privado'),('role','rol'),('user','usuario'),('group','grupo'),
-- ('permission','permiso'),('profile','perfil'),('account','cuenta'),('device','dispositivo'),
-- ('network','red'),('data','datos'),('api','api'),('service','servicio'),('application','aplicacion'),
-- ('workload','cargaTrabajo'),('container','contenedor'),('cluster','cluster'),
-- ('namespace','espacioNombres'),('resource','recurso'),('policy','politica'),
-- ('configuration','configuracion'),('management','gestion'),('protection','proteccion'),
-- ('detection','deteccion'),('prevention','prevencion'),('response','respuesta'),
-- ('validation','validacion'),('verification','verificacion'),('testing','prueba'),
-- ('assessment','evaluacion'),('classification','clasificacion'),('retention','retencion'),
-- ('masking','enmascaramiento'),('anonymization','anonimizacion'),('tokenization','tokenizacion'),
-- ('sanctumEnhanced','sanctumMejorado'),('tokenManagement','gestionTokens'),
-- ('keyRotation','rotacionClaves'),('adaptiveInterval','intervaloAdaptativo'),
-- ('maxInterval','intervaloMaximo'),('minInterval','intervaloMinimo'),('riskFactors','factoresRiesgo'),
-- ('threatLevel','nivelAmenaza'),('accessPatterns','patronesAcceso'),
-- ('securityIncidents','incidentesSeguridad'),('strategy','estrategia'),('proactive','proactivo'),
-- ('riskEngine','motorRiesgo'),('riskScore','puntuacionRiesgo'),('contextEngine','motorContexto'),
-- ('deviceAnalysis','analisisDispositivo'),('locationAnalysis','analisisUbicacion'),
-- ('networkAnalysis','analisisRed'),('behavioralAnalysis','analisisConductual'),
-- ('threatDetection','deteccionAmenazas'),('anomalyDetection','deteccionAnomalias'),
-- ('sessionManager','gestorSesiones'),('sessionTimeout','tiempoEsperaSesion'),
-- ('concurrentSessions','sesionesConcurrentes'),('loggingSystem','sistemaRegistro'),
-- ('auditTrail','pistaAuditoria'),('eventLogging','registroEventos'),
-- ('logRetention','retencionRegistros'),('incidentManagement','gestionIncidentes'),
-- ('incidentResponse','respuestaIncidentes'),('detectionEngine','motorDeteccion'),
-- ('escalationPolicies','politicasEscalacion'),('dataSecuritySystem','sistemaSeguridadDatos'),
-- ('dataSecurityControls','controlesSeguridadDatos'),('dataClassification','clasificacionDatos'),
-- ('accessControl','controlAcceso'),('accessPolicies','politicasAcceso'),
-- ('policyEngine','motorPoliticas'),('continuousMonitoring','monitoreoContinuo'),
-- ('highAvailability','altaDisponibilidad'),('disasterRecovery','recuperacionDesastres'),
-- ('businessContinuity','continuidadNegocio'),('containerSecurity','seguridadContenedores'),
-- ('runtimeProtection','proteccionEjecucion'),('admissionControl','controlAdmision'),
-- ('podSecurity','seguridadPod'),('identityFederation','federacionIdentidad'),
-- ('federationTrust','confianzaFederacion'),('apiSecurity','seguridadAPI'),
-- ('endpointProtection','proteccionEndpoints'),('rateLimiting','limitacionTasa'),
-- ('circuitBreaker','cortacircuitos'),('faultTolerance','toleranciaFallos'),
-- ('cryptographicManagement','gestionCriptografica'),('keyManagement','gestionClaves'),
-- ('secretsVault','bovedaSecretos'),('zeroTrustSystem','sistemaConfianzaCero'),
-- ('zeroTrustInfrastructure','infraestructuraConfianzaCero'),
-- ('blockchainSecurity','seguridadBlockchain'),('aiSecurity','seguridadIA'),
-- ('modelProtection','proteccionModelos'),('microservicesSystem','sistemaMicroservicios'),
-- ('serviceMesh','mallaServicios'),('deviceManagement','gestionDispositivos'),
-- ('postQuantumSystem','sistemaPostCuantico'),('hybridMode','modoHibrido'),
-- ('keyExchange','intercambioClaves'),('digitalSignatures','firmasDigitales'),
-- ('passwordPolicy','politicaContrasena'),('mfaRequirements','requisitosMFA'),
-- ('phishingResistant','resistentePhishing'),('blocklistScreening','filtroBlocklist'),
-- ('geoFencing','geoCerca'),('regionAware','conscienteRegion'),
-- ('dataSovereignty','soberaniaDatos'),('breakGlass','romperCristal'),
-- ('justInTime','justoATiempo'),('segregationOfDuties','segregacionFunciones'),
-- ('approvalChain','cadenaAprobacion'),('temporaryAccess','accesoTemporal'),
-- ('emergencyOverride','anulacionEmergencia'),('bestPractices','mejoresPracticas'),
-- ('requirements','requisitos'),('features','caracteristicas'),
-- ('implementation','implementacion'),('orchestration','orquestacion'),
-- ('automation','automatizacion'),('synchronization','sincronizacion'),
-- ('replication','replicacion'),('federation','federacion'),('escalation','escalacion'),
-- ('integration','integracion'),('habilitado','habilitado'),('requerido','requerido'),
-- ('intervalo','intervalo'),('estrategia','estrategia'),('rotacionClaves','rotacionClaves'),
-- ('gestionTokens','gestionTokens'),('seguridad','seguridad'),
-- ('intervaloAdaptativo','intervaloAdaptativo'),('factoresRiesgo','factoresRiesgo'),
-- ('intervaloMaximo','intervaloMaximo'),('intervaloMinimo','intervaloMinimo'),
-- ('frecuencia','frecuencia'),('tipo','tipo'),('peso','peso'),
-- ('anonimizacion','anonimizacion'),('revocacion','revocacion'),
-- ('renovacion','renovacion'),('cicloVida','cicloVida'),
-- ('certificados','certificados'),('firmaDigital','firmaDigital');

-- ══════════════════════════════════════════════════════════════════════
-- Función: jsonb_explode — Descompone objetos y arrays en filas
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION bauth.jsonb_explode(node jsonb)
RETURNS TABLE(child_key text, child_value jsonb, child_ordinality bigint)
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
BEGIN
    IF jsonb_typeof(node) = 'object' THEN
        RETURN QUERY SELECT k, v, 0::bigint FROM jsonb_each(node) AS e(k, v);
    ELSIF jsonb_typeof(node) = 'array' THEN
        RETURN QUERY SELECT '[' || o::text || ']', v, o
                     FROM jsonb_array_elements(node) WITH ORDINALITY AS e(v, o);
    END IF;
END;
$$;

COMMENT ON FUNCTION bauth.jsonb_explode(jsonb) IS 'Descompone nodo JSONB en filas (key, value, ordinality). Objetos→jsonb_each, Arrays→jsonb_array_elements.';

-- ══════════════════════════════════════════════════════════════════════
-- Función: translate_keys_en_es — Traduce claves JSON inglés → español
-- ══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION bauth.translate_keys_en_es(node jsonb)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
DECLARE
    result jsonb := '{}';
    child_record record;
    translated_key text;
    child_value jsonb;
    word_parts text[];
    translated_parts text[];
    i integer;
    part text;
BEGIN
    IF jsonb_typeof(node) = 'object' THEN
        FOR child_record IN SELECT * FROM jsonb_each(node) LOOP
            -- 1) Buscar clave exacta en tabla de traducción
            SELECT kt.key_es INTO translated_key
            FROM bauth.cfg_key_translation kt WHERE kt.key_en = child_record.key;

            -- 2) Si no se encontró, descomponer camelCase
            IF translated_key IS NULL THEN
                -- Separar por camelCase: accessControl → ['access','control']
                translated_parts := '{}';
                FOR part IN SELECT w[1] FROM regexp_matches(child_record.key, '([A-Z][a-z]+|[a-z]+)', 'g') AS w LOOP
                    SELECT COALESCE(kt2.key_es, lower(part)) INTO part
                    FROM (SELECT 1) AS d
                    LEFT JOIN bauth.cfg_key_translation kt2 ON kt2.key_en = lower(part);
                    translated_parts := array_append(translated_parts, part);
                END LOOP;

                IF array_length(translated_parts, 1) > 1 THEN
                    translated_key := array_to_string(translated_parts, '');
                ELSE
                    translated_key := NULL;
                END IF;
            END IF;

            -- 3) Si no se encontró, descomponer snake_case
            IF translated_key IS NULL THEN
                translated_parts := '{}';
                FOR part IN SELECT w FROM regexp_split_to_table(child_record.key, '_') AS w LOOP
                    SELECT COALESCE(kt3.key_es, part) INTO part
                    FROM (SELECT 1) AS d
                    LEFT JOIN bauth.cfg_key_translation kt3 ON kt3.key_en = part;
                    translated_parts := array_append(translated_parts, part);
                END LOOP;

                IF array_length(translated_parts, 1) > 1 THEN
                    translated_key := array_to_string(translated_parts, '_');
                ELSE
                    translated_key := NULL;
                END IF;
            END IF;

            -- 4) Fallback: clave original
            IF translated_key IS NULL THEN
                translated_key := child_record.key;
            END IF;

            child_value := bauth.translate_keys_en_es(child_record.value);
            result := result || jsonb_build_object(translated_key, child_value);
        END LOOP;
        RETURN result;
    ELSIF jsonb_typeof(node) = 'array' THEN
        result := '[]';
        FOR child_record IN SELECT * FROM jsonb_array_elements(node) WITH ORDINALITY AS elem(value, idx) ORDER BY idx LOOP
            child_value := bauth.translate_keys_en_es(child_record.value);
            result := result || jsonb_build_array(child_value);
        END LOOP;
        RETURN result;
    ELSE
        RETURN node;
    END IF;
END;
$$;

COMMENT ON FUNCTION bauth.translate_keys_en_es(jsonb) IS 'Recorre JSONB recursivamente y traduce claves usando bauth.cfg_key_translation. Valores se preservan intactos.';

-- ═══════════════════════════════════════════════════════════════
-- FASE 2: Carga automática de fuentes en framework_raw (TODO SQL, sin archivos)
-- NOTA: datos cargados por bauth_fw_01..16 (INSERT ON CONFLICT DO NOTHING)
--       Este bloque NO trunca — el proceso es idempotente.
-- ═══════════════════════════════════════════════════════════════

-- Fuentes originales (SQL autocontenido)

-- Fuentes investigación 2025-2026 (inline SQL)

-- Fuentes investigación 2025-2026 (inline)

-- ═══════════════════════════════════════════════════════════════
-- FASE 3: Poblar cfg_policy_library desde framework_raw (CTE)
-- NOTA: ON CONFLICT DO NOTHING → idempotente, no re-procesa si ya existe.
--       Para forzar recarga completa: TRUNCATE bauth.cfg_policy_library CASCADE; (manual)
-- ═══════════════════════════════════════════════════════════════

WITH RECURSIVE tree AS (
  SELECT kv.key AS section_name, NULL::text AS parent_path, kv.value AS node,
         'section' AS node_type, 1 AS depth, 0::bigint AS array_index,
         r.source_name || '.' || kv.key AS json_path, r.source_name AS src
  FROM bauth.framework_raw r, jsonb_each(r.content) AS kv(key, value)

  UNION ALL

  SELECT e.child_key, t.json_path, e.child_value,
         CASE WHEN jsonb_typeof(e.child_value) = 'object' THEN 'group'
              WHEN jsonb_typeof(e.child_value) = 'array' THEN 'policy' ELSE 'config' END,
         t.depth + 1, e.child_ordinality,
         t.json_path || CASE WHEN e.child_ordinality > 0 THEN '[' || e.child_ordinality::text || ']' ELSE '.' || e.child_key END,
         t.src
  FROM tree t, bauth.jsonb_explode(t.node) AS e
  WHERE t.depth < 15
)
INSERT INTO bauth.cfg_policy_library (section_name, parent_path, node_type, depth, array_index, json_path, source, content, content_en, content_es)
SELECT section_name, parent_path, node_type, depth, array_index, json_path, src, node, node, node
FROM tree
ON CONFLICT (json_path) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- FASE 4: Traducción y documentación automática
-- ═══════════════════════════════════════════════════════════════
UPDATE bauth.cfg_policy_library SET content_es = bauth.translate_keys_en_es(content_en);

UPDATE bauth.cfg_policy_library SET help_text = jsonb_build_array(
  CASE node_type
    WHEN 'section' THEN 'Sección: ' || section_name || ' — Fuente: ' || source
    WHEN 'group'   THEN 'Grupo: ' || section_name || ' — Padre: ' || COALESCE(parent_path, 'raíz')
    WHEN 'policy'  THEN 'Política: ' || section_name
    WHEN 'config'  THEN 'Configuración: ' || section_name || ' = ' || left(content::text, 80)
  END,
  'Ruta: ' || json_path, 'Fuente: ' || source, 'Profundidad: ' || depth::text, 'Tipo: ' || node_type
) WHERE help_text IS NULL;

-- ═══════════════════════════════════════════════════════════════
-- FASE 5: Clasificación automática por fuente y dominio
-- ═══════════════════════════════════════════════════════════════
-- 5.1 domain_map por fuente
-- NOTA: source_names en BD son camelCase (authenticationFramework, policiesAuthenticationFramework)
UPDATE bauth.cfg_policy_library SET domain_map = CASE source
  -- Framework principal — clasificación por section_name (nivel 2)
  WHEN 'authenticationFramework' THEN CASE
    WHEN section_name IN ('accessControl','adaptiveAccessControl') THEN ARRAY['D1']
    WHEN section_name IN ('advancedBiometrics') THEN ARRAY['D5']
    WHEN section_name IN ('iotEdgeSecurity','endpointDeviceSecurity') THEN ARRAY['D2','D7']
    WHEN section_name IN ('networkSecurity','zeroTrustInfrastructure','containerSecurity',
         'microservicesSecurity','apiSecurity','applicationApiSecurity','webSocketAccessControl') THEN ARRAY['D7']
    WHEN section_name IN ('contextualAuthentication','advancedSessionManagement','contextualSecurity',
         'systemResilience','incidentResponse','behavioralAuthentication') THEN ARRAY['D8']
    WHEN section_name IN ('authenticationCore','identityFederation','federatedAuthentication') THEN ARRAY['D9']
    WHEN section_name IN ('auditingSystem','securityMonitoring','dataProtection','dataPrivacySecurity',
         'dataProtectionSystem','mlAnomalyDetection','aiSecurity','aiSecurityEngine') THEN ARRAY['D11']
    WHEN section_name IN ('blockchainSecurity') THEN ARRAY['D12']
    WHEN section_name IN ('quantumResistantSecurity','quantumSafeSecurity','cryptographyServices',
         'secretsManagement','quantumAuthenticationSystem','metadata') THEN ARRAY['SEC']
    ELSE ARRAY['D9']
  END
  -- Políticas por dominio — clasificación por section_name (nivel 2)
  WHEN 'policiesAuthenticationFramework' THEN CASE
    WHEN section_name IN ('identity_access_policies','advanced_identity_management') THEN ARRAY['D1','D9']
    WHEN section_name IN ('physical_logical_authentication') THEN ARRAY['D2']
    WHEN section_name IN ('modern_authentication_policies') THEN ARRAY['D9']
    WHEN section_name IN ('next_generation_protections','security_privacy_policies',
         'integrations_and_apis') THEN ARRAY['D7','D9']
    WHEN section_name IN ('edge_authentication_policies') THEN ARRAY['D2','D7']
    WHEN section_name IN ('emergency_management') THEN ARRAY['D8']
    WHEN section_name IN ('ml_monitoring','adaptive_learning','compliance_regulation') THEN ARRAY['D11']
    WHEN section_name IN ('blockchain_audit') THEN ARRAY['D12']
    WHEN section_name IN ('quantum_resistant_authentication') THEN ARRAY['SEC']
    ELSE ARRAY['D11']
  END
  -- Fuentes por nombre fijo (snake_case — nombres reales en BD)
  WHEN 'nist_sp_800_63b_rev4'   THEN ARRAY['D9']            -- credenciales/passwords (no biométrico)
  WHEN 'fido2_ctap_2.2'         THEN ARRAY['D7','D9']       -- protocolo red + autenticación (no biométrico)
  WHEN 'nist_pqc_2025'          THEN ARRAY['SEC']
  WHEN 'oauth_2_1'              THEN ARRAY['D7','D9']
  WHEN 'zero_trust_nsa_2026'    THEN ARRAY['D7','D1','D2']
  WHEN 'iso_27001_2022'         THEN ARRAY['D11','D9']
  WHEN 'industry_enterprise'    THEN ARRAY['D9','D7']       -- prácticas enterprise (no biométrico)
  WHEN 'pci_dss_4_0_financial'  THEN ARRAY['D3']
  WHEN 'time_based_access_d4'   THEN ARRAY['D4']
  WHEN 'geo_location_d6'        THEN ARRAY['D6']
  WHEN 'delegation_authority_d10' THEN ARRAY['D10']
  WHEN 'cis_kubernetes_1_8'     THEN ARRAY['D7']
  WHEN 'aws_iam_best_practices' THEN ARRAY['D7','D9']
  WHEN 'soc2_type_ii'           THEN ARRAY['D11']
  ELSE ARRAY['SEC']
END WHERE domain_map IS NULL AND depth = 1;

-- 5.1b domain_map para los dos frameworks camelCase (secciones en depth=2, no depth=1)
-- authenticationFramework y policiesAuthenticationFramework tienen JSON wrapeado un nivel extra:
--   { "authenticationFramework": { "advancedBiometrics": {...} } }  → depth=2 es la sección real
UPDATE bauth.cfg_policy_library SET domain_map = CASE
  WHEN section_name IN ('accessControl','adaptiveAccessControl')              THEN ARRAY['D1']
  WHEN section_name IN ('advancedBiometrics')                                 THEN ARRAY['D5']
  WHEN section_name IN ('iotEdgeSecurity','endpointDeviceSecurity')           THEN ARRAY['D2','D7']
  WHEN section_name IN ('networkSecurity','zeroTrustInfrastructure','containerSecurity',
       'microservicesSecurity','apiSecurity','applicationApiSecurity',
       'webSocketAccessControl')                                               THEN ARRAY['D7']
  WHEN section_name IN ('contextualAuthentication','advancedSessionManagement',
       'contextualSecurity','systemResilience','incidentResponse',
       'behavioralAuthentication')                                             THEN ARRAY['D8']
  WHEN section_name IN ('authenticationCore','identityFederation',
       'federatedAuthentication')                                              THEN ARRAY['D9']
  WHEN section_name IN ('auditingSystem','securityMonitoring','dataProtection',
       'dataPrivacySecurity','dataProtectionSystem','mlAnomalyDetection',
       'aiSecurity','aiSecurityEngine')                                        THEN ARRAY['D11']
  WHEN section_name IN ('blockchainSecurity')                                 THEN ARRAY['D12']
  WHEN section_name IN ('quantumResistantSecurity','quantumSafeSecurity',
       'cryptographyServices','secretsManagement','quantumAuthenticationSystem',
       'metadata')                                                             THEN ARRAY['SEC']
  ELSE ARRAY['D9']
END WHERE source = 'authenticationFramework' AND depth = 2 AND domain_map IS NULL;

UPDATE bauth.cfg_policy_library SET domain_map = CASE
  WHEN section_name IN ('identity_access_policies','advanced_identity_management') THEN ARRAY['D1','D9']
  WHEN section_name IN ('physical_logical_authentication')                         THEN ARRAY['D2']
  WHEN section_name IN ('modern_authentication_policies')                          THEN ARRAY['D9']
  WHEN section_name IN ('next_generation_protections','security_privacy_policies',
       'integrations_and_apis')                                                    THEN ARRAY['D7','D9']
  WHEN section_name IN ('edge_authentication_policies')                            THEN ARRAY['D2','D7']
  WHEN section_name IN ('emergency_management')                                    THEN ARRAY['D8']
  WHEN section_name IN ('ml_monitoring','adaptive_learning','compliance_regulation') THEN ARRAY['D11']
  WHEN section_name IN ('blockchain_audit')                                        THEN ARRAY['D12']
  WHEN section_name IN ('quantum_resistant_authentication')                        THEN ARRAY['SEC']
  ELSE ARRAY['D11']
END WHERE source = 'policiesAuthenticationFramework' AND depth = 2 AND domain_map IS NULL;

-- 5.2 semantic_type por fuente
UPDATE bauth.cfg_policy_library SET semantic_type = CASE
  WHEN source IN ('nist_sp_800_63b_rev4','nist_pqc_2025','iso_27001_2022','soc2_type_ii','zero_trust_nsa_2026') THEN 'standard'
  WHEN source = 'policiesAuthenticationFramework' THEN 'policy'
  WHEN source IN ('industry_enterprise','aws_iam_best_practices','cis_kubernetes_1_8') THEN 'guideline'
  WHEN source IN ('fido2_ctap_2.2','oauth_2_1') THEN 'method'
  WHEN source IN ('pci_dss_4_0_financial','time_based_access_d4','geo_location_d6','delegation_authority_d10') THEN 'policy'
  WHEN source = 'authenticationFramework' THEN CASE
    WHEN section_name IN ('authenticationCore','advancedSessionManagement','secretsManagement',
         'containerSecurity','cryptographyServices','dataProtectionSystem') THEN 'configuration'
    WHEN section_name IN ('advancedBiometrics','behavioralAuthentication','webSocketAccessControl',
         'contextualAuthentication','federatedAuthentication','quantumAuthenticationSystem','identityFederation') THEN 'method'
    ELSE 'policy'
  END
  ELSE 'policy'
END WHERE semantic_type IS NULL AND depth = 1;

-- 5.3 enforcement
UPDATE bauth.cfg_policy_library SET enforcement = CASE
  WHEN semantic_type = 'standard' THEN 'mandatory'
  WHEN semantic_type = 'guideline' THEN 'recommended'
  WHEN semantic_type IN ('policy','configuration','method') THEN 'mandatory'
  ELSE 'mandatory'
END WHERE enforcement IS NULL AND depth = 1;

-- 5.4 risk_level
UPDATE bauth.cfg_policy_library SET risk_level = CASE
  WHEN domain_map @> '{D3}' OR domain_map @> '{D10}' THEN 'critical'
  WHEN domain_map @> '{D1}' OR domain_map @> '{D9}' THEN 'high'
  WHEN domain_map @> '{SEC}' THEN 'high'
  ELSE 'medium'
END WHERE risk_level IS NULL AND depth = 1;

-- 5.5 lifecycle
UPDATE bauth.cfg_policy_library SET lifecycle = 'active' WHERE lifecycle IS NULL AND depth = 1;

-- 5.6 assurance_level, mfa_required, phishing_resistant
UPDATE bauth.cfg_policy_library SET assurance_level = 'AAL2', mfa_required = true WHERE source IN ('nist_sp_800_63b_rev4','fido2_ctap_2.2','oauth_2_1') AND depth = 1;
UPDATE bauth.cfg_policy_library SET assurance_level = 'AAL3', mfa_required = true WHERE source = 'nist_pqc_2025' AND depth = 1;
UPDATE bauth.cfg_policy_library SET assurance_level = 'AAL1', mfa_required = false WHERE assurance_level IS NULL AND depth = 1;
UPDATE bauth.cfg_policy_library SET phishing_resistant = true WHERE source IN ('fido2_ctap_2.2','nist_sp_800_63b_rev4') AND depth = 1;
UPDATE bauth.cfg_policy_library SET phishing_resistant = false WHERE phishing_resistant IS NULL AND depth = 1;

-- 5.7 compliance_ref por fuente
UPDATE bauth.cfg_policy_library SET compliance_ref = CASE source
  WHEN 'nist_sp_800_63b_rev4' THEN ARRAY['NIST SP 800-63B-4 §5.1.1.2','NIST SP 800-63B-4 §5.2']
  WHEN 'fido2_ctap_2.2' THEN ARRAY['FIDO2 CTAP 2.2','WebAuthn Level 3']
  WHEN 'nist_pqc_2025' THEN ARRAY['FIPS 203','FIPS 204','FIPS 205','NIST IR 8547']
  WHEN 'oauth_2_1' THEN ARRAY['OAuth 2.1 draft-ietf-oauth-v2-1-14']
  WHEN 'zero_trust_nsa_2026' THEN ARRAY['NIST SP 800-207','NSA ZIG Phase 1-2']
  WHEN 'iso_27001_2022' THEN ARRAY['ISO 27001:2022 A.5.16','ISO 27001:2022 A.5.17','ISO 27001:2022 A.8.5']
  WHEN 'industry_enterprise' THEN ARRAY['NIST SP 800-63B-4','Google BeyondCorp','Microsoft Entra ID']
  WHEN 'pci_dss_4_0_financial' THEN ARRAY['PCI DSS 4.0 Req 7.2.4','PCI DSS 4.0 Req 8.4.2']
  WHEN 'time_based_access_d4' THEN ARRAY['NIST 800-53 AC-2','ISO 27001:2022 A.8.5']
  WHEN 'geo_location_d6' THEN ARRAY['GDPR Art 44-49','NIS 2 Directive']
  WHEN 'delegation_authority_d10' THEN ARRAY['SOX §404','NIST 800-53 AC-2(6)']
  WHEN 'cis_kubernetes_1_8' THEN ARRAY['CIS K8s 1.8 §1.2','CIS K8s 1.8 §5.1']
  WHEN 'aws_iam_best_practices' THEN ARRAY['AWS IAM Best Practices','AWS Organizations SCPs']
  WHEN 'soc2_type_ii' THEN ARRAY['SOC 2 CC6.1','SOC 2 CC6.2','SOC 2 CC6.3']
  ELSE NULL
END WHERE compliance_ref IS NULL AND depth = 1;

-- 5.8 Propagar clasificaciones de padres a hijos (3 iteraciones)
DO $$ DECLARE r integer := 1; i integer := 0;
BEGIN
  WHILE r > 0 AND i < 20 LOOP i := i + 1;
    UPDATE bauth.cfg_policy_library c SET
      domain_map = COALESCE(c.domain_map, p.domain_map),
      semantic_type = COALESCE(c.semantic_type, p.semantic_type),
      enforcement = COALESCE(c.enforcement, p.enforcement),
      risk_level = COALESCE(c.risk_level, p.risk_level),
      lifecycle = COALESCE(c.lifecycle, p.lifecycle),
      assurance_level = COALESCE(c.assurance_level, p.assurance_level),
      mfa_required = COALESCE(c.mfa_required, p.mfa_required),
      phishing_resistant = COALESCE(c.phishing_resistant, p.phishing_resistant),
      compliance_ref = COALESCE(c.compliance_ref, p.compliance_ref),
      applicability = COALESCE(c.applicability, p.applicability)
    FROM bauth.cfg_policy_library p
    WHERE c.parent_path = p.json_path AND c.source = p.source
      AND (c.domain_map IS NULL OR c.semantic_type IS NULL OR c.enforcement IS NULL OR c.compliance_ref IS NULL);
    GET DIAGNOSTICS r = ROW_COUNT;
  END LOOP;
END; $$;

-- ═══════════════════════════════════════════════════════════════
-- FASE 6: Ejecutar seeds (49 seeds en 10 fases, idempotentes)
-- ═══════════════════════════════════════════════════════════════
\echo '=== Ejecutando seeds desde framework ==='
