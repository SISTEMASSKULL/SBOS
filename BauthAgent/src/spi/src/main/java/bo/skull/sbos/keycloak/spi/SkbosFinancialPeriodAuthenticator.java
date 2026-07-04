package bo.skull.sbos.keycloak.spi;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

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
 * SPI-3: SBOS Financial Period Authenticator.
 * Verifies that the current time falls within the allowed operating windows
 * defined in the rol del usuario.(shift_start/end, allowed_days, transaction_schedule).
 */
public class SkbosFinancialPeriodAuthenticator implements ConditionalAuthenticator {

    public static final String PROVIDER_ID = "bos-financial-period-authenticator";
    private static final String ATTR_SHIFT_START = "shift_start";
    private static final String ATTR_SHIFT_END = "shift_end";
    private static final String ATTR_ALLOWED_DAYS = "allowed_days";

    @Override
    public boolean matchCondition(AuthenticationFlowContext context) {
        // Check shift hours
        String shiftStart = context.getUser().getFirstAttribute(ATTR_SHIFT_START);
        String shiftEnd = context.getUser().getFirstAttribute(ATTR_SHIFT_END);

        if (shiftStart != null && shiftEnd != null) {
            try {
                LocalTime start = LocalTime.parse(shiftStart);
                LocalTime end = LocalTime.parse(shiftEnd);
                LocalTime now = LocalTime.now();

                if (start.isBefore(end)) {
                    // Normal window (e.g. 08:00-18:00)
                    if (now.isBefore(start) || now.isAfter(end)) {
                        context.getEvent().error("outside_shift_hours");
                        return false;
                    }
                } else {
                    // Overnight window (e.g. 22:00-06:00)
                    if (now.isBefore(start) && now.isAfter(end)) {
                        context.getEvent().error("outside_shift_hours");
                        return false;
                    }
                }
            } catch (DateTimeParseException e) {
                context.getEvent().detail("warning", "shift_hours_parse_error");
            }
        }

        // Check allowed days
        String allowedDays = context.getUser().getFirstAttribute(ATTR_ALLOWED_DAYS);
        if (allowedDays != null && !allowedDays.isEmpty()) {
            Set<DayOfWeek> allowed = Arrays.stream(allowedDays.split(","))
                    .map(String::trim)
                    .map(String::toUpperCase)
                    .filter(s -> !s.isEmpty())
                    .map(DayOfWeek::valueOf)
                    .collect(Collectors.toSet());

            if (!allowed.contains(LocalDate.now().getDayOfWeek())) {
                context.getEvent().error("outside_allowed_days");
                return false;
            }
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

        private static final SkbosFinancialPeriodAuthenticator SINGLETON = new SkbosFinancialPeriodAuthenticator();

        @Override
        public String getDisplayType() {
            return "SBOS Período Financiero — Shift & Day Restriction";
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
            return "Denies login outside the user's allowed shift hours and days.";
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
