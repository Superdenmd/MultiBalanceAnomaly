# MultiBalanceAnomaly
balance-anomaly-sergeant-trap
# Objective 
"This trap detects abnormal balance changes (≥0.01%) across three critical Ethereum addresses, signaling potential large transfers or suspicious activity."
# Problem
Ethereum wallets involved in DAO treasury management, DeFi protocol control, or asset distribution are expected to maintain a stable balance. Any sudden or unexplained change — whether a decrease or increase — may indicate a compromise, operator error, or malicious behavior
Solution: This trap monitors ETH balance changes on selected wallets on a per-block basis. If even a slight deviation is detected, it triggers an immediate response — enabling early detection and mitigation of potential threats.
# Trap Logic Summary
trap contract: MultiBalanceSpikeTrap.sol
Pay attention to this string "address public constant target =
0x3F63ae7cb6EF734387AA8223CfFa7D4e1a075847,
0x753b1fcA5588706492Cd89C7d2c287dB236Be03d,
0xc517F2CF2858ABee3D0E2a3F9FD87f26A4d5646D
these are arbitrary addresses.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}

contract MultiBalanceSpikeTrap is ITrap {
    address[3] public targets = [
        0x3F63ae7cb6EF734387AA8223CfFa7D4e1a075847,
        0x753b1fcA5588706492Cd89C7d2c287dB236Be03d,
        0xc517F2CF2858ABee3D0E2a3F9FD87f26A4d5646D
    ];

    uint256 public constant THRESHOLD_BASIS_POINTS = 1;
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;
    uint256 public constant MIN_DIFF_WEI = 1 ether;

    function collect() external view override returns (bytes memory) {
        uint256[] memory balances = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            balances[i] = targets[i].balance;
        }
        return abi.encode(balances);
    }

    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) return (false, abi.encode("Insufficient data"));

        uint256[] memory current = abi.decode(data[0], (uint256[]));
        uint256[] memory previous = abi.decode(data[1], (uint256[]));

        if (current.length != previous.length || current.length != 3) {
            return (false, abi.encode("Mismatched array lengths"));
        }

        for (uint256 i = 0; i < 3; i++) {
            uint256 oldBal = previous[i];
            uint256 newBal = current[i];

            if (oldBal == 0) continue;

            uint256 diff = newBal > oldBal ? newBal - oldBal : oldBal - newBal;
            if (diff < MIN_DIFF_WEI) continue;

            uint256 changeBp = (diff * BASIS_POINTS_DIVISOR) / oldBal;
            if (changeBp >= THRESHOLD_BASIS_POINTS) {
                return (true, abi.encode(i, oldBal, newBal));
            }
        }

        return (false, abi.encode("No anomaly detected"));
    }
}

# Response Contract: LogAlertReceiver.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LogAlertReceiver {
    event Alert(string message);

    function logAnomaly(string calldata message) external {
        emit Alert(message);
    }
}
# What It Solves
Identifies unusual ETH movements from tracked wallets

Triggers automated notifications upon anomaly detection

Can plug into on-chain or off-chain automation (e.g., fund lockdown, DAO emergency signals)
# Deployment & Setup Instructions
1. Deploy Contracts (e.g., via Foundry)
   forge create src/MultiBalanceSpikeTrap.sol:MultiBalanceSpikeTrap \
  --rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --private-key 0x...
   forge create src/LogAlertReceiver.sol:LogAlertReceiver \
  --rpc-url https://ethereum-hoodi-rpc.publicnode.com \
  --private-key 0x...
2. Update drosera.toml
   [traps.mytrap]
path = "out/MultiBalanceSpikeTrap.sol/MultiBalanceSpikeTrap.json"
response_contract = "<LogAlertReceiver address>"
response_function = "logAnomaly(string)"
3. Apply changes
   DROSERA_PRIVATE_KEY=0x... drosera apply
# Testing the Trap

Wait for any target address to process a transaction on the Ethereum Hoodi testnet.

Wait until there are no changes in the balance of the controlled addresses.

View Drosera operator logs:

Get ShouldRespond='true' in the logs and on the Drosera dashboard.
# Date & Author
first created: 27.07.2025
# Autor:  d_diacuk && Profit_Nodes
TG: @d_diacuk
Discord: d_diacuk
