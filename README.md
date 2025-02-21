# On-Chain Gaming Achievement System

A Clarity smart contract system for managing and tracking gaming achievements on the Stacks blockchain.

## Contract: gaming.clar

The main contract handles achievement creation, claiming, and verification.

### Functions

#### Public Functions
- `add-achievement`: Creates new achievements (owner only)
  - Parameters: achievement-id, name, description, points
  - Returns: (ok true) on success

- `claim-achievement`: Allows players to claim achievements
  - Parameters: achievement-id
  - Returns: (ok true) on success

#### Read-Only Functions
- `get-achievement`: Retrieves achievement details
  - Parameters: achievement-id
  - Returns: Optional achievement data

- `has-achievement`: Checks if player has claimed an achievement
  - Parameters: player principal, achievement-id
  - Returns: Optional claim status

## Tests: gaming.test.ts

Test suite covering core contract functionality using Vitest and Clarinet.

### Test Cases
1. Achievement Creation
   - Verifies owner can add new achievements
   - Validates achievement data storage

2. Achievement Claiming
   - Tests successful achievement claims
   - Verifies claim status tracking

3. Data Retrieval
   - Tests achievement data retrieval
   - Validates player achievement status checks
