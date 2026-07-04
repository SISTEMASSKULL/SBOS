// SPDX-License-Identifier: UNLICENSED
// ============================================================
// AuditAnchor.sol — B29.T04 · SBOS D12 Variante A
//
// Contrato inteligente para anclaje verificable de lotes
// Merkle en Arbitrum One. Optimizado para gas (~45K gas).
//
// Funciones:
//   anchor(bytes32, uint256, uint256) → anclar lote
//   verify(uint256, bytes32) → verificar si raíz está anclada
//   batchCount() → número total de lotes anclados
//
// Solidity 0.8.26 · Arbitrum One · Keccak-256
// ============================================================
pragma solidity ^0.8.26;

contract AuditAnchor {
    /// Propietario del contrato (bAuth deployer).
    address public owner;

    /// Contador de lotes anclados.
    uint256 public batchCount;

    /// Estructura de un lote anclado.
    struct AnchoredBatch {
        bytes32 merkleRoot;
        uint256 eventCount;
        uint256 blockNumber;
        uint256 timestamp;
        address anchoredBy;
    }

    /// Lotes anclados indexados por batchId.
    mapping(uint256 => AnchoredBatch) public batches;

    /// Raíz Merkle → true si ya fue anclada (previene duplicados).
    mapping(bytes32 => bool) public anchoredRoots;

    /// Evento emitido al anclar un lote.
    event BatchAnchored(
        uint256 indexed batchId,
        bytes32 indexed merkleRoot,
        uint256 eventCount,
        uint256 timestamp,
        address anchoredBy
    );

    /// Evento emitido al transferir la propiedad.
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "AuditAnchor: solo el propietario");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// Ancla un lote Merkle en la blockchain.
    /// @param merkleRoot Raíz Merkle del lote (32 bytes, Keccak-256).
    /// @param eventCount Número de eventos en el lote.
    /// @param batchId Identificador del lote (enviado por bAuth).
    function anchor(
        bytes32 merkleRoot,
        uint256 eventCount,
        uint256 batchId
    ) external onlyOwner {
        require(merkleRoot != bytes32(0), "AuditAnchor: merkleRoot no puede ser 0");
        require(eventCount > 0, "AuditAnchor: eventCount debe ser > 0");
        require(!anchoredRoots[merkleRoot], "AuditAnchor: merkleRoot ya anclada");

        batches[batchId] = AnchoredBatch({
            merkleRoot: merkleRoot,
            eventCount: eventCount,
            blockNumber: block.number,
            timestamp: block.timestamp,
            anchoredBy: msg.sender
        });

        anchoredRoots[merkleRoot] = true;
        batchCount++;

        emit BatchAnchored(batchId, merkleRoot, eventCount, block.timestamp, msg.sender);
    }

    /// Verifica si una raíz Merkle fue anclada en un batch específico.
    /// @param batchId Identificador del lote a verificar.
    /// @param merkleRoot Raíz Merkle a verificar.
    /// @return true si la raíz coincide con el lote anclado.
    function verify(
        uint256 batchId,
        bytes32 merkleRoot
    ) external view returns (bool) {
        AnchoredBatch storage batch = batches[batchId];
        require(batch.timestamp > 0, "AuditAnchor: batch no encontrado");
        return batch.merkleRoot == merkleRoot;
    }

    /// Transfiere la propiedad del contrato.
    /// @param newOwner Dirección del nuevo propietario.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AuditAnchor: nuevo owner no puede ser 0");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
