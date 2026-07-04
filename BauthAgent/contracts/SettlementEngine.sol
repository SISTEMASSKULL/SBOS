// SPDX-License-Identifier: UNLICENSED
// ============================================================
// SettlementEngine.sol — B29.T10 · SBOS D12 Variante B
//
// Contrato inteligente para liquidación on-chain en red
// Besu QBFT privada. Cuentas, transferencias, congelación.
//
// Solidity 0.8.26 · Besu QBFT · Keccak-256
// ============================================================
pragma solidity ^0.8.26;

contract SettlementEngine {
    address public owner;

    struct Account {
        address accountAddr;
        uint256 balance;
        bool frozen;
        uint256 createdAt;
        uint256 lastActivity;
    }

    struct Settlement {
        bytes32 settlementId;
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        bool executed;
    }

    mapping(address => Account) public accounts;
    mapping(bytes32 => Settlement) public settlements;
    mapping(bytes32 => bool) public executedSettlements; // anti-replay

    uint256 public accountCount;
    uint256 public settlementCount;

    event AccountRegistered(address indexed accountAddr, uint256 timestamp);
    event AccountFrozen(address indexed accountAddr, uint256 timestamp);
    event AccountUnfrozen(address indexed accountAddr, uint256 timestamp);
    event SettlementExecuted(
        bytes32 indexed settlementId, address indexed from,
        address indexed to, uint256 amount, uint256 timestamp
    );
    event OwnershipTransferred(address indexed prev, address indexed next);

    modifier onlyOwner() {
        require(msg.sender == owner, "SettlementEngine: solo propietario");
        _;
    }

    modifier accountNotFrozen(address addr) {
        require(!accounts[addr].frozen, "SettlementEngine: cuenta congelada");
        _;
    }

    constructor() { owner = msg.sender; }

    /// Registra una nueva cuenta on-chain (llamado por bAuth al dar de alta usuario).
    function registerAccount(address accountAddr) external onlyOwner {
        require(accounts[accountAddr].createdAt == 0, "cuenta ya existe");
        accounts[accountAddr] = Account(accountAddr, 0, false, block.timestamp, block.timestamp);
        accountCount++;
        emit AccountRegistered(accountAddr, block.timestamp);
    }

    /// Ejecuta una liquidación: transfiere amount de from a to.
    function settle(bytes32 settlementId, address from, address to, uint256 amount)
        external onlyOwner accountNotFrozen(from) accountNotFrozen(to)
    {
        require(!executedSettlements[settlementId], "settlementId ya ejecutado");
        require(amount > 0, "monto debe ser > 0");
        require(from != to, "from y to no pueden ser iguales");
        require(accounts[from].createdAt > 0, "cuenta from no existe");
        require(accounts[to].createdAt > 0, "cuenta to no existe");
        require(accounts[from].balance >= amount, "saldo insuficiente");

        accounts[from].balance -= amount;
        accounts[to].balance += amount;
        accounts[from].lastActivity = block.timestamp;
        accounts[to].lastActivity = block.timestamp;

        settlements[settlementId] = Settlement(
            settlementId, from, to, amount, block.timestamp, block.number, true
        );
        executedSettlements[settlementId] = true;
        settlementCount++;

        emit SettlementExecuted(settlementId, from, to, amount, block.timestamp);
    }

    function freezeAccount(address accountAddr) external onlyOwner {
        require(accounts[accountAddr].createdAt > 0, "cuenta no existe");
        require(!accounts[accountAddr].frozen, "ya esta congelada");
        accounts[accountAddr].frozen = true;
        emit AccountFrozen(accountAddr, block.timestamp);
    }

    function unfreezeAccount(address accountAddr) external onlyOwner {
        require(accounts[accountAddr].createdAt > 0, "cuenta no existe");
        require(accounts[accountAddr].frozen, "no esta congelada");
        accounts[accountAddr].frozen = false;
        emit AccountUnfrozen(accountAddr, block.timestamp);
    }

    function balanceOf(address accountAddr) external view returns (uint256) {
        return accounts[accountAddr].balance;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner no puede ser 0");
        address prev = owner; owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }
}
