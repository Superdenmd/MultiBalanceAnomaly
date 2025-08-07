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


