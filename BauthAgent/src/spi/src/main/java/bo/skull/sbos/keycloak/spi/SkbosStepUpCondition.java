package bo.skull.sbos.keycloak.spi;

import java.util.List;
import java.util.Map;

import org.keycloak.Config;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationManager;
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
 * SPI-5: SBOS Step-Up Condition.
 * Implements RFC 9470 OAuth 2.0 Step-up Authentication Challenge.
 * Verifies that the current session's LoA satisfies the required ACR
 * for the requested operation.
 */
public class SkbosStepUpCondition implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "bos-stepup-condition";

    private static final Map<String, Integer> LOA_ORDER = Map.of(
            "standard", 1,
            "elevated", 2,
            "high_security", 3,
            "critical", 4
    );

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String requiredAcr = context.getAuthenticationSession()
                .getClientNote("requested_acr");
        if (requiredAcr == null || requiredAcr.isEmpty()) {
            return true;
        }

        String currentAcr = AuthenticationManager
                .getSessionAcr(context.getAuthenticationSession());

        int required = LOA_ORDER.getOrDefault(requiredAcr, 1);
        int current = LOA_ORDER.getOrDefault(currentAcr, 0);
        return current >= required;
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

        private static final SkbosStepUpCondition SINGLETON = new SkbosStepUpCondition();

        @Override
        public String getDisplayType() {
            return "SBOS Step-Up — RFC 9470 LoA Verification";
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
            return "Requires step-up authentication when the current LoA is insufficient.";
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
