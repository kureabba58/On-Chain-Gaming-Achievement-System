(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-invalid-difficulty (err u401))
(define-constant err-adjustment-too-soon (err u402))

(define-constant MIN-DIFFICULTY u1)
(define-constant MAX-DIFFICULTY u10)
(define-constant BASE-DIFFICULTY u5)
(define-constant ADJUSTMENT-THRESHOLD u100)
(define-constant MIN-ADJUSTMENT-INTERVAL u1000)

(define-map achievement-difficulty
    { achievement-id: uint }
    {
        current-difficulty: uint,
        base-requirement: uint,
        current-requirement: uint,
        completion-count: uint,
        attempt-count: uint,
        last-adjustment: uint
    }
)

(define-map difficulty-multipliers
    { difficulty-level: uint }
    {
        requirement-multiplier: uint,
        reward-multiplier: uint,
        point-bonus: uint
    }
)

(define-map player-difficulty-stats
    { player: principal }
    {
        average-completion-rate: uint,
        preferred-difficulty: uint,
        total-attempts: uint,
        total-completions: uint
    }
)

(define-public (initialize-achievement-difficulty (achievement-id uint) (base-requirement uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set achievement-difficulty
            { achievement-id: achievement-id }
            {
                current-difficulty: BASE-DIFFICULTY,
                base-requirement: base-requirement,
                current-requirement: base-requirement,
                completion-count: u0,
                attempt-count: u0,
                last-adjustment: stacks-block-height
            }
        ))
    )
)

(define-public (setup-difficulty-multipliers)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set difficulty-multipliers { difficulty-level: u1 } { requirement-multiplier: u50, reward-multiplier: u80, point-bonus: u0 })
        (map-set difficulty-multipliers { difficulty-level: u2 } { requirement-multiplier: u60, reward-multiplier: u85, point-bonus: u5 })
        (map-set difficulty-multipliers { difficulty-level: u3 } { requirement-multiplier: u70, reward-multiplier: u90, point-bonus: u10 })
        (map-set difficulty-multipliers { difficulty-level: u4 } { requirement-multiplier: u80, reward-multiplier: u95, point-bonus: u15 })
        (map-set difficulty-multipliers { difficulty-level: u5 } { requirement-multiplier: u100, reward-multiplier: u100, point-bonus: u20 })
        (map-set difficulty-multipliers { difficulty-level: u6 } { requirement-multiplier: u120, reward-multiplier: u110, point-bonus: u30 })
        (map-set difficulty-multipliers { difficulty-level: u7 } { requirement-multiplier: u140, reward-multiplier: u120, point-bonus: u40 })
        (map-set difficulty-multipliers { difficulty-level: u8 } { requirement-multiplier: u160, reward-multiplier: u130, point-bonus: u50 })
        (map-set difficulty-multipliers { difficulty-level: u9 } { requirement-multiplier: u180, reward-multiplier: u140, point-bonus: u60 })
        (ok (map-set difficulty-multipliers { difficulty-level: u10 } { requirement-multiplier: u200, reward-multiplier: u150, point-bonus: u75 }))
    )
)

(define-public (record-achievement-attempt (achievement-id uint) (completed bool))
    (let
        (
            (difficulty-data (unwrap! (map-get? achievement-difficulty { achievement-id: achievement-id }) err-invalid-difficulty))
            (player-stats (default-to { average-completion-rate: u50, preferred-difficulty: BASE-DIFFICULTY, total-attempts: u0, total-completions: u0 }
                (map-get? player-difficulty-stats { player: tx-sender })))
            (new-attempt-count (+ (get attempt-count difficulty-data) u1))
            (new-completion-count (if completed (+ (get completion-count difficulty-data) u1) (get completion-count difficulty-data)))
            (new-total-attempts (+ (get total-attempts player-stats) u1))
            (new-total-completions (if completed (+ (get total-completions player-stats) u1) (get total-completions player-stats)))
        )
        (map-set achievement-difficulty
            { achievement-id: achievement-id }
            (merge difficulty-data { 
                attempt-count: new-attempt-count,
                completion-count: new-completion-count
            })
        )
        (map-set player-difficulty-stats
            { player: tx-sender }
            {
                average-completion-rate: (if (> new-total-attempts u0) (/ (* new-total-completions u100) new-total-attempts) u50),
                preferred-difficulty: (get preferred-difficulty player-stats),
                total-attempts: new-total-attempts,
                total-completions: new-total-completions
            }
        )
        (try! (auto-adjust-difficulty achievement-id))
        (ok completed)
    )
)

(define-public (auto-adjust-difficulty (achievement-id uint))
    (let
        (
            (difficulty-data (unwrap! (map-get? achievement-difficulty { achievement-id: achievement-id }) err-invalid-difficulty))
            (attempt-count (get attempt-count difficulty-data))
            (completion-count (get completion-count difficulty-data))
            (current-difficulty (get current-difficulty difficulty-data))
            (last-adjustment (get last-adjustment difficulty-data))
            (blocks-since-adjustment (- stacks-block-height last-adjustment))
        )
        (asserts! (>= blocks-since-adjustment MIN-ADJUSTMENT-INTERVAL) err-adjustment-too-soon)
        (asserts! (>= attempt-count ADJUSTMENT-THRESHOLD) (ok false))
        
        (let
            (
                (completion-rate (/ (* completion-count u100) attempt-count))
                (new-difficulty 
                    (if (> completion-rate u70)
                        (if (< current-difficulty MAX-DIFFICULTY) (+ current-difficulty u1) current-difficulty)
                        (if (< completion-rate u30)
                            (if (> current-difficulty MIN-DIFFICULTY) (- current-difficulty u1) current-difficulty)
                            current-difficulty)))
                (multiplier-data (unwrap! (map-get? difficulty-multipliers { difficulty-level: new-difficulty }) err-invalid-difficulty))
                (new-requirement (/ (* (get base-requirement difficulty-data) (get requirement-multiplier multiplier-data)) u100))
            )
            (ok (map-set achievement-difficulty
                { achievement-id: achievement-id }
                (merge difficulty-data {
                    current-difficulty: new-difficulty,
                    current-requirement: new-requirement,
                    last-adjustment: stacks-block-height,
                    attempt-count: u0,
                    completion-count: u0
                })
            ))
        )
    )
)

(define-public (calculate-dynamic-reward (achievement-id uint) (base-points uint))
    (let
        (
            (difficulty-data (unwrap! (map-get? achievement-difficulty { achievement-id: achievement-id }) err-invalid-difficulty))
            (current-difficulty (get current-difficulty difficulty-data))
            (multiplier-data (unwrap! (map-get? difficulty-multipliers { difficulty-level: current-difficulty }) err-invalid-difficulty))
            (reward-multiplier (get reward-multiplier multiplier-data))
            (point-bonus (get point-bonus multiplier-data))
            (final-points (+ (/ (* base-points reward-multiplier) u100) point-bonus))
        )
        (ok final-points)
    )
)

(define-public (set-player-preferred-difficulty (preferred-difficulty uint))
    (let
        (
            (player-stats (default-to { average-completion-rate: u50, preferred-difficulty: BASE-DIFFICULTY, total-attempts: u0, total-completions: u0 }
                (map-get? player-difficulty-stats { player: tx-sender })))
        )
        (asserts! (and (>= preferred-difficulty MIN-DIFFICULTY) (<= preferred-difficulty MAX-DIFFICULTY)) err-invalid-difficulty)
        (ok (map-set player-difficulty-stats
            { player: tx-sender }
            (merge player-stats { preferred-difficulty: preferred-difficulty })
        ))
    )
)

(define-public (get-personalized-achievement-difficulty (achievement-id uint) (player principal))
    (let
        (
            (difficulty-data (unwrap! (map-get? achievement-difficulty { achievement-id: achievement-id }) err-invalid-difficulty))
            (player-stats (default-to { average-completion-rate: u50, preferred-difficulty: BASE-DIFFICULTY, total-attempts: u0, total-completions: u0 }
                (map-get? player-difficulty-stats { player: player })))
            (base-difficulty (get current-difficulty difficulty-data))
            (player-preference (get preferred-difficulty player-stats))
            (player-skill (get average-completion-rate player-stats))
            (adjusted-difficulty 
                (if (> player-skill u70)
                    (if (< base-difficulty MAX-DIFFICULTY) (+ base-difficulty u1) base-difficulty)
                    (if (< player-skill u30)
                        (if (> base-difficulty MIN-DIFFICULTY) (- base-difficulty u1) base-difficulty)
                        base-difficulty)))
            (final-difficulty (/ (+ adjusted-difficulty player-preference) u2))
        )
        (ok final-difficulty)
    )
)

(define-read-only (get-achievement-difficulty-info (achievement-id uint))
    (map-get? achievement-difficulty { achievement-id: achievement-id })
)

(define-read-only (get-player-difficulty-stats (player principal))
    (map-get? player-difficulty-stats { player: player })
)

(define-read-only (get-difficulty-multiplier (difficulty-level uint))
    (map-get? difficulty-multipliers { difficulty-level: difficulty-level })
)

(define-read-only (get-current-completion-rate (achievement-id uint))
    (match (map-get? achievement-difficulty { achievement-id: achievement-id })
        difficulty-data 
            (let
                (
                    (attempts (get attempt-count difficulty-data))
                    (completions (get completion-count difficulty-data))
                )
                (if (> attempts u0)
                    (some (/ (* completions u100) attempts))
                    (some u0)
                )
            )
        none
    )
)