;; Achievement System - Core Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-invalid-achievement (err u102))
(define-constant err-not-claimed (err u103))
(define-constant err-no-reward (err u104))

;; Define tiers
(define-constant TIER-BRONZE u1)
(define-constant TIER-SILVER u2)
(define-constant TIER-GOLD u3)


;; Data Variables
(define-map achievements
    { achievement-id: uint }
    { 
        name: (string-ascii 50),
        description: (string-ascii 200),
        points: uint
    }
)

(define-map player-achievements
    { player: principal, achievement-id: uint }
    { claimed: bool, claimed-at: uint }
)

;; Public Functions
(define-public (add-achievement (achievement-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set achievements
            { achievement-id: achievement-id }
            { 
                name: name,
                description: description,
                points: points
            }
        ))
    )
)

(define-public (claim-achievement (achievement-id uint))
    (let
        (
            (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-invalid-achievement))
            (existing-claim (map-get? player-achievements { player: tx-sender, achievement-id: achievement-id }))
        )
        (asserts! (is-none existing-claim) err-already-claimed)
        (ok (map-set player-achievements
            { player: tx-sender, achievement-id: achievement-id }
            { claimed: true, claimed-at: stacks-block-height }
        ))
    )
)

;; Read-only Functions
(define-read-only (get-achievement (achievement-id uint))
    (map-get? achievements { achievement-id: achievement-id })
)

(define-read-only (has-achievement (player principal) (achievement-id uint))
    (map-get? player-achievements { player: player, achievement-id: achievement-id })
)




;; Add this map to track total points
(define-map player-total-points 
    { player: principal }
    { total-points: uint }
)

;; Add this function to update points when claiming achievement
(define-public (update-player-points (points uint))
    (let (
        (current-points (default-to { total-points: u0 } 
            (map-get? player-total-points { player: tx-sender })))
    )
    (ok (map-set player-total-points
        { player: tx-sender }
        { total-points: (+ points (get total-points current-points)) }
    )))
)

;; Read player points
(define-read-only (get-player-points (player principal))
    (map-get? player-total-points { player: player })
)



;; Add category mapping
(define-map achievement-categories
    { category-id: uint }
    { name: (string-ascii 50) }
)


;; Function to add categories
(define-public (add-category (category-id uint) (name (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set achievement-categories
            { category-id: category-id }
            { name: name }
        ))
    )
)



;; Progress tracking map
(define-map achievement-progress
    { player: principal, achievement-id: uint }
    { current-progress: uint, target: uint }
)

;; Update progress function
(define-public (update-achievement-progress (achievement-id uint) (progress uint))
    (let (
        (current (default-to { current-progress: u0, target: u100 }
            (map-get? achievement-progress { player: tx-sender, achievement-id: achievement-id })))
    )
    (ok (map-set achievement-progress
        { player: tx-sender, achievement-id: achievement-id }
        { current-progress: (+ progress (get current-progress current)), target: (get target current) }
    )))
)


;; Rewards mapping
(define-map achievement-rewards
    { achievement-id: uint }
    { reward-amount: uint }
)

;; Function to claim rewards
(define-public (claim-achievement-reward (achievement-id uint))
    (let (
        (achievement-claim (unwrap! (map-get? player-achievements 
            { player: tx-sender, achievement-id: achievement-id }) err-not-claimed))
        (reward (unwrap! (map-get? achievement-rewards 
            { achievement-id: achievement-id }) err-no-reward))
    )
    (ok true))
)


;; Streak tracking
(define-map player-streaks
    { player: principal }
    { current-streak: uint, last-claim-height: uint }
)

;; Update streak function
(define-public (update-streak)
    (let (
        (current-data (default-to { current-streak: u0, last-claim-height: u0 }
            (map-get? player-streaks { player: tx-sender })))
        (current-height stacks-block-height)
    )
    (ok (map-set player-streaks
        { player: tx-sender }
        { 
            current-streak: (+ (get current-streak current-data) u1),
            last-claim-height: current-height 
        }
    )))
)
