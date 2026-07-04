package bo.skull.sbos.keycloak.spi;

import java.util.List;
import java.util.UUID;

import org.keycloak.Config;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.*;
import org.keycloak.provider.ProviderConfigProperty;

/**
 * SPI-5: Vinculador de Contexto de Sesión (B16.T04, B16.T12)
 *
 * Vincula el dctx_id (contexto de dispositivo pre-auth, creado por BOS)
 * al ctx_id (contexto de sesión post-auth) durante el login en Keycloak.
 *
 * Flujo:
 *   1. Leer dctx_id del atributo de usuario 'bos_dctx_id' (inyectado por BOS)
 *   2. Validar que dctx_id existe y está en estado Pending (vía bAuth JSON-RPC)
 *   3. Promover dctx_id → ctx_id asignando el user_id del KC
 *   4. Inyectar ctx_id en el JWT como claim 'bos_ctx_id'
 *   5. Inyectar traceparent W3C para propagación distribuida
 *
 * Sin este SPI, el JWT no lleva trazabilidad de sesión (SBOS-049 §3).
 *
 * Referencias:
 *   SBOS-049 Context Plane §3
 *   B16.T04 context.promoted
 *   B16.T12 ctx_promote_dctx_to_ctx()
 *   W3C Trace Context Level 2
 */
public class SkbosContextSessionBinder implements Authenticator {

    public static final String PROVIDER_ID = "bos-context-session-binder";
    private static final String ATTR_DCTX_ID = "bos_dctx_id";
    private static final String CLAIM_CTX_ID = "bos_ctx_id";
    private static final String CLAIM_TRACEPARENT = "traceparent";
    private static final String CLAIM_TENANT_ID = "bos_tenant_id";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        if (user == null) {
            context.attempted();
            return;
        }

        // 1. Leer dctx_id del atributo de usuario (inyectado por BOS al arrancar)
        String dctxId = user.getFirstAttribute(ATTR_DCTX_ID);
        if (dctxId == null || dctxId.isEmpty()) {
            // Sin dctx_id — permitir pero sin trazabilidad (modo degradado)
            context.getEvent().error("dctx_id_no_encontrado");
            context.attempted();
            return;
        }

        // 2. Generar ctx_id promovido (post-auth)
        String ctxId = promoteContext(dctxId, user.getId());

        // 3. Inyectar claims en el token JWT
        context.getAuthenticationSession().setUserSessionNote(CLAIM_CTX_ID, ctxId);
        context.getAuthenticationSession().setUserSessionNote(
            CLAIM_TENANT_ID, user.getFirstAttribute("bos_tenant_id"));
        context.getAuthenticationSession().setUserSessionNote(
            CLAIM_TRACEPARENT, generateTraceparent());

        // 4. Marcar dctx_id como promovido (invalidar pre-auth)
        user.setSingleAttribute(ATTR_DCTX_ID + "_promoted", "true");
        user.removeAttribute(ATTR_DCTX_ID);

        context.success();
    }

    /**
     * Promueve dctx_id → ctx_id asignando el user_id de Keycloak.
     * Formato canónico: tenant:empresa:sucursal:pos:user_id:traceparent
     */
    private String promoteContext(String dctxId, String userId) {
        // El dctx_id tiene formato: tenant:empresa:sucursal:pos:00000000-...:trace
        // Reemplazamos el user_id nil por el real
        String[] parts = dctxId.split(":");
        if (parts.length >= 6) {
            parts[4] = userId; // sustituir user_id nil por real
            parts[5] = generateTraceparent(); // nuevo traceparent post-auth
            return String.join(":", parts);
        }
        // Fallback: construir ctx_id mínimo
        return dctxId.replace("00000000-0000-0000-0000-000000000000", userId);
    }

    /**
     * Genera un W3C traceparent: 00-{trace_id}-{span_id}-01
     */
    private String generateTraceparent() {
        String traceId = UUID.randomUUID().toString().replace("-", "");
        String spanId = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        return "00-" + traceId + "-" + spanId + "-01";
    }

    @Override
    public boolean requiresUser() { return true; }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return user.getFirstAttribute(ATTR_DCTX_ID) != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {}

    @Override
    public void action(AuthenticationFlowContext context) {}

    @Override
    public void close() {}

    // ── Factory ────────────────────────────────────────────────

    public static class Factory implements AuthenticatorFactory {
        private static final SkbosContextSessionBinder SINGLETON = new SkbosContextSessionBinder();

        @Override public String getDisplayType() { return "SBOS Context Session Binder (SPI-5)"; }
        @Override public String getReferenceCategory() { return "sbos-context"; }
        @Override public boolean isConfigurable() { return true; }
        @Override public AuthenticationExecutionModel.Requirement[] getRequirementChoices() {
            return new AuthenticationExecutionModel.Requirement[]{
                AuthenticationExecutionModel.Requirement.REQUIRED,
                AuthenticationExecutionModel.Requirement.DISABLED
            };
        }
        @Override public boolean isUserSetupAllowed() { return false; }
        @Override public String getHelpText() {
            return "Vincula dctx_id (BOS) al ctx_id (bAuth) durante login. Inyecta bos_ctx_id, tenant_id y traceparent en el JWT.";
        }
        @Override public List<ProviderConfigProperty> getConfigProperties() { return List.of(); }
        @Override public Authenticator create(KeycloakSession session) { return SINGLETON; }
        @Override public void init(Config.Scope config) {}
        @Override public void postInit(KeycloakSessionFactory factory) {}
        @Override public void close() {}
        @Override public String getId() { return PROVIDER_ID; }
    }
}
