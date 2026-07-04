// ============================================================
// bauth::domain::merkle — B29.T06 Merkle Tree Engine (RFC 6962)
//
// Construye árbol binario Merkle con domain separation:
//   0x00 || data  → leaf hash
//   0x01 || left || right → node hash
//
// Algoritmo: Keccak-256 (padding original Ethereum, ≠ NIST SHA3-256).
// Soporta lotes de hasta 1M eventos.
// Genera Merkle proofs verificables offline.
// ============================================================
#![allow(dead_code)]
use sha3::{Digest, Keccak256};

const LEAF_PREFIX: u8 = 0x00;
const NODE_PREFIX: u8 = 0x01;

/// Hash de una hoja Merkle (evento de auditoría).
pub fn leaf_hash(data: &[u8]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update([LEAF_PREFIX]);
    hasher.update(data);
    hasher.finalize().into()
}

/// Hash de un nodo interno (combinación de dos hijos).
pub fn node_hash(left: &[u8; 32], right: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Keccak256::new();
    hasher.update([NODE_PREFIX]);
    hasher.update(left);
    hasher.update(right);
    hasher.finalize().into()
}

/// Árbol Merkle con root y proofs.
#[derive(Debug, Clone)]
pub struct MerkleTree {
    pub root: [u8; 32],
    pub leaves: Vec<[u8; 32]>,
    pub depth: usize,
}

impl MerkleTree {
    /// Construye un árbol Merkle desde datos crudos.
    /// `items` son los eventos a anclar (máx 1M).
    pub fn build(items: &[Vec<u8>]) -> Self {
        let leaves: Vec<[u8; 32]> = items.iter().map(|d| leaf_hash(d)).collect();
        let depth = if leaves.is_empty() { 0 } else { (leaves.len() as f64).log2().ceil() as usize };
        let root = Self::compute_root(&leaves);
        MerkleTree { root, leaves, depth }
    }

    /// Genera una prueba Merkle para una hoja específica.
    pub fn proof(&self, leaf_index: usize) -> Option<MerkleProof> {
        if leaf_index >= self.leaves.len() { return None; }
        let mut proof_hashes = Vec::new();
        let mut idx = leaf_index;
        let mut level: Vec<[u8; 32]> = self.leaves.clone();

        while level.len() > 1 {
            let pair_start = (idx / 2) * 2;
            let sibling_idx = if idx % 2 == 0 { pair_start + 1 } else { pair_start };

            if sibling_idx < level.len() {
                // sibling_idx > idx → sibling is to the RIGHT
                proof_hashes.push((sibling_idx > idx, level[sibling_idx]));
            } else {
                // Odd number: last node pairs with itself → sibling is itself
                proof_hashes.push((false, level[idx]));
            }
            idx /= 2;
            level = Self::next_level(&level);
        }

        Some(MerkleProof {
            leaf_index,
            leaf_hash: self.leaves[leaf_index],
            proof_hashes,
            root: self.root,
        })
    }

    /// Verifica una prueba Merkle reconstruyendo la raíz.
    pub fn verify(proof: &MerkleProof) -> bool {
        let mut hash = proof.leaf_hash;
        for (is_right_sibling, sibling_hash) in &proof.proof_hashes {
            hash = if *is_right_sibling {
                node_hash(&hash, sibling_hash)
            } else {
                node_hash(sibling_hash, &hash)
            };
        }
        hash == proof.root
    }

    fn compute_root(leaves: &[[u8; 32]]) -> [u8; 32] {
        if leaves.is_empty() {
            return [0u8; 32];
        }
        let mut level = leaves.to_vec();
        while level.len() > 1 {
            level = Self::next_level(&level);
        }
        level[0]
    }

    fn next_level(level: &[[u8; 32]]) -> Vec<[u8; 32]> {
        level.chunks(2).map(|chunk| {
            let left = chunk[0];
            let right = if chunk.len() > 1 { chunk[1] } else { chunk[0] };
            node_hash(&left, &right)
        }).collect()
    }
}

/// Prueba Merkle verificable offline.
#[derive(Debug, Clone)]
pub struct MerkleProof {
    pub leaf_index: usize,
    pub leaf_hash: [u8; 32],
    /// (is_right_sibling, hash)
    pub proof_hashes: Vec<(bool, [u8; 32])>,
    pub root: [u8; 32],
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_tree() {
        let tree = MerkleTree::build(&[]);
        assert_eq!(tree.root, [0u8; 32]);
        assert_eq!(tree.depth, 0);
    }

    #[test]
    fn test_single_leaf() {
        let tree = MerkleTree::build(&[b"evento-1".to_vec()]);
        assert_ne!(tree.root, [0u8; 32]);
        let proof = tree.proof(0).unwrap();
        assert!(MerkleTree::verify(&proof));
    }

    #[test]
    fn test_two_leaves() {
        let tree = MerkleTree::build(&[b"a".to_vec(), b"b".to_vec()]);
        assert_eq!(tree.leaves.len(), 2);
        let p0 = tree.proof(0).unwrap();
        let p1 = tree.proof(1).unwrap();
        assert!(MerkleTree::verify(&p0));
        assert!(MerkleTree::verify(&p1));
        assert_eq!(p0.root, p1.root);
    }

    #[test]
    fn test_odd_leaves() {
        let tree = MerkleTree::build(&[b"a".to_vec(), b"b".to_vec(), b"c".to_vec()]);
        // 3 hojas → a+b=ab, c+c=cc, ab+cc=root
        for i in 0..3 {
            let proof = tree.proof(i).unwrap();
            assert!(MerkleTree::verify(&proof), "proof {} failed", i);
        }
    }

    #[test]
    fn test_100_leaves() {
        let items: Vec<Vec<u8>> = (0..100).map(|i| format!("event-{}", i).into_bytes()).collect();
        let tree = MerkleTree::build(&items);
        for i in 0..100 {
            let proof = tree.proof(i).unwrap();
            assert!(MerkleTree::verify(&proof), "proof {} failed", i);
        }
    }

    #[test]
    fn test_domain_separation() {
        // leaf y node deben producir hashes diferentes incluso con mismo input
        let data = b"mismo dato";
        let lh = leaf_hash(data);
        let nh = node_hash(&lh, &lh);
        assert_ne!(lh, nh, "leaf hash != node hash (domain separation)");
    }

    #[test]
    fn test_tamper_detection() {
        let tree = MerkleTree::build(&[b"original".to_vec()]);
        let mut proof = tree.proof(0).unwrap();
        proof.leaf_hash = leaf_hash(b"tampered");
        assert!(!MerkleTree::verify(&proof), "proof alterada debe fallar");
    }

    #[test]
    fn test_batch_size_1000() {
        let items: Vec<Vec<u8>> = (0..1000).map(|i| format!("batch-event-{:04}", i).into_bytes()).collect();
        let tree = MerkleTree::build(&items);
        assert_eq!(tree.leaves.len(), 1000);
        assert!(tree.depth >= 10, "1000 leaves needs depth >= 10");
        // Verificar 10 proofs aleatorias
        for idx in [0, 1, 42, 99, 255, 500, 666, 777, 998, 999] {
            let proof = tree.proof(idx).unwrap();
            assert!(MerkleTree::verify(&proof), "proof at {} failed", idx);
        }
    }
}
