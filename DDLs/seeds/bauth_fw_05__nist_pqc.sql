INSERT INTO bauth.framework_raw (source_name, content) VALUES (
  'nist_pqc_2025',
  '{
    "nist_pqc_standardization": {
      "finalized_standards_2024": {
        "fips_203": {"algorithm": "ML-KEM", "former_name": "CRYSTALS-Kyber", "purpose": "Key Encapsulation Mechanism (KEM)", "status": "final"},
        "fips_204": {"algorithm": "ML-DSA", "former_name": "CRYSTALS-Dilithium", "purpose": "Digital Signature Algorithm (primary)", "status": "final"},
        "fips_205": {"algorithm": "SLH-DSA", "former_name": "SPHINCS+", "purpose": "Stateless Hash-Based Digital Signature (backup)", "status": "final"}
      },
      "in_progress": {
        "fips_206": {"algorithm": "FN-DSA", "former_name": "FALCON", "purpose": "Compact lattice-based signature", "draft_released": "2024-Q4", "final_expected": "2026-2027"},
        "hqc": {"algorithm": "HQC", "full_name": "Hamming Quasi-Cyclic", "purpose": "Backup KEM (code-based)", "selected": "2025-03", "draft_expected": "2026-Q1", "final_expected": "2027"}
      },
      "migration_timeline": {
        "112bit_deprecated": "2030",
        "112bit_disallowed": "2035",
        "128bit_disallowed": "2035",
        "standard_ref": "NIST IR 8547 (Transition to PQC Standards)",
        "iana_cose_pqc": "2025-04",
        "description": "IANA added PQC algorithms to COSE codelist enabling quantum-safe FIDO2 passkeys"
      },
      "hybrid_mode": {
        "enabled": true,
        "classical_fallback": true,
        "ietf_standards": ["TLS PQC hybrid", "SSH PQC hybrid", "IPSec PQC hybrid"]
      },
      "hardware_acceleration": {
        "intel_cpu_instructions": "in development",
        "arm_cryptocell": "updated for PQC",
        "expected": "2026-2027"
      }
    }
  }'::jsonb
);
