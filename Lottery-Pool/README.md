# Decentralized Lottery Pool Smart Contract

## Overview

A fair and transparent lottery system built on the Stacks blockchain that allows users to purchase tickets, participate in draws, and claim winnings in a fully decentralized manner. The contract features configurable parameters, multiple winners per draw, organizer fees, withdrawal periods, automatic prize distribution, and comprehensive history tracking.

## Features

- **Fair Random Winner Selection**: Uses block-based randomization for transparent winner determination
- **Multiple Winners**: Supports configurable number of winners per lottery round
- **Flexible Configuration**: Customizable ticket prices, lottery duration, and organizer fees
- **Withdrawal Period**: Participants can refund tickets before the withdrawal deadline
- **Automatic Prize Distribution**: Streamlined prize distribution to all winners
- **Comprehensive History**: Tracks participant statistics, round history, and performance analytics
- **Fee Management**: Built-in organizer fee system with maximum rate protection

## Contract Architecture

### State Variables

- `lottery-is-running`: Current lottery status
- `ticket-price-in-microstx`: Cost per ticket in microSTX
- `total-prize-pool`: Accumulated prize money
- `tickets-sold-count`: Number of tickets sold in current round
- `maximum-winner-count`: Number of winners per lottery
- `lottery-closing-block`: Block height when lottery ends
- `withdrawal-deadline-block`: Last block for ticket refunds
- `organizer-fee-rate`: Percentage fee for organizer (max 20%)

### Data Maps

#### Core Lottery Maps
- `participant-ticket-registry`: Maps ticket numbers to participant addresses
- `participant-ticket-balance`: Tracks tickets owned by each participant
- `lottery-winner-registry`: Stores winner information and claim status

#### History and Analytics Maps
- `lottery-history-records`: Complete history of all lottery rounds
- `round-winner-history`: Winner details for each round
- `participant-history`: Overall participant statistics
- `participant-round-participation`: Round-specific participant data

## Functions

### Administrative Functions

#### `initialize-new-lottery`
```clarity
(initialize-new-lottery (duration-blocks uint) (withdrawal-window-blocks uint) 
                       (price-per-ticket uint) (number-of-winners uint) 
                       (commission-percentage uint))
```
**Access**: Contract administrator only
**Purpose**: Starts a new lottery round with specified parameters
**Parameters**:
- `duration-blocks`: Lottery duration in blocks
- `withdrawal-window-blocks`: Withdrawal period in blocks
- `price-per-ticket`: Ticket price in microSTX
- `number-of-winners`: Number of winners for this round
- `commission-percentage`: Organizer fee (0-20%)

#### `finalize-lottery-draw`
```clarity
(finalize-lottery-draw)
```
**Access**: Contract administrator only
**Purpose**: Ends the lottery and calculates prizes
**Requirements**: Must be called after lottery closing block

#### `determine-lottery-winners`
```clarity
(determine-lottery-winners (randomization-seed uint))
```
**Access**: Contract administrator only
**Purpose**: Selects winners using provided randomization seed
**Requirements**: Lottery must be finalized first

#### `distribute-all-prizes`
```clarity
(distribute-all-prizes)
```
**Access**: Contract administrator only
**Purpose**: Automatically distributes prizes to all winners

### Participant Functions

#### `buy-lottery-ticket`
```clarity
(buy-lottery-ticket)
```
**Access**: Public
**Purpose**: Purchase a lottery ticket
**Requirements**: 
- Lottery must be active
- Sufficient STX balance
- Automatically transfers ticket cost from caller

#### `refund-lottery-tickets`
```clarity
(refund-lottery-tickets (number-of-tickets uint))
```
**Access**: Public
**Purpose**: Refund tickets before withdrawal deadline
**Requirements**:
- Must own the specified number of tickets
- Current block must be before withdrawal deadline

#### `claim-lottery-winnings`
```clarity
(claim-lottery-winnings (winner-position uint))
```
**Access**: Winners only
**Purpose**: Individual prize claiming by winners
**Requirements**:
- Caller must be the registered winner
- Prize not already claimed
- Auto-distribution not yet executed

### Query Functions

#### Basic Status Queries
- `get-ticket-price`: Current ticket price
- `get-total-prize-pool`: Current prize pool amount
- `get-tickets-sold`: Number of tickets sold
- `is-lottery-active`: Lottery running status
- `get-lottery-end-block`: Lottery closing block
- `get-withdrawal-deadline`: Withdrawal deadline block
- `get-commission-rate`: Current organizer fee rate

#### Participant Queries
- `get-participant-ticket-count`: Tickets owned by address
- `get-winner-details`: Winner information by position
- `get-participant-overall-stats`: Complete participant statistics
- `get-participant-round-stats`: Participant stats for specific round
- `calculate-participant-roi`: Return on investment calculation

#### History Queries
- `get-current-round`: Current lottery round number
- `get-total-completed-lotteries`: Total completed lotteries
- `get-lottery-history`: Complete round information
- `get-round-winner`: Winner details for specific round

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-UNAUTHORIZED-ACCESS | Caller not authorized |
| 102 | ERR-LOTTERY-NOT-ACTIVE | Lottery not currently running |
| 103 | ERR-INSUFFICIENT-FUNDS | Insufficient STX balance |
| 104 | ERR-INVALID-TICKET-PRICE | Invalid ticket price specified |
| 105 | ERR-NO-WINNERS-AVAILABLE | No winners available |
| 106 | ERR-NO-TICKETS-OWNED | Insufficient tickets owned |
| 107 | ERR-WITHDRAWAL-DEADLINE-PASSED | Withdrawal period expired |
| 108 | ERR-LOTTERY-STILL-RUNNING | Lottery still in progress |
| 109 | ERR-WINNERS-ALREADY-DETERMINED | Winners already selected |
| 110 | ERR-INVALID-LOTTERY-DURATION | Invalid duration specified |
| 111 | ERR-INVALID-WITHDRAWAL-DURATION | Invalid withdrawal period |
| 112 | ERR-WINNER-ID-NOT-FOUND | Winner position not found |
| 113 | ERR-PRIZES-ALREADY-DISTRIBUTED | Prizes already distributed |
| 114 | ERR-WINNERS-NOT-DETERMINED | Winners not yet selected |
| 115 | ERR-LOTTERY-ROUND-NOT-FOUND | Round not found |

## Usage Flow

### For Administrators

1. **Initialize Lottery**: Call `initialize-new-lottery` with desired parameters
2. **Monitor Sales**: Use query functions to track ticket sales and prize pool
3. **End Lottery**: Call `finalize-lottery-draw` after closing block
4. **Select Winners**: Call `determine-lottery-winners` with random seed
5. **Distribute Prizes**: Call `distribute-all-prizes` or allow individual claiming

### For Participants

1. **Check Status**: Use `is-lottery-active` to confirm lottery is running
2. **Buy Tickets**: Call `buy-lottery-ticket` to purchase tickets
3. **Monitor Holdings**: Use `get-participant-ticket-count` to check tickets owned
4. **Refund if Needed**: Call `refund-lottery-tickets` before withdrawal deadline
5. **Claim Winnings**: Use `claim-lottery-winnings` if selected as winner

## Security Features

- **Access Control**: Administrative functions restricted to contract administrator
- **Balance Verification**: Automatic balance checking before transactions
- **Deadline Enforcement**: Strict enforcement of withdrawal and lottery deadlines
- **Double Spending Prevention**: Prevents multiple claims of same prize
- **Fee Cap**: Maximum 20% organizer fee protection

## Analytics and History

The contract maintains comprehensive analytics including:

- **Participant Statistics**: Total tickets bought, amount spent, winnings, ROI
- **Round History**: Complete details of all completed lotteries
- **Winner Tracking**: Historical winner information across all rounds
- **Performance Metrics**: Return on investment calculations

## Constants and Defaults

- **Maximum Organizer Fee**: 20%
- **Default Ticket Price**: 1,000,000 microSTX (1 STX)
- **Default Organizer Fee**: 5%
- **Contract Administrator**: Set to contract deployer

## Technical Requirements

- **Blockchain**: Stacks blockchain
- **Language**: Clarity smart contract language
- **Token**: STX (Stacks native token)

## Deployment Notes

1. The contract administrator is set to the transaction sender at deployment
2. Default values are configured for immediate testing capability
3. All state variables are properly initialized
4. History tracking begins with the first lottery round