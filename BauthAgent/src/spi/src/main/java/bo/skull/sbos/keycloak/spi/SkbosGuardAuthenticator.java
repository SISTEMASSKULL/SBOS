package bo.skull.sbos.keycloak.spi;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.keycloak.Config;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.authentication.authenticators.conditional.ConditionalAuthenticator;
import org.keycloak.models.AuthenticationExecutionModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.models.RealmModel;
import org.keycloak.models.UserModel;
import org.keycloak.provider.ProviderConfigProperty;

/**
 * SPI-1: SBOS Guard Authenticator.
 * Primer paso del Flujo de Autenticación. Lee los métodos permitidos del
 * atributo de grupo del usuario (sincronizado desde RolTemplate) y deniega métodos
 * no autorizados para el rol.
 */
public class SkbosGuardAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "bos-guard-authenticator";
    private static final String ATTR_ALLOWED_METHODS = "bos_allowed_methods";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requestedMethod = context.getAuthenticationSession()
                .getClientNote("requested_method");
        if (requestedMethod == null) {
            return true;
        }

        String allowedMethodsStr = context.getUser()
                .getFirstAttribute(ATTR_ALLOWED_METHODS);
        if (allowedMethodsStr == null || allowedMethodsStr.isEmpty()) {
            return true;
        }

        Set<String> allowedMethods = new HashSet<>(
                Arrays.asList(allowedMethodsStr.split(",")));

        if (!allowedMethods.contains(requestedMethod.trim())) {
            context.getEvent().error("method_not_authorized_for_role");
            return false;
        }
        return true;
    }

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        context.attempted();
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
    }

    @Override
    public void action(AuthenticationFlowContext context) {
    }

    @Override
    public void close() {
    }

    // ── Factory ────────────────────────────────────────────────

    public static class Factory implements AuthenticatorFactory {

        private static final SkbosGuardAuthenticator SINGLETON = new SkbosGuardAuthenticator();

        @Override
        public String getDisplayType() {
            return "SBOS Guardia — Autorización de Métodos";
        }

        @Override
        public String getReferenceCategory() {
            return "authorization";
        }

        @Override
        public boolean isConfigurable() {
            return false;
        }

        @Override
        public AuthenticationExecutionModel.Requirement[] getRequirementChoices() {
            return new AuthenticationExecutionModel.Requirement[]{
                    AuthenticationExecutionModel.Requirement.REQUIRED,
                    AuthenticationExecutionModel.Requirement.CONDITIONAL,
                    AuthenticationExecutionModel.Requirement.DISABLED
            };
        }

        @Override
        public boolean isUserSetupAllowed() {
            return false;
        }

        @Override
        public String getHelpText() {
            return "Deniega métodos de autenticación no autorizados para el rol del usuario.";
        }

        @Override
        public List<ProviderConfigProperty> getConfigProperties() {
            return List.of();
        }

        @Override
        public Authenticator create(KeycloakSession session) {
            return SINGLETON;
        }

        @Override
        public void init(Config.Scope config) {
        }

        @Override
        public void postInit(KeycloakSessionFactory factory) {
        }

        @Override
        public void close() {
        }

        @Override
        public String getId() {
            return PROVIDER_ID;
        }
    }
}
