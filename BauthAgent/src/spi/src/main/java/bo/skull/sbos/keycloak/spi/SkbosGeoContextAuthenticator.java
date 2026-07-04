package bo.skull.sbos.keycloak.spi;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Arrays;
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
 * SPI-2: SBOS Geo-Context Authenticator.
 * Verifies that the login source IP falls within the allowed_networks
 * attribute set on the KC user (sync'd from RolTemplate).
 */
public class SkbosGeoContextAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "bos-geocontext-authenticator";
    private static final String ATTR_ALLOWED_NETWORKS = "allowed_networks";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        String allowedNetworks = context.getUser()
                .getFirstAttribute(ATTR_ALLOWED_NETWORKS);
        if (allowedNetworks == null || allowedNetworks.isEmpty()) {
            return true;
        }

        String remoteAddr = context.getConnection().getRemoteAddr();
        boolean inAllowed = Arrays.stream(allowedNetworks.split(","))
                .map(String::trim)
                .anyMatch(cidr -> isInCidr(remoteAddr, cidr));

        if (!inAllowed) {
            context.getEvent().error("login_from_unauthorized_network");
            return false;
        }
        return true;
    }

    private boolean isInCidr(String ip, String cidr) {
        try {
            String[] parts = cidr.split("/");
            InetAddress addr = InetAddress.getByName(parts[0]);
            int prefix = Integer.parseInt(parts[1]);

            byte[] addrBytes = addr.getAddress();
            byte[] ipBytes = InetAddress.getByName(ip).getAddress();

            if (addrBytes.length != ipBytes.length) {
                return false;
            }

            int fullBytes = prefix / 8;
            int remBits = prefix % 8;

            for (int i = 0; i < fullBytes; i++) {
                if (addrBytes[i] != ipBytes[i]) {
                    return false;
                }
            }

            if (remBits > 0 && fullBytes < addrBytes.length) {
                int mask = (0xFF << (8 - remBits)) & 0xFF;
                if ((addrBytes[fullBytes] & mask) != (ipBytes[fullBytes] & mask)) {
                    return false;
                }
            }
            return true;
        } catch (UnknownHostException | NumberFormatException e) {
            return false;
        }
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

        private static final SkbosGeoContextAuthenticator SINGLETON = new SkbosGeoContextAuthenticator();

        @Override
        public String getDisplayType() {
            return "SBOS Geo-Context — Network Authorization";
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
            return "Denies login from IP addresses not in the user's allowed_networks.";
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
