package bo.skull.sbos.keycloak.spi;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.List;

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
 * SPI-4: SBOS Role Validity Authenticator.
 * Verifies that the rol del usuario.has not expired by checking the
 * role_valid_until attribute (synced from RolTemplate).
 */
public class SkbosRoleValidityAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "bos-role-validity-authenticator";
    private static final String ATTR_ROLE_VALID_UNTIL = "role_valid_until";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String validUntil = context.getUser()
                .getFirstAttribute(ATTR_ROLE_VALID_UNTIL);
        if (validUntil == null || validUntil.isEmpty()) {
            return true;
        }

        try {
            Instant expiresAt = Instant.parse(validUntil);
            if (Instant.now().isAfter(expiresAt)) {
                context.getEvent().error("role_expired");
                return false;
            }
        } catch (DateTimeParseException e) {
            context.getEvent().detail("warning",
                    "role_valid_until_parse_error:" + validUntil);
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

        private static final SkbosRoleValidityAuthenticator SINGLETON = new SkbosRoleValidityAuthenticator();

        @Override
        public String getDisplayType() {
            return "SBOS Validez de Rol — Expiration Check";
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
            return "Denies login when the rol del usuario.has expired (role_valid_until).";
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
