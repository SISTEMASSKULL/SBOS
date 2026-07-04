/**
 * SBOS WebAuthn Client — v1.0.0
 * =================================
 * Libreria JavaScript para registro y autenticacion WebAuthn/FIDO2.
 * Comunicacion con bAuth via JSON-RPC 2.0.
 *
 * Uso:
 *   const client = new SBOSWebAuthn({ rpcUrl: '/rpc' });
 *   await client.register('user-123', 'john');
 *   await client.authenticate();
 */

class SBOSWebAuthn {
    constructor(options = {}) {
        this.rpcUrl = options.rpcUrl || '/rpc';
        this.rpId = options.rpId || window.location.hostname;
        this.timeout = options.timeout || 60000;
        this.userVerification = options.userVerification || 'preferred';
    }

    // ── Helpers: Base64URL ↔ ArrayBuffer ─────────────────────

    static _b64urlToBuffer(b64) {
        const binary = atob(b64.replace(/-/g, '+').replace(/_/g, '/'));
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
        return bytes.buffer;
    }

    static _bufferToB64url(buffer) {
        const bytes = new Uint8Array(buffer);
        let binary = '';
        for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
        return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    }

    // ── JSON-RPC call to bAuth ─────────────────────────────

    async _rpc(method, params) {
        const resp = await fetch(this.rpcUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ jsonrpc: '2.0', method, params, id: 1 })
        });
        const data = await resp.json();
        if (data.error) throw new Error(data.error.message);
        return data.result;
    }

    // ── Registration (Passkey Creation) ────────────────────

    /**
     * Registra una nueva passkey para el usuario.
     * @param {string} userId - UUID del usuario en bAuth
     * @param {string} username - nombre de usuario
     * @returns {Object} credential info
     */
    async register(userId, username) {
        // 1. Obtener challenge del servidor (bAuth via JSON-RPC)
        const challenge = await this._rpc('bauth.webauthn.register', {
            user_id: userId,
            username: username,
        });

        // 2. Convertir challenge a formato WebAuthn API
        const publicKey = {
            challenge: SBOSWebAuthn._b64urlToBuffer(challenge.publicKey.challenge),
            rp: challenge.publicKey.rp,
            user: {
                id: SBOSWebAuthn._b64urlToBuffer(btoa(challenge.publicKey.user.id)),
                name: challenge.publicKey.user.name,
                displayName: challenge.publicKey.user.displayName,
            },
            pubKeyCredParams: challenge.publicKey.pubKeyCredParams,
            authenticatorSelection: challenge.publicKey.authenticatorSelection,
            timeout: challenge.publicKey.timeout || this.timeout,
            attestation: challenge.publicKey.attestation || 'none',
        };

        // 3. Llamar a la API del navegador
        const credential = await navigator.credentials.create({ publicKey });

        // 4. Serializar respuesta y enviar al servidor
        const response = {
            id: credential.id,
            type: credential.type,
            rawId: SBOSWebAuthn._bufferToB64url(credential.rawId),
            response: {
                clientDataJSON: SBOSWebAuthn._bufferToB64url(credential.response.clientDataJSON),
                attestationObject: SBOSWebAuthn._bufferToB64url(credential.response.attestationObject),
            },
        };

        // 5. Verificar registro con bAuth
        const result = await this._rpc('bauth.webauthn.verify_registration', {
            state: challenge.state,
            response: JSON.stringify(response),
        });

        return {
            registered: result.registered,
            credentialId: credential.id,
            userVerified: credential.response.userVerified || false,
        };
    }

    // ── Authentication (Passkey Login) ─────────────────────

    /**
     * Autentica con una passkey existente.
     * @returns {Object} auth result
     */
    async authenticate() {
        // 1. Obtener challenge del servidor
        const challenge = await this._rpc('bauth.webauthn.authenticate', {});

        // 2. Convertir a formato WebAuthn API
        const publicKey = {
            challenge: SBOSWebAuthn._b64urlToBuffer(challenge.publicKey.challenge),
            rpId: challenge.publicKey.rpId || this.rpId,
            userVerification: challenge.publicKey.userVerification || this.userVerification,
            timeout: challenge.publicKey.timeout || this.timeout,
        };

        // 3. Llamar a la API del navegador
        const credential = await navigator.credentials.get({ publicKey });

        // 4. Serializar respuesta
        const response = {
            id: credential.id,
            type: credential.type,
            rawId: SBOSWebAuthn._bufferToB64url(credential.rawId),
            response: {
                clientDataJSON: SBOSWebAuthn._bufferToB64url(credential.response.clientDataJSON),
                authenticatorData: SBOSWebAuthn._bufferToB64url(credential.response.authenticatorData),
                signature: SBOSWebAuthn._bufferToB64url(credential.response.signature),
                userHandle: credential.response.userHandle
                    ? SBOSWebAuthn._bufferToB64url(credential.response.userHandle) : null,
            },
        };

        // 5. Verificar autenticacion con bAuth
        const result = await this._rpc('bauth.webauthn.verify_authentication', {
            state: challenge.state,
            response: JSON.stringify(response),
        });

        return {
            authenticated: result.authenticated,
            credentialId: credential.id,
            userVerified: credential.response.userVerified || false,
        };
    }

    // ── Check browser support ─────────────────────────────

    static isSupported() {
        return window.PublicKeyCredential !== undefined
            && typeof window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable === 'function';
    }

    static async isPlatformAuthAvailable() {
        if (!SBOSWebAuthn.isSupported()) return false;
        return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    }
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { SBOSWebAuthn };
}
