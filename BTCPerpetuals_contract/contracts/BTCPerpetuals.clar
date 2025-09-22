
;; title: BTCPerpetuals
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool for Bitcoin perpetual futures on Stacks
;; description: A decentralized perpetual futures trading platform for Bitcoin with AMM-based liquidity provision

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u104))
(define-constant ERR-POSITION-NOT-FOUND (err u105))
(define-constant ERR-POSITION-UNDERWATER (err u106))
(define-constant ERR-INVALID-LEVERAGE (err u107))
(define-constant ERR-PRICE-TOO-OLD (err u108))

;; Basis points for calculations (10000 = 100%)
(define-constant BASIS-POINTS u10000)
(define-constant MAX-LEVERAGE u10) ;; 10x maximum leverage
(define-constant LIQUIDATION-THRESHOLD u8000) ;; 80%
(define-constant FEE-RATE u30) ;; 0.3% trading fee

;; data vars
;;
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-liquidity uint u0)
(define-data-var btc-reserve uint u0)
(define-data-var stx-reserve uint u0)
(define-data-var position-counter uint u0)
(define-data-var emergency-shutdown bool false)
(define-data-var oracle-price uint u0)
(define-data-var oracle-timestamp uint u0)

;; data maps
;;
;; Liquidity provider balances
(define-map liquidity-providers principal uint)

;; User positions
(define-map positions
  { position-id: uint }
  {
    owner: principal,
    size: uint,
    collateral: uint,
    leverage: uint,
    entry-price: uint,
    is-long: bool,
    timestamp: uint
  }
)

;; User position IDs
(define-map user-positions principal (list 100 uint))

;; Fee collection
(define-map collected-fees principal uint)

;; public functions
;;

;; Add liquidity to the pool
(define-public (add-liquidity (stx-amount uint))
  (let
    (
      (sender tx-sender)
      (current-liquidity (var-get total-liquidity))
      (current-stx-reserve (var-get stx-reserve))
    )
    (asserts! (not (var-get emergency-shutdown)) ERR-NOT-AUTHORIZED)
    (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)

    ;; Transfer STX from user
    (try! (stx-transfer? stx-amount sender (as-contract tx-sender)))

    ;; Calculate liquidity tokens to mint
    (let
      (
        (liquidity-to-mint
          (if (is-eq current-liquidity u0)
            stx-amount ;; Initial liquidity
            (/ (* stx-amount current-liquidity) current-stx-reserve)
          )
        )
      )
      ;; Update reserves and liquidity
      (var-set stx-reserve (+ current-stx-reserve stx-amount))
      (var-set total-liquidity (+ current-liquidity liquidity-to-mint))

      ;; Update user's liquidity balance
      (map-set liquidity-providers
        sender
        (+ (default-to u0 (map-get? liquidity-providers sender)) liquidity-to-mint)
      )

      (ok liquidity-to-mint)
    )
  )
)

;; Remove liquidity from the pool
(define-public (remove-liquidity (liquidity-amount uint))
  (let
    (
      (sender tx-sender)
      (user-liquidity (default-to u0 (map-get? liquidity-providers sender)))
      (current-liquidity (var-get total-liquidity))
      (current-stx-reserve (var-get stx-reserve))
    )
    (asserts! (>= user-liquidity liquidity-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> liquidity-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> current-liquidity u0) ERR-INSUFFICIENT-LIQUIDITY)

    ;; Calculate STX to return
    (let
      (
        (stx-to-return (/ (* liquidity-amount current-stx-reserve) current-liquidity))
      )
      ;; Update reserves and liquidity
      (var-set stx-reserve (- current-stx-reserve stx-to-return))
      (var-set total-liquidity (- current-liquidity liquidity-amount))

      ;; Update user's liquidity balance
      (map-set liquidity-providers sender (- user-liquidity liquidity-amount))

      ;; Transfer STX back to user
      (try! (as-contract (stx-transfer? stx-to-return tx-sender sender)))

      (ok stx-to-return)
    )
  )
)

;; Open a perpetual position
(define-public (open-position (collateral-amount uint) (leverage uint) (is-long bool))
  (let
    (
      (sender tx-sender)
      (current-price (var-get oracle-price))
      (position-id (+ (var-get position-counter) u1))
      (position-size (* collateral-amount leverage))
      (fee-amount (/ (* position-size FEE-RATE) BASIS-POINTS))
    )
    (asserts! (not (var-get emergency-shutdown)) ERR-NOT-AUTHORIZED)
    (asserts! (> collateral-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (and (> leverage u0) (<= leverage MAX-LEVERAGE)) ERR-INVALID-LEVERAGE)
    (asserts! (> current-price u0) ERR-PRICE-TOO-OLD)
    (asserts! (< (- block-height (var-get oracle-timestamp)) u10) ERR-PRICE-TOO-OLD)

    ;; Transfer collateral + fee from user
    (try! (stx-transfer? (+ collateral-amount fee-amount) sender (as-contract tx-sender)))

    ;; Create position
    (map-set positions
      { position-id: position-id }
      {
        owner: sender,
        size: position-size,
        collateral: collateral-amount,
        leverage: leverage,
        entry-price: current-price,
        is-long: is-long,
        timestamp: block-height
      }
    )

    ;; Update user positions list
    (let
      (
        (current-positions (default-to (list) (map-get? user-positions sender)))
      )
      (map-set user-positions sender (unwrap! (as-max-len? (append current-positions position-id) u100) ERR-INVALID-AMOUNT))
    )

    ;; Update position counter
    (var-set position-counter position-id)

    ;; Collect fees
    (map-set collected-fees
      (var-get contract-owner)
      (+ (default-to u0 (map-get? collected-fees (var-get contract-owner))) fee-amount)
    )

    (ok position-id)
  )
)

;; Close a perpetual position
(define-public (close-position (position-id uint))
  (let
    (
      (sender tx-sender)
      (position (unwrap! (map-get? positions { position-id: position-id }) ERR-POSITION-NOT-FOUND))
      (current-price (var-get oracle-price))
    )
    (asserts! (is-eq (get owner position) sender) ERR-NOT-AUTHORIZED)
    (asserts! (> current-price u0) ERR-PRICE-TOO-OLD)
    (asserts! (< (- block-height (var-get oracle-timestamp)) u10) ERR-PRICE-TOO-OLD)

    ;; Calculate PnL
    (let
      (
        (entry-price (get entry-price position))
        (position-size (get size position))
        (collateral (get collateral position))
        (is-long (get is-long position))
        (price-diff (if is-long
                      (if (> current-price entry-price) (- current-price entry-price) (- entry-price current-price))
                      (if (> entry-price current-price) (- entry-price current-price) (- current-price entry-price))))
        (pnl (/ (* position-size price-diff) entry-price))
        (fee-amount (/ (* position-size FEE-RATE) BASIS-POINTS))
        (net-pnl (if is-long
                   (if (> current-price entry-price) pnl (- u0 pnl))
                   (if (> entry-price current-price) pnl (- u0 pnl))))
        (final-amount (if (>= net-pnl collateral)
                       (- (+ collateral net-pnl) fee-amount)
                       (if (>= collateral (+ (- u0 net-pnl) fee-amount))
                         (- collateral (+ (- u0 net-pnl) fee-amount))
                         u0)))
      )

      ;; Remove position
      (map-delete positions { position-id: position-id })

      ;; Transfer final amount to user (if any)
      (if (> final-amount u0)
        (try! (as-contract (stx-transfer? final-amount tx-sender sender)))
        true
      )

      ;; Collect fees
      (map-set collected-fees
        (var-get contract-owner)
        (+ (default-to u0 (map-get? collected-fees (var-get contract-owner))) fee-amount)
      )

      (ok final-amount)
    )
  )
)

;; Update price oracle (owner only)
(define-public (update-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (asserts! (> new-price u0) ERR-INVALID-AMOUNT)
    (var-set oracle-price new-price)
    (var-set oracle-timestamp block-height)
    (ok true)
  )
)

;; Emergency shutdown (owner only)
(define-public (set-emergency-shutdown)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (var-set emergency-shutdown true)
    (ok true)
  )
)

;; Withdraw collected fees (owner only)
(define-public (withdraw-fees)
  (let
    (
      (owner (var-get contract-owner))
      (fee-amount (default-to u0 (map-get? collected-fees owner)))
    )
    (asserts! (is-eq tx-sender owner) ERR-OWNER-ONLY)
    (asserts! (> fee-amount u0) ERR-INSUFFICIENT-BALANCE)

    (map-set collected-fees owner u0)
    (try! (as-contract (stx-transfer? fee-amount tx-sender owner)))
    (ok fee-amount)
  )
)

;; read only functions
;;

;; Get position details
(define-read-only (get-position (position-id uint))
  (map-get? positions { position-id: position-id })
)

;; Get user's liquidity balance
(define-read-only (get-liquidity-balance (user principal))
  (default-to u0 (map-get? liquidity-providers user))
)

;; Get user positions
(define-read-only (get-user-positions (user principal))
  (default-to (list) (map-get? user-positions user))
)

;; Get pool stats
(define-read-only (get-pool-stats)
  {
    total-liquidity: (var-get total-liquidity),
    stx-reserve: (var-get stx-reserve),
    btc-reserve: (var-get btc-reserve),
    oracle-price: (var-get oracle-price),
    oracle-timestamp: (var-get oracle-timestamp)
  }
)

;; Get contract state
(define-read-only (get-contract-state)
  {
    owner: (var-get contract-owner),
    emergency-shutdown: (var-get emergency-shutdown),
    position-counter: (var-get position-counter)
  }
)

;; Calculate position health (for liquidation monitoring)
(define-read-only (get-position-health (position-id uint))
  (match (map-get? positions { position-id: position-id })
    position
    (let
      (
        (current-price (var-get oracle-price))
        (entry-price (get entry-price position))
        (collateral (get collateral position))
        (leverage (get leverage position))
        (is-long (get is-long position))
        (price-change (if is-long
                       (if (> current-price entry-price)
                         (/ (* (- current-price entry-price) BASIS-POINTS) entry-price)
                         (- u0 (/ (* (- entry-price current-price) BASIS-POINTS) entry-price)))
                       (if (> entry-price current-price)
                         (/ (* (- entry-price current-price) BASIS-POINTS) entry-price)
                         (- u0 (/ (* (- current-price entry-price) BASIS-POINTS) entry-price)))))
        (pnl-percent (/ (* price-change leverage) BASIS-POINTS))
        (health-ratio (+ BASIS-POINTS pnl-percent))
      )
      (some health-ratio)
    )
    none
  )
)

;; private functions
;;

