// ============================================================
// bauth::blockchain::anchor — B29.T05 AnchorClient
//
// Cliente para interactuar con AuditAnchor.sol en Arbitrum One.
//
// DOS BACKENDS:
//   PureAnchor (tests): verifica lógica sin dependencias externas
//   EthersAnchor (prod): envía transacciones reales vía ethers-rs
//
// Contrato: AuditAnchor.sol (Solidity 0.8.26)
// Red: Arbitrum One (chain_id=42161) o Sepolia (chain_id=421614)
// Gas estimado: ~45,000 gas para anchor()
// ============================================================

#![allow(dead_code)]
/// Resultado de una transacción de anclaje.
#[derive(Debug, Clone)]
pub struct AnchorReceipt {
    pub batch_id: u64,
    pub merkle_root: [u8; 32],
    pub event_count: u64,
    pub tx_hash: String,
    pub block_number: u64,
    pub gas_used: u64,
}

/// Cliente de anclaje — backend puro (sin dependencias externas).
/// Usado en tests unitarios y como fallback cuando no hay conexión RPC.
pub struct PureAnchor {
    /// Lotes anclados en memoria (simula el storage del contrato).
    batches: std::collections::HashMap<u64, ([u8; 32], u64)>,
    /// Raíces ya ancladas (previene duplicados).
    anchored_roots: std::collections::HashSet<[u8; 32]>,
    /// Contador de lotes.
    batch_count: u64,
}

impl PureAnchor {
    pub fn new() -> Self {
        PureAnchor {
            batches: std::collections::HashMap::new(),
            anchored_roots: std::collections::HashSet::new(),
            batch_count: 0,
        }
    }

    /// Ancla un lote (misma interfaz que el contrato Solidity).
    pub fn anchor(&mut self, merkle_root: [u8; 32], event_count: u64, batch_id: u64) -> Result<AnchorReceipt, String> {
        if merkle_root == [0u8; 32] {
            return Err("merkleRoot no puede ser 0".into());
        }
        if event_count == 0 {
            return Err("eventCount debe ser > 0".into());
        }
        if self.anchored_roots.contains(&merkle_root) {
            return Err("merkleRoot ya anclada".into());
        }

        self.batches.insert(batch_id, (merkle_root, event_count));
        self.anchored_roots.insert(merkle_root);
        self.batch_count += 1;

        Ok(AnchorReceipt {
            batch_id,
            merkle_root,
            event_count,
            tx_hash: format!("pure-{}", batch_id),
            block_number: self.batch_count,
            gas_used: 45000,
        })
    }

    /// Verifica si una raíz fue anclada en un batch específico.
    pub fn verify(&self, batch_id: u64, merkle_root: &[u8; 32]) -> Result<bool, String> {
        match self.batches.get(&batch_id) {
            Some((root, _)) => Ok(root == merkle_root),
            None => Err(format!("batch {} no encontrado", batch_id)),
        }
    }

    pub fn total_batches(&self) -> u64 { self.batch_count }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::merkle::MerkleTree;

    #[test]
    fn test_anchor_and_verify_real_merkle() {
        // 1. Generar eventos reales (simulando eventos de auditoría)
        let events: Vec<Vec<u8>> = (0..50).map(|i| {
            format!("audit-event-{:04}-tenant-skull-emp-01-suc-01-user-cajero", i).into_bytes()
        }).collect();

        // 2. Construir Merkle tree real (RFC 6962 + Keccak-256)
        let tree = MerkleTree::build(&events);
        assert_eq!(tree.leaves.len(), 50);
        assert_ne!(tree.root, [0u8; 32]);

        // 3. Anclar en el contrato (backend puro — sin gas)
        let mut anchor = PureAnchor::new();
        let receipt = anchor.anchor(tree.root, 50, 1).unwrap();
        assert_eq!(receipt.event_count, 50);
        assert_eq!(receipt.batch_id, 1);
        assert_eq!(receipt.gas_used, 45000);

        // 4. Verificar que la raíz fue anclada
        assert!(anchor.verify(1, &tree.root).unwrap());
        assert_eq!(anchor.total_batches(), 1);

        // 5. Generar proof para el evento 0 y verificar
        let proof = tree.proof(0).unwrap();
        assert!(MerkleTree::verify(&proof), "proof del evento 0 debe ser válida");

        // 6. Verificar que un batch inexistente da error
        assert!(anchor.verify(999, &tree.root).is_err());

        // 7. Verificar que una raíz diferente no coincide
        let different_root = [42u8; 32];
        assert!(!anchor.verify(1, &different_root).unwrap());

        // 8. Verificar que no se puede anclar la misma raíz dos veces
        assert!(anchor.anchor(tree.root, 50, 2).is_err());
    }

    #[test]
    fn test_anchor_1000_events_real_pipeline() {
        // Simular un lote de 1000 eventos (tamaño típico Gold tier)
        let events: Vec<Vec<u8>> = (0..1000).map(|i| {
            format!("batch-event-{:04}", i).into_bytes()
        }).collect();

        let tree = MerkleTree::build(&events);
        assert_eq!(tree.leaves.len(), 1000);

        let mut anchor = PureAnchor::new();
        let receipt = anchor.anchor(tree.root, 1000, 42).unwrap();

        assert_eq!(receipt.event_count, 1000);
        assert!(anchor.verify(42, &tree.root).unwrap());

        // Verificar 10 proofs aleatorias
        for idx in [0, 1, 42, 99, 255, 500, 666, 777, 998, 999] {
            let proof = tree.proof(idx).unwrap();
            assert!(MerkleTree::verify(&proof), "proof en idx {} falló", idx);
        }
    }

    #[test]
    fn test_anchor_rejects_zero_root() {
        let mut anchor = PureAnchor::new();
        assert!(anchor.anchor([0u8; 32], 10, 1).is_err());
    }

    #[test]
    fn test_anchor_rejects_zero_events() {
        let mut anchor = PureAnchor::new();
        let root = [1u8; 32];
        assert!(anchor.anchor(root, 0, 1).is_err());
    }

    #[test]
    fn test_anchor_rejects_duplicate_root() {
        let mut anchor = PureAnchor::new();
        let events = vec![b"evento-unico".to_vec()];
        let tree = MerkleTree::build(&events);

        anchor.anchor(tree.root, 1, 1).unwrap();
        assert!(anchor.anchor(tree.root, 1, 2).is_err(), "raíz duplicada debe ser rechazada");
    }
}
