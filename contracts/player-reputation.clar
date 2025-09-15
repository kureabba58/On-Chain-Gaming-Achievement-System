;; Player Reputation & Trust System
;; A comprehensive reputation system for gaming achievements that tracks player credibility,
;; enables peer validation, and provides reputation-based privileges

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-invalid-player (err u601))
(define-constant err-invalid-reputation-level (err u602))
(define-constant err-insufficient-reputation (err u603))
(define-constant err-already-validated (err u604))
(define-constant err-self-validation (err u605))
(define-constant err-validation-cooldown (err u606))
(define-constant err-reputation-locked (err u607))
(define-constant err-invalid-endorsement (err u608))

;; Reputation level constants
(define-constant REP-ROOKIE u1)
(define-constant REP-TRUSTED u2)
(define-constant REP-VETERAN u3)
(define-constant REP-CHAMPION u4)
(define-constant REP-LEGEND u5)

;; Scoring constants
(define-constant BASE-REPUTATION-SCORE u100)
(define-constant VALIDATION-REWARD u5)
(define-constant ENDORSEMENT-REWARD u10)
(define-constant CONSISTENCY-BONUS u20)
(define-constant PENALTY-AMOUNT u15)
(define-constant VALIDATION-COOLDOWN u144) ;; blocks (approximately 1 day)

;; Main reputation tracking
(define-map player-reputation
    { player: principal }
    {
        current-score: uint,
        reputation-level: uint,
        total-validations-given: uint,
        total-validations-received: uint,
        total-endorsements: uint,
        consistency-streak: uint,
        last-activity: uint,
        trust-index: uint,
        penalty-count: uint,
        reputation-locked: bool
    }
)

;; Peer validation system
(define-map validation-requests
    { request-id: uint }
    {
        requester: principal,
        achievement-id: uint,
        evidence-hash: (string-ascii 64),
        validators-needed: uint,
        validators-confirmed: uint,
        status: uint, ;; 1=pending, 2=approved, 3=rejected
        created-at: uint,
        reward-pool: uint
    }
)

(define-map validation-votes
    { request-id: uint, validator: principal }
    {
        vote: bool, ;; true=approve, false=reject
        vote-weight: uint,
        voted-at: uint,
        reputation-at-vote: uint
    }
)

(define-map validator-history
    { validator: principal, request-id: uint }
    {
        correct-vote: bool,
        reputation-change: int
    }
)

;; Endorsement system
(define-map player-endorsements
    { endorser: principal, endorsee: principal }
    {
        endorsement-type: uint, ;; 1=skillful, 2=helpful, 3=reliable, 4=leadership
        strength: uint, ;; 1-5 scale
        given-at: uint,
        active: bool
    }
)

(define-map endorsement-summary
    { player: principal, endorsement-type: uint }
    {
        total-received: uint,
        average-strength: uint,
        unique-endorsers: uint
    }
)

;; Trust network analysis
(define-map trust-connections
    { trustor: principal, trustee: principal }
    {
        trust-level: uint, ;; 1-10 scale
        interaction-count: uint,
        last-interaction: uint,
        mutual-trust: bool
    }
)

(define-map reputation-milestones
    { player: principal, milestone-id: uint }
    {
        achieved: bool,
        achieved-at: uint,
        reward-claimed: bool
    }
)

;; Community reporting system
(define-map violation-reports
    { report-id: uint }
    {
        reporter: principal,
        reported-player: principal,
        violation-type: uint, ;; 1=cheating, 2=toxic, 3=fraud, 4=spam
        evidence: (string-ascii 200),
        status: uint, ;; 1=pending, 2=investigating, 3=resolved, 4=dismissed
        created-at: uint,
        moderator-assigned: (optional principal)
    }
)

;; Reputation-based privileges
(define-map reputation-privileges
    { reputation-level: uint }
    {
        daily-validation-limit: uint,
        endorsement-weight: uint,
        special-achievements-access: bool,
        marketplace-discount: uint,
        priority-support: bool
    }
)

;; Initialize reputation system
(define-public (initialize-reputation-privileges)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set reputation-privileges 
            { reputation-level: REP-ROOKIE } 
            { daily-validation-limit: u2, endorsement-weight: u1, special-achievements-access: false, marketplace-discount: u0, priority-support: false })
        (map-set reputation-privileges 
            { reputation-level: REP-TRUSTED } 
            { daily-validation-limit: u5, endorsement-weight: u2, special-achievements-access: false, marketplace-discount: u5, priority-support: false })
        (map-set reputation-privileges 
            { reputation-level: REP-VETERAN } 
            { daily-validation-limit: u10, endorsement-weight: u3, special-achievements-access: true, marketplace-discount: u10, priority-support: true })
        (map-set reputation-privileges 
            { reputation-level: REP-CHAMPION } 
            { daily-validation-limit: u15, endorsement-weight: u4, special-achievements-access: true, marketplace-discount: u15, priority-support: true })
        (ok (map-set reputation-privileges 
            { reputation-level: REP-LEGEND } 
            { daily-validation-limit: u25, endorsement-weight: u5, special-achievements-access: true, marketplace-discount: u20, priority-support: true }))
    )
)

;; Initialize player reputation
(define-public (initialize-player-reputation)
    (let
        (
            (existing-reputation (map-get? player-reputation { player: tx-sender }))
        )
        (asserts! (is-none existing-reputation) err-invalid-player)
        (ok (map-set player-reputation
            { player: tx-sender }
            {
                current-score: BASE-REPUTATION-SCORE,
                reputation-level: REP-ROOKIE,
                total-validations-given: u0,
                total-validations-received: u0,
                total-endorsements: u0,
                consistency-streak: u0,
                last-activity: stacks-block-height,
                trust-index: u50,
                penalty-count: u0,
                reputation-locked: false
            }
        ))
    )
)

;; Create validation request
(define-public (create-validation-request (request-id uint) (achievement-id uint) (evidence-hash (string-ascii 64)) (validators-needed uint))
    (let
        (
            (player-rep (unwrap! (map-get? player-reputation { player: tx-sender }) err-invalid-player))
        )
        (asserts! (not (get reputation-locked player-rep)) err-reputation-locked)
        (ok (map-set validation-requests
            { request-id: request-id }
            {
                requester: tx-sender,
                achievement-id: achievement-id,
                evidence-hash: evidence-hash,
                validators-needed: validators-needed,
                validators-confirmed: u0,
                status: u1,
                created-at: stacks-block-height,
                reward-pool: (* validators-needed VALIDATION-REWARD)
            }
        ))
    )
)

;; Vote on validation request
(define-public (vote-on-validation (request-id uint) (approve bool))
    (let
        (
            (request-data (unwrap! (map-get? validation-requests { request-id: request-id }) err-invalid-reputation-level))
            (voter-rep (unwrap! (map-get? player-reputation { player: tx-sender }) err-invalid-player))
            (existing-vote (map-get? validation-votes { request-id: request-id, validator: tx-sender }))
            (vote-weight (calculate-vote-weight (get reputation-level voter-rep)))
        )
        (asserts! (not (is-eq tx-sender (get requester request-data))) err-self-validation)
        (asserts! (is-none existing-vote) err-already-validated)
        (asserts! (is-eq (get status request-data) u1) err-invalid-reputation-level)
        (asserts! (not (get reputation-locked voter-rep)) err-reputation-locked)
        
        (map-set validation-votes
            { request-id: request-id, validator: tx-sender }
            {
                vote: approve,
                vote-weight: vote-weight,
                voted-at: stacks-block-height,
                reputation-at-vote: (get current-score voter-rep)
            }
        )
        
        (let
            (
                (new-confirmed-count (+ (get validators-confirmed request-data) u1))
                (approval-threshold (/ (* (get validators-needed request-data) u66) u100))
            )
            (map-set validation-requests
                { request-id: request-id }
                (merge request-data { validators-confirmed: new-confirmed-count })
            )
            
            (if (>= new-confirmed-count (get validators-needed request-data))
                (finalize-validation request-id)
                (ok true)
            )
        )
    )
)

;; Finalize validation after sufficient votes
(define-private (finalize-validation (request-id uint))
    (let
        (
            (request-data (unwrap! (map-get? validation-requests { request-id: request-id }) err-invalid-reputation-level))
            (approval-count (count-approval-votes request-id))
            (total-votes (get validators-confirmed request-data))
            (approval-rate (/ (* approval-count u100) total-votes))
            (final-status (if (>= approval-rate u60) u2 u3))
        )
        (map-set validation-requests
            { request-id: request-id }
            (merge request-data { status: final-status })
        )
        
        (if (is-eq final-status u2)
            (try! (update-requester-reputation (get requester request-data) true))
            (try! (update-requester-reputation (get requester request-data) false))
        )
        
        (ok (distribute-validation-rewards request-id final-status))
    )
)

;; Give endorsement to another player
(define-public (endorse-player (endorsee principal) (endorsement-type uint) (strength uint))
    (let
        (
            (endorser-rep (unwrap! (map-get? player-reputation { player: tx-sender }) err-invalid-player))
            (endorsee-rep (unwrap! (map-get? player-reputation { player: endorsee }) err-invalid-player))
            (existing-endorsement (map-get? player-endorsements { endorser: tx-sender, endorsee: endorsee }))
        )
        (asserts! (not (is-eq tx-sender endorsee)) err-self-validation)
        (asserts! (and (>= endorsement-type u1) (<= endorsement-type u4)) err-invalid-endorsement)
        (asserts! (and (>= strength u1) (<= strength u5)) err-invalid-endorsement)
        (asserts! (>= (get reputation-level endorser-rep) REP-TRUSTED) err-insufficient-reputation)
        (asserts! (not (get reputation-locked endorser-rep)) err-reputation-locked)
        
        (map-set player-endorsements
            { endorser: tx-sender, endorsee: endorsee }
            {
                endorsement-type: endorsement-type,
                strength: strength,
                given-at: stacks-block-height,
                active: true
            }
        )
        
        (unwrap-panic (update-endorsement-summary endorsee endorsement-type strength))
        (unwrap-panic (update-player-reputation-score endorsee ENDORSEMENT-REWARD))
        (ok true)
    )
)

;; Report violation
(define-public (report-violation (report-id uint) (reported-player principal) (violation-type uint) (evidence (string-ascii 200)))
    (let
        (
            (reporter-rep (unwrap! (map-get? player-reputation { player: tx-sender }) err-invalid-player))
        )
        (asserts! (not (is-eq tx-sender reported-player)) err-self-validation)
        (asserts! (and (>= violation-type u1) (<= violation-type u4)) err-invalid-endorsement)
        (asserts! (>= (get reputation-level reporter-rep) REP-TRUSTED) err-insufficient-reputation)
        (asserts! (not (get reputation-locked reporter-rep)) err-reputation-locked)
        
        (ok (map-set violation-reports
            { report-id: report-id }
            {
                reporter: tx-sender,
                reported-player: reported-player,
                violation-type: violation-type,
                evidence: evidence,
                status: u1,
                created-at: stacks-block-height,
                moderator-assigned: none
            }
        ))
    )
)

;; Update trust connection between players
(define-public (update-trust-connection (trustee principal) (trust-level uint))
    (let
        (
            (trustor-rep (unwrap! (map-get? player-reputation { player: tx-sender }) err-invalid-player))
            (existing-connection (default-to 
                { trust-level: u5, interaction-count: u0, last-interaction: u0, mutual-trust: false }
                (map-get? trust-connections { trustor: tx-sender, trustee: trustee })))
        )
        (asserts! (not (is-eq tx-sender trustee)) err-self-validation)
        (asserts! (and (>= trust-level u1) (<= trust-level u10)) err-invalid-endorsement)
        (asserts! (not (get reputation-locked trustor-rep)) err-reputation-locked)
        
        (ok (map-set trust-connections
            { trustor: tx-sender, trustee: trustee }
            {
                trust-level: trust-level,
                interaction-count: (+ (get interaction-count existing-connection) u1),
                last-interaction: stacks-block-height,
                mutual-trust: (check-mutual-trust tx-sender trustee trust-level)
            }
        ))
    )
)

;; Helper functions
(define-private (calculate-vote-weight (reputation-level uint))
    (if (is-eq reputation-level REP-LEGEND) u5
        (if (is-eq reputation-level REP-CHAMPION) u4
            (if (is-eq reputation-level REP-VETERAN) u3
                (if (is-eq reputation-level REP-TRUSTED) u2 u1))))
)

(define-private (count-approval-votes (request-id uint))
    ;; This would typically iterate through votes, simplified for demo
    u1
)

(define-private (update-requester-reputation (requester principal) (approved bool))
    (let
        (
            (current-rep (unwrap! (map-get? player-reputation { player: requester }) err-invalid-player))
            (score-change (if approved VALIDATION-REWARD (- u0 PENALTY-AMOUNT)))
            (new-score (if approved 
                (+ (get current-score current-rep) score-change)
                (if (>= (get current-score current-rep) PENALTY-AMOUNT)
                    (- (get current-score current-rep) PENALTY-AMOUNT)
                    u0)))
            (new-level (calculate-reputation-level new-score))
        )
        (ok (map-set player-reputation
            { player: requester }
            (merge current-rep {
                current-score: new-score,
                reputation-level: new-level,
                total-validations-received: (+ (get total-validations-received current-rep) u1),
                last-activity: stacks-block-height,
                penalty-count: (if approved (get penalty-count current-rep) (+ (get penalty-count current-rep) u1))
            })
        ))
    )
)

(define-private (distribute-validation-rewards (request-id uint) (final-status uint))
    ;; Simplified reward distribution
    true
)

(define-private (update-endorsement-summary (endorsee principal) (endorsement-type uint) (strength uint))
    (let
        (
            (current-summary (default-to 
                { total-received: u0, average-strength: u0, unique-endorsers: u0 }
                (map-get? endorsement-summary { player: endorsee, endorsement-type: endorsement-type })))
            (new-total (+ (get total-received current-summary) u1))
            (new-average (/ (+ (* (get average-strength current-summary) (get total-received current-summary)) strength) new-total))
        )
        (ok (map-set endorsement-summary
            { player: endorsee, endorsement-type: endorsement-type }
            {
                total-received: new-total,
                average-strength: new-average,
                unique-endorsers: (+ (get unique-endorsers current-summary) u1)
            }
        ))
    )
)

(define-private (update-player-reputation-score (player principal) (score-change uint))
    (let
        (
            (current-rep (unwrap! (map-get? player-reputation { player: player }) err-invalid-player))
            (new-score (+ (get current-score current-rep) score-change))
            (new-level (calculate-reputation-level new-score))
        )
        (ok (map-set player-reputation
            { player: player }
            (merge current-rep {
                current-score: new-score,
                reputation-level: new-level,
                total-endorsements: (+ (get total-endorsements current-rep) u1),
                last-activity: stacks-block-height
            })
        ))
    )
)

(define-private (calculate-reputation-level (score uint))
    (if (>= score u500) REP-LEGEND
        (if (>= score u350) REP-CHAMPION
            (if (>= score u250) REP-VETERAN
                (if (>= score u150) REP-TRUSTED REP-ROOKIE))))
)

(define-private (check-mutual-trust (trustor principal) (trustee principal) (trust-level uint))
    (match (map-get? trust-connections { trustor: trustee, trustee: trustor })
        reverse-connection (and (>= (get trust-level reverse-connection) u7) (>= trust-level u7))
        false
    )
)

;; Read-only functions
(define-read-only (get-player-reputation (player principal))
    (map-get? player-reputation { player: player })
)

(define-read-only (get-validation-request (request-id uint))
    (map-get? validation-requests { request-id: request-id })
)

(define-read-only (get-validation-vote (request-id uint) (validator principal))
    (map-get? validation-votes { request-id: request-id, validator: validator })
)

(define-read-only (get-player-endorsement (endorser principal) (endorsee principal))
    (map-get? player-endorsements { endorser: endorser, endorsee: endorsee })
)

(define-read-only (get-endorsement-summary (player principal) (endorsement-type uint))
    (map-get? endorsement-summary { player: player, endorsement-type: endorsement-type })
)

(define-read-only (get-trust-connection (trustor principal) (trustee principal))
    (map-get? trust-connections { trustor: trustor, trustee: trustee })
)

(define-read-only (get-violation-report (report-id uint))
    (map-get? violation-reports { report-id: report-id })
)

(define-read-only (get-reputation-privileges (reputation-level uint))
    (map-get? reputation-privileges { reputation-level: reputation-level })
)

(define-read-only (check-reputation-requirement (player principal) (min-level uint))
    (match (map-get? player-reputation { player: player })
        rep-data (>= (get reputation-level rep-data) min-level)
        false
    )
)
