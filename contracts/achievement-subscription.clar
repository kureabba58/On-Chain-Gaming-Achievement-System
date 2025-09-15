;; Achievement Subscription System
;; Allows players to subscribe to notifications about specific achievements

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-already-subscribed (err u801))
(define-constant err-not-subscribed (err u802))
(define-constant err-invalid-achievement (err u803))

;; Player subscriptions to specific achievements
(define-map achievement-subscriptions
    { player: principal, achievement-id: uint }
    { 
        subscribed-at: uint,
        notifications-count: uint
    }
)

;; Notification queue for each player
(define-map player-notifications
    { player: principal, notification-id: uint }
    {
        achievement-id: uint,
        message: (string-ascii 100),
        created-at: uint,
        read: bool
    }
)

;; Notification counter per player
(define-map notification-counters
    { player: principal }
    { next-id: uint }
)

;; Subscribe to achievement notifications
(define-public (subscribe-to-achievement (achievement-id uint))
    ;; (let
    ;;     (
    ;;         ;; (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-invalid-achievement))
    ;;         ;; (existing-claim (map-get? player-achievements { player: tx-sender, achievement-id: achievement-id }))
    ;;     )
    ;;     ;; (asserts! (is-none existing-claim) err-already-claimed)
    ;;     (ok (map-set player-achievements
    ;;         { player: tx-sender, achievement-id: achievement-id }
    ;;         { claimed: true, claimed-at: stacks-block-height }
    ;;     ))
    ;; )
    (ok (map-set achievement-subscriptions
        { player: tx-sender, achievement-id: achievement-id }
        { subscribed-at: stacks-block-height, notifications-count: u0 }
    ))
)

;; Read-only Functions
;; (define-read-only (get-achievement (achievement-id uint))
;;     (ok (map-get? achievements { achievement-id: achievement-id }))
;; )

;; (define-read-only (has-achievement (player principal) (achievement-id uint))
;;     (map-get? player-achievements { player: player, achievement-id: achievement-id })
;; )




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
        (asserts! (is-eq tx-sender contract-owner) (err u101))
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
        (reward (unwrap! (map-get? achievement-rewards 
            { achievement-id: achievement-id }) (err u101)))
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


;; Badge mapping
(define-map player-badges
    { player: principal }
    { current-badge: (string-ascii 50) }
)

;; Set badge based on points
(define-public (update-player-badge (badge (string-ascii 50)))
    (ok (map-set player-badges
        { player: tx-sender }
        { current-badge: badge }
    ))
)

;; Get player badge
(define-read-only (get-player-badge (player principal))
    (map-get? player-badges { player: player })
)


;; Leaderboard map
(define-map leaderboard-rankings
    { rank: uint }
    { player: principal, score: uint }
)

;; Update leaderboard
(define-public (update-leaderboard (rank uint) (score uint))
    (ok (map-set leaderboard-rankings
        { rank: rank }
        { player: tx-sender, score: score }
    ))
)

;; Get rank
(define-read-only (get-rank (rank-position uint))
    (map-get? leaderboard-rankings { rank: rank-position })
)


;; Time-limited achievement map
(define-map limited-time-achievements
    { achievement-id: uint }
    { 
        start-height: uint,
        end-height: uint,
        bonus-points: uint
    }
)

;; Create time-limited achievement
(define-public (create-limited-achievement (achievement-id uint) (duration uint) (bonus uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set limited-time-achievements
            { achievement-id: achievement-id }
            { 
                start-height: stacks-block-height,
                end-height: (+ stacks-block-height duration),
                bonus-points: bonus
            }
        ))
    )
)


;; Combo tracking
(define-map achievement-combos
    { player: principal }
    { 
        combo-count: uint,
        last-achievement-time: uint,
        bonus-multiplier: uint
    }
)

;; Update combo
(define-public (update-combo)
    (let (
        (current-combo (default-to { combo-count: u0, last-achievement-time: u0, bonus-multiplier: u1 }
            (map-get? achievement-combos { player: tx-sender })))
    )
    (ok (map-set achievement-combos
        { player: tx-sender }
        { 
            combo-count: (+ (get combo-count current-combo) u1),
            last-achievement-time: stacks-block-height,
            bonus-multiplier: (+ (get bonus-multiplier current-combo) u1)
        }
    )))
)


;; Shared achievements
(define-map shared-achievements
    { share-id: uint }
    { 
        player: principal,
        achievement-id: uint,
        share-message: (string-ascii 100)
    }
)

;; Share achievement
(define-public (share-achievement (share-id uint) (achievement-id uint) (message (string-ascii 100)))
    (ok (map-set shared-achievements
        { share-id: share-id }
        { 
            player: tx-sender,
            achievement-id: achievement-id,
            share-message: message
        }
    ))
)




;; Daily challenges
(define-map daily-challenges
    { day-height: uint }
    { 
        challenge-id: uint,
        points: uint,
        completed-by: (list 100 principal)
    }
)

;; Create daily challenge
(define-public (set-daily-challenge (challenge-id uint) (points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set daily-challenges
            { day-height: stacks-block-height }
            { 
                challenge-id: challenge-id,
                points: points,
                completed-by: (list)
            }
        ))
    )
)


;; Rarity levels
(define-constant RARITY-COMMON u1)
(define-constant RARITY-RARE u2)
(define-constant RARITY-EPIC u3)
(define-constant RARITY-LEGENDARY u4)

;; Achievement rarity map
(define-map achievement-rarity
    { achievement-id: uint }
    { 
        rarity-level: uint,
        total-claimed: uint,
        max-claims: uint
    }
)

;; Set achievement rarity
(define-public (set-achievement-rarity (achievement-id uint) (rarity uint) (max-claims uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set achievement-rarity
            { achievement-id: achievement-id }
            { 
                rarity-level: rarity,
                total-claimed: u0,
                max-claims: max-claims
            }
        ))
    )
)



(define-map achievement-tiers
    { achievement-id: uint, tier: uint }
    { 
        tier-name: (string-ascii 20),
        points-required: uint,
        bonus-reward: uint
    }
)

(define-map player-achievement-tiers
    { player: principal, achievement-id: uint }
    { current-tier: uint }
)

(define-public (add-achievement-tier (achievement-id uint) (tier uint) (tier-name (string-ascii 20)) (points-required uint) (bonus-reward uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set achievement-tiers
            { achievement-id: achievement-id, tier: tier }
            { 
                tier-name: tier-name,
                points-required: points-required,
                bonus-reward: bonus-reward
            }
        ))
    )
)

(define-public (upgrade-achievement-tier (achievement-id uint))
    (let
        (
            (current-tier-data (default-to { current-tier: u0 } 
                (map-get? player-achievement-tiers { player: tx-sender, achievement-id: achievement-id })))
            (next-tier (+ (get current-tier current-tier-data) u1))
            (next-tier-data (map-get? achievement-tiers { achievement-id: achievement-id, tier: next-tier }))
        )
        (asserts! (is-some next-tier-data) err-invalid-achievement)
        (ok (map-set player-achievement-tiers
            { player: tx-sender, achievement-id: achievement-id }
            { current-tier: next-tier }
        ))
    )
)

(define-read-only (get-achievement-tier (achievement-id uint) (tier uint))
    (map-get? achievement-tiers { achievement-id: achievement-id, tier: tier })
)



(define-constant err-invalid-quest (err u105))
(define-constant err-quest-incomplete (err u106))

(define-map quests
    { quest-id: uint }
    { 
        name: (string-ascii 50),
        description: (string-ascii 200),
        required-achievements: (list 10 uint),
        reward-points: uint,
        active: bool
    }
)

(define-map player-quests
    { player: principal, quest-id: uint }
    { completed: bool, completed-at: uint }
)

(define-public (add-quest (quest-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (required-achievements (list 10 uint)) (reward-points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set quests
            { quest-id: quest-id }
            { 
                name: name,
                description: description,
                required-achievements: required-achievements,
                reward-points: reward-points,
                active: true
            }
        ))
    )
)

(define-public (complete-quest (quest-id uint))
    (let
        (
            (quest (unwrap! (map-get? quests { quest-id: quest-id }) err-invalid-quest))
            (required-achievements (get required-achievements quest))
            (reward-points (get reward-points quest))
        )
        (asserts! (get active quest) err-invalid-quest)
        ;; (asserts! (check-achievements-completed tx-sender required-achievements) err-quest-incomplete)
        (map-set player-quests
            { player: tx-sender, quest-id: quest-id }
            { completed: true, completed-at: stacks-block-height }
        )
        (update-player-points reward-points)
    )
)



(define-read-only (check-achievement (result bool) (achievement-id uint))
(ok true)
)



(define-constant err-already-referred (err u107))
(define-constant REFERRAL-BONUS u50)

(define-map referrals
    { referred: principal }
    { referrer: principal, processed: bool }
)

(define-map referral-counts
    { referrer: principal }
    { count: uint, total-bonus: uint }
)

(define-public (refer-player (referred principal))
    (begin
        (asserts! (not (is-eq tx-sender referred)) (err u101))
        (asserts! (is-none (map-get? referrals { referred: referred })) (err u107))
        (ok (map-set referrals
            { referred: referred }
            { referrer: tx-sender, processed: false }
        ))
    )
)

(define-public (claim-referral-bonus)
    (let
        (
            (referral-data (unwrap! (map-get? referrals { referred: tx-sender }) (err u1)))
            (referrer (get referrer referral-data))
            (processed (get processed referral-data))
            (current-count (default-to { count: u0, total-bonus: u0 } 
                (map-get? referral-counts { referrer: referrer })))
        )
        (asserts! (not processed) (err u404))
        (map-set referrals
            { referred: tx-sender }
            { referrer: referrer, processed: true }
        )
        (map-set referral-counts
            { referrer: referrer }
            { 
                count: (+ (get count current-count) u1),
                total-bonus: (+ (get total-bonus current-count) REFERRAL-BONUS)
            }
        )
        (update-player-points REFERRAL-BONUS)
    )
)

(define-read-only (get-referral-count (player principal))
    (map-get? referral-counts { referrer: player })
)



(define-constant err-season-inactive (err u108))

(define-map seasons
    { season-id: uint }
    { 
        name: (string-ascii 50),
        start-height: uint,
        end-height: uint,
        active: bool,
        bonus-multiplier: uint
    }
)

(define-map season-achievements
    { season-id: uint, achievement-id: uint }
    { active: bool, bonus-points: uint }
)

(define-map player-season-stats
    { player: principal, season-id: uint }
    { 
        points-earned: uint,
        achievements-completed: uint,
        rank: uint
    }
)

(define-public (create-season (season-id uint) (name (string-ascii 50)) (duration uint) (bonus-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set seasons
            { season-id: season-id }
            { 
                name: name,
                start-height: stacks-block-height,
                end-height: (+ stacks-block-height duration),
                active: true,
                bonus-multiplier: bonus-multiplier
            }
        ))
    )
)

(define-public (add-season-achievement (season-id uint) (achievement-id uint) (bonus-points uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set season-achievements
            { season-id: season-id, achievement-id: achievement-id }
            { active: true, bonus-points: bonus-points }
        ))
    )
)

(define-public (claim-season-achievement (season-id uint) (achievement-id uint))
    (let
        (
            (season (unwrap! (map-get? seasons { season-id: season-id }) err-invalid-achievement))
            (season-achievement (unwrap! (map-get? season-achievements 
                { season-id: season-id, achievement-id: achievement-id }) err-invalid-achievement))
            ;; (achievement-claim (claim-achievement achievement-id))
            (current-stats (default-to { points-earned: u0, achievements-completed: u0, rank: u0 } 
                (map-get? player-season-stats { player: tx-sender, season-id: season-id })))
            (bonus-points (get bonus-points season-achievement))
        )
        (asserts! (get active season) err-season-inactive)
        (asserts! (get active season-achievement) err-invalid-achievement)
        ;; (asserts! (is-ok achievement-claim) (unwrap-err! achievement-claim err-already-claimed))
        (map-set player-season-stats
            { player: tx-sender, season-id: season-id }
            { 
                points-earned: (+ (get points-earned current-stats) bonus-points),
                achievements-completed: (+ (get achievements-completed current-stats) u1),
                rank: (get rank current-stats)
            }
        )
        (update-player-points bonus-points)
    )
)


(define-constant err-insufficient-funds (err u109))
(define-constant err-not-for-sale (err u110))

(define-map marketplace-items
    { item-id: uint }
    { 
        name: (string-ascii 50),
        description: (string-ascii 200),
        price: uint,
        required-points: uint,
        available: bool,
        total-supply: uint,
        sold: uint
    }
)

(define-map player-items
    { player: principal, item-id: uint }
    { quantity: uint, purchased-at: uint }
)

(define-public (add-marketplace-item (item-id uint) (name (string-ascii 50)) (description (string-ascii 200)) (price uint) (required-points uint) (total-supply uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (ok (map-set marketplace-items
            { item-id: item-id }
            { 
                name: name,
                description: description,
                price: price,
                required-points: required-points,
                available: true,
                total-supply: total-supply,
                sold: u0
            }
        ))
    )
)

(define-public (purchase-item (item-id uint))
    (let
        (
            (item (unwrap! (map-get? marketplace-items { item-id: item-id }) err-invalid-achievement))
            (player-points (unwrap! (get-player-points tx-sender) err-insufficient-funds))
            (current-items (default-to { quantity: u0, purchased-at: u0 } 
                (map-get? player-items { player: tx-sender, item-id: item-id })))
            (price (get price item))
            (required-points (get required-points item))
            (available (get available item))
            (total-supply (get total-supply item))
            (sold (get sold item))
        )
        (asserts! available err-not-for-sale)
        (asserts! (< sold total-supply) err-not-for-sale)
        (asserts! (>= (get total-points player-points) required-points) err-insufficient-funds)
        
        (map-set player-items
            { player: tx-sender, item-id: item-id }
            { quantity: (+ (get quantity current-items) u1), purchased-at: stacks-block-height }
        )
        
        (map-set marketplace-items
            { item-id: item-id }
            (merge item { sold: (+ sold u1) })
        )
        
        (ok true)
    )
)

(define-read-only (get-player-items (player principal) (item-id uint))
    (map-get? player-items { player: player, item-id: item-id })
)


(define-constant err-team-full (err u111))
(define-constant err-not-team-member (err u112))
(define-constant MAX-TEAM-SIZE u5)

(define-map teams
    { team-id: uint }
    { 
        name: (string-ascii 50),
        leader: principal,
        members: (list 5 principal),
        total-points: uint,
        created-at: uint
    }
)

(define-map player-teams
    { player: principal }
    { team-id: uint }
)

(define-map team-achievements
    { team-id: uint, achievement-id: uint }
    { completed: bool, completed-at: uint }
)

(define-public (create-team (team-id uint) (name (string-ascii 50)))
    (begin
        (ok (map-set teams
            { team-id: team-id }
            { 
                name: name,
                leader: tx-sender,
                members: (list tx-sender),
                total-points: u0,
                created-at: stacks-block-height
            }
        ))
    )
)



(define-public (complete-team-achievement (team-id uint) (achievement-id uint))
    (let
        (
            (team (unwrap! (map-get? teams { team-id: team-id }) err-invalid-achievement))
            (members (get members team))
            (player-team (unwrap! (map-get? player-teams { player: tx-sender }) err-not-team-member))
            ;; (achievement (unwrap! (map-get? achievements { achievement-id: achievement-id }) err-invalid-achievement))
            ;; (points (get points u1))
        )
        (asserts! (is-eq (get team-id player-team) team-id) (err u112))
        (map-set team-achievements
            { team-id: team-id, achievement-id: achievement-id }
            { completed: true, completed-at: stacks-block-height }
        )
        (map-set teams
            { team-id: team-id }
            (merge team { total-points: (+ (get total-points team) u100) })
        )
        (ok (err u0))
    )
)


(define-non-fungible-token achievement-nft uint)

(define-constant err-not-achievement-owner (err u200))
(define-constant err-nft-exists (err u201))

(define-map nft-metadata
    { token-id: uint }
    {
        achievement-id: uint,
        player: principal,
        earned-at: uint,
        rarity: uint
    }
)

(define-map player-nft-count
    { player: principal }
    { count: uint }
)

(define-public (mint-achievement-nft (achievement-id uint))
    (let
        (
            ;; (achievement-claim (unwrap! (has-achievement tx-sender achievement-id) err-not-achievement-owner))
            (player-count (default-to { count: u0 } (map-get? player-nft-count { player: tx-sender })))
            (new-token-id (+ (* u1000000 achievement-id) (get count player-count)))
        )
        ;; (asserts! (get claimed achievement-claim) (err u200))
        (try! (nft-mint? achievement-nft new-token-id tx-sender))
        (map-set nft-metadata
            { token-id: new-token-id }
            {
                achievement-id: achievement-id,
                player: tx-sender,
                earned-at: stacks-block-height,
                rarity: u1
            }
        )
        (ok (map-set player-nft-count
            { player: tx-sender }
            { count: (+ (get count player-count) u1) }
        ))
    )
)

(define-read-only (get-nft-metadata (token-id uint))
    (map-get? nft-metadata { token-id: token-id })
)


(define-constant err-not-staked (err u300))
(define-constant err-already-staked (err u301))
(define-constant BLOCKS_PER_REWARD u144)
(define-constant BASE_REWARD_RATE u10)

(define-map staked-achievements
    { player: principal, achievement-id: uint }
    {
        staked-at: uint,
        last-claim: uint,
        multiplier: uint
    }
)

(define-map staking-rewards
    { player: principal }
    { pending-rewards: uint }
)

(define-public (stake-achievement (achievement-id uint))
    (let
        (
            ;; (achievement-claim (unwrap! (has-achievement tx-sender achievement-id) err-not-achievement-owner))
            (existing-stake (map-get? staked-achievements { player: tx-sender, achievement-id: achievement-id }))
        )
        (asserts! (is-none existing-stake) err-already-staked)
        (ok (map-set staked-achievements
            { player: tx-sender, achievement-id: achievement-id }
            {
                staked-at: stacks-block-height,
                last-claim: stacks-block-height,
                multiplier: u1
            }
        ))
    )
)

(define-public (claim-staking-rewards (achievement-id uint))
    (let
        (
            (stake-data (unwrap! (map-get? staked-achievements 
                { player: tx-sender, achievement-id: achievement-id }) err-not-staked))
            (blocks-staked (- stacks-block-height (get last-claim stake-data)))
            (reward-amount (* (/ blocks-staked BLOCKS_PER_REWARD) 
                            (* BASE_REWARD_RATE (get multiplier stake-data))))
        )
        (map-set staked-achievements
            { player: tx-sender, achievement-id: achievement-id }
            (merge stake-data { last-claim: stacks-block-height })
        )
        (update-player-points reward-amount)
    )
)