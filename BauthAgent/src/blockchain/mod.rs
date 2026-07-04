//! bauth::blockchain — D12 Blockchain Integration (B29)
//!
//! AnchorClient: interactúa con AuditAnchor.sol en Arbitrum One.
//! PureAnchor: backend sin dependencias para tests unitarios.
//! EthersAnchor: backend real con ethers-rs para testnet/producción.

pub mod anchor;
pub mod settlement;
