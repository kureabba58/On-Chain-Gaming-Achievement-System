(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-invalid-game (err u501))
(define-constant err-invalid-bridge-achievement (err u502))
(define-constant err-insufficient-achievements (err u503))
(define-constant err-already-claimed (err u504))
(define-constant err-bridge-inactive (err u505))

(define-map registered-games
    { game-id: uint }
    {
        name: (string-ascii 50),
        contract-address: principal,
        active: bool,
        achievement-count: uint
    }
)

(define-map bridge-achievements
    { bridge-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        required-games: (list 10 uint),
        required-achievements-per-game: uint,
        unlock-type: uint,
        reward-multiplier: uint,
        special-bonus: uint,
        active: bool
    }
)

(define-map player-game-achievements
    { player: principal, game-id: uint }
    {
        verified-count: uint,
        last-sync: uint,
        total-points: uint
    }
)

(define-map bridge-claims
    { player: principal, bridge-id: uint }
    {
        claimed: bool,
        claimed-at: uint,
        bonus-awarded: uint
    }
)

(define-map cross-game-bonuses
    { player: principal }
    {
        active-bridges: uint,
        total-bonus-multiplier: uint,
        special-privileges: uint
    }
)

(define-constant BRIDGE-TYPE-AND u1)
(define-constant BRIDGE-TYPE-OR u2)
(define-constant BRIDGE-TYPE-MILESTONE u3)

(define-public (register-game (game-id uint) (name (string-ascii 50)) (contract-address principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set registered-games
            { game-id: game-id }
            {
                name: name,
                contract-address: contract-address,
                active: true,
                achievement-count: u0
            }
        ))
    )
)

(define-public (create-bridge-achievement (bridge-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (required-games (list 10 uint)) (required-achievements-per-game uint) (unlock-type uint) (reward-multiplier uint) (special-bonus uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set bridge-achievements
            { bridge-id: bridge-id }
            {
                name: name,
                description: description,
                required-games: required-games,
                required-achievements-per-game: required-achievements-per-game,
                unlock-type: unlock-type,
                reward-multiplier: reward-multiplier,
                special-bonus: special-bonus,
                active: true
            }
        ))
    )
)

(define-public (sync-player-achievements (game-id uint) (achievement-count uint) (total-points uint))
    (let
        (
            (game-data (unwrap! (map-get? registered-games { game-id: game-id }) err-invalid-game))
            (current-data (default-to { verified-count: u0, last-sync: u0, total-points: u0 }
                (map-get? player-game-achievements { player: tx-sender, game-id: game-id })))
        )
        (asserts! (get active game-data) err-invalid-game)
        (ok (map-set player-game-achievements
            { player: tx-sender, game-id: game-id }
            {
                verified-count: achievement-count,
                last-sync: stacks-block-height,
                total-points: total-points
            }
        ))
    )
)

(define-public (claim-bridge-achievement (bridge-id uint))
    (let
        (
            (bridge-data (unwrap! (map-get? bridge-achievements { bridge-id: bridge-id }) err-invalid-bridge-achievement))
            (required-games (get required-games bridge-data))
            (required-count (get required-achievements-per-game bridge-data))
            (unlock-type (get unlock-type bridge-data))
            (reward-multiplier (get reward-multiplier bridge-data))
            (special-bonus (get special-bonus bridge-data))
            (existing-claim (map-get? bridge-claims { player: tx-sender, bridge-id: bridge-id }))
            (current-bonuses (default-to { active-bridges: u0, total-bonus-multiplier: u100, special-privileges: u0 }
                (map-get? cross-game-bonuses { player: tx-sender })))
        )
        (asserts! (get active bridge-data) err-bridge-inactive)
        (asserts! (is-none existing-claim) err-already-claimed)
        (asserts! (check-bridge-requirements tx-sender required-games required-count unlock-type) err-insufficient-achievements)
        
        (map-set bridge-claims
            { player: tx-sender, bridge-id: bridge-id }
            {
                claimed: true,
                claimed-at: stacks-block-height,
                bonus-awarded: special-bonus
            }
        )
        
        (ok (map-set cross-game-bonuses
            { player: tx-sender }
            {
                active-bridges: (+ (get active-bridges current-bonuses) u1),
                total-bonus-multiplier: (+ (get total-bonus-multiplier current-bonuses) reward-multiplier),
                special-privileges: (+ (get special-privileges current-bonuses) special-bonus)
            }
        ))
    )
)

(define-public (calculate-cross-game-bonus (base-points uint))
    (let
        (
            (player-bonuses (default-to { active-bridges: u0, total-bonus-multiplier: u100, special-privileges: u0 }
                (map-get? cross-game-bonuses { player: tx-sender })))
            (multiplier (get total-bonus-multiplier player-bonuses))
            (privilege-bonus (get special-privileges player-bonuses))
            (final-points (+ (/ (* base-points multiplier) u100) privilege-bonus))
        )
        (ok final-points)
    )
)

(define-public (update-game-achievement-count (game-id uint) (new-count uint))
    (let
        (
            (game-data (unwrap! (map-get? registered-games { game-id: game-id }) err-invalid-game))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set registered-games
            { game-id: game-id }
            (merge game-data { achievement-count: new-count })
        ))
    )
)

(define-public (toggle-game-status (game-id uint))
    (let
        (
            (game-data (unwrap! (map-get? registered-games { game-id: game-id }) err-invalid-game))
            (current-status (get active game-data))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set registered-games
            { game-id: game-id }
            (merge game-data { active: (not current-status) })
        ))
    )
)

(define-public (toggle-bridge-status (bridge-id uint))
    (let
        (
            (bridge-data (unwrap! (map-get? bridge-achievements { bridge-id: bridge-id }) err-invalid-bridge-achievement))
            (current-status (get active bridge-data))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set bridge-achievements
            { bridge-id: bridge-id }
            (merge bridge-data { active: (not current-status) })
        ))
    )
)

(define-private (check-bridge-requirements (player principal) (required-games (list 10 uint)) (required-count uint) (unlock-type uint))
    (if (is-eq unlock-type BRIDGE-TYPE-AND)
        (check-all-games-requirement player required-games required-count)
        (if (is-eq unlock-type BRIDGE-TYPE-OR)
            (check-any-game-requirement player required-games required-count)
            (check-milestone-requirement player required-games required-count)
        )
    )
)

(define-private (check-all-games-requirement (player principal) (required-games (list 10 uint)) (required-count uint))
    (fold check-single-game-and required-games true)
)

(define-private (check-single-game-and (game-id uint) (acc bool))
    (if acc
        (match (map-get? player-game-achievements { player: tx-sender, game-id: game-id })
            game-data (>= (get verified-count game-data) u5)
            false
        )
        false
    )
)

(define-private (check-any-game-requirement (player principal) (required-games (list 10 uint)) (required-count uint))
    (> (fold count-qualifying-games required-games u0) u0)
)

(define-private (count-qualifying-games (game-id uint) (acc uint))
    (match (map-get? player-game-achievements { player: tx-sender, game-id: game-id })
        game-data 
            (if (>= (get verified-count game-data) u5)
                (+ acc u1)
                acc
            )
        acc
    )
)

(define-private (check-milestone-requirement (player principal) (required-games (list 10 uint)) (required-count uint))
    (>= (fold sum-total-achievements required-games u0) (* (len required-games) required-count))
)

(define-private (sum-total-achievements (game-id uint) (acc uint))
    (match (map-get? player-game-achievements { player: tx-sender, game-id: game-id })
        game-data (+ acc (get verified-count game-data))
        acc
    )
)

(define-read-only (get-registered-game (game-id uint))
    (map-get? registered-games { game-id: game-id })
)

(define-read-only (get-bridge-achievement (bridge-id uint))
    (map-get? bridge-achievements { bridge-id: bridge-id })
)

(define-read-only (get-player-game-stats (player principal) (game-id uint))
    (map-get? player-game-achievements { player: player, game-id: game-id })
)

(define-read-only (get-bridge-claim (player principal) (bridge-id uint))
    (map-get? bridge-claims { player: player, bridge-id: bridge-id })
)

(define-read-only (get-player-cross-game-bonuses (player principal))
    (map-get? cross-game-bonuses { player: player })
)

(define-read-only (get-player-bridge-eligibility (player principal) (bridge-id uint))
    (let
        (
            (bridge-data (map-get? bridge-achievements { bridge-id: bridge-id }))
            (existing-claim (map-get? bridge-claims { player: player, bridge-id: bridge-id }))
        )
        (match bridge-data
            bridge-info
                (if (is-none existing-claim)
                    (some {
                        eligible: (check-bridge-requirements player 
                            (get required-games bridge-info) 
                            (get required-achievements-per-game bridge-info)
                            (get unlock-type bridge-info)),
                        active: (get active bridge-info)
                    })
                    (some { eligible: false, active: false })
                )
            none
        )
    )
)
