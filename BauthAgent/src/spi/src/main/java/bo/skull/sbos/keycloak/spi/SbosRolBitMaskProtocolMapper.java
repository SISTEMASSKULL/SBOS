package bo.skull.sbos.keycloak.spi;

import java.util.ArrayList;
import java.util.List;

import org.keycloak.models.*;
import org.keycloak.protocol.ProtocolMapper;
import org.keycloak.protocol.oidc.mappers.*;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.representations.IDToken;

/**
 * SPI-1: Mapeador de Protocolo RolBitMask (OIDC Protocol Mapper).
 *
 * Inyecta en el JWT los claims del modelo BitMask Dual v3.0:
 *   - bos_rol_bitmask: base64 del RolBitMask one-hot (posiciones activas)
 *   - bos_atom_bitmask: hex del AtomBitMask 64-bit (átomo de login)
 *   - bos_ctx_id: identificador del Context Plane (SBOS-049)
 *   - bos_tenant_id: tenant del usuario
 *
 * MODELO NUEVO (BitMask Dual v3.0):
 *   El JWT contiene DOS campos de bitmask, no múltiples máscaras por dominio.
 *   La verificación de acceso opera sobre bos_rol_bitmask (N bits one-hot).
 *   El bos_atom_bitmask identifica el átomo específico de la operación (64-bit label).
 *
 * MODELO VIEJO (ELIMINADO):
 *   BitmaskBundle con máscaras separadas por dominio (bos_physical_mask,
 *   bos_logical_mask, bos_financial_mask, etc.) — YA NO SE USA.
 *
 * Referencias:
 *   SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md §4-5
 *   B1.T04 — JWT claims corregidos
 *   B23.T02 — SPI 1 RolBitMaskProtocolMapper
 */
public class SbosRolBitMaskProtocolMapper extends AbstractOIDCProtocolMapper
        implements OIDCAccessTokenMapper, OIDCIDTokenMapper, UserInfoTokenMapper {

    public static final String PROVIDER_ID = "bos-rol-bitmask-mapper";
    private static final String CLAIM_ROL_BITMASK = "bos_rol_bitmask";
    private static final String CLAIM_ATOM_BITMASK = "bos_atom_bitmask";
    private static final String CLAIM_CTX_ID = "bos_ctx_id";
    private static final String CLAIM_TENANT_ID = "bos_tenant_id";
    private static final String CLAIM_USER_ID = "bos_user_id";

    @Override
    protected void setClaim(IDToken token, ProtocolMapperModel mappingModel,
                            UserSessionModel userSession, KeycloakSession session,
                            ClientSessionContext clientCtx) {

        UserModel user = userSession.getUser();
        if (user == null) return;

        // ── 1. RolBitMask (N-bit one-hot) ──────────────────
        String rolBitmaskBase64 = userSession.getNote(CLAIM_ROL_BITMASK);
        if (rolBitmaskBase64 == null || rolBitmaskBase64.isEmpty()) {
            // Leer del atributo de usuario (sincronizado desde bauth_db)
            rolBitmaskBase64 = user.getFirstAttribute("bos_rol_bitmask");
        }
        if (rolBitmaskBase64 != null && !rolBitmaskBase64.isEmpty()) {
            token.getOtherClaims().put(CLAIM_ROL_BITMASK, rolBitmaskBase64);
        }

        // ── 2. AtomBitMask (64-bit label encoding) ─────────
        String atomBitmaskHex = userSession.getNote(CLAIM_ATOM_BITMASK);
        if (atomBitmaskHex == null || atomBitmaskHex.isEmpty()) {
            atomBitmaskHex = user.getFirstAttribute("bos_atom_bitmask");
        }
        if (atomBitmaskHex != null && !atomBitmaskHex.isEmpty()) {
            token.getOtherClaims().put(CLAIM_ATOM_BITMASK, atomBitmaskHex);
        }

        // ── 3. Context Plane (SBOS-049) ────────────────────
        String ctxId = userSession.getNote(CLAIM_CTX_ID);
        if (ctxId != null && !ctxId.isEmpty()) {
            token.getOtherClaims().put(CLAIM_CTX_ID, ctxId);
        }

        // ── 4. Tenant ID ───────────────────────────────────
        String tenantId = userSession.getNote(CLAIM_TENANT_ID);
        if (tenantId == null || tenantId.isEmpty()) {
            tenantId = user.getFirstAttribute("bos_tenant_id");
        }
        if (tenantId != null && !tenantId.isEmpty()) {
            token.getOtherClaims().put(CLAIM_TENANT_ID, tenantId);
        }

        // ── 5. User ID ─────────────────────────────────────
        token.getOtherClaims().put(CLAIM_USER_ID, user.getId());
    }

    @Override
    public String getDisplayType() {
        return "SBOS Rol BitMask Mapper (SPI-1)";
    }

    @Override
    public String getHelpText() {
        return "Inyecta bos_rol_bitmask (base64 N-bit one-hot) y bos_atom_bitmask (hex 64-bit) en el JWT. BitMask Dual v3.0.";
    }

    @Override
    public String getId() { return PROVIDER_ID; }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() { return List.of(); }

    // ── Factory ────────────────────────────────────────────────

    public static class Factory extends AbstractOIDCProtocolMapper.Factory {
        public static final SbosRolBitMaskProtocolMapper SINGLETON = new SbosRolBitMaskProtocolMapper();

        @Override public String getDisplayType() { return "SBOS Rol BitMask (SPI-1)"; }
        @Override public String getHelpText() { return "Inyecta bos_rol_bitmask + bos_atom_bitmask + bos_ctx_id en el JWT según BitMask Dual v3.0."; }
        @Override public ProtocolMapper create(KeycloakSession session) { return SINGLETON; }
        @Override public String getId() { return PROVIDER_ID; }
        @Override public List<ProviderConfigProperty> getConfigProperties() { return List.of(); }
    }
}
