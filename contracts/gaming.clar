;; Achievement System - Core Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-invalid-achievement (err u102))

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
