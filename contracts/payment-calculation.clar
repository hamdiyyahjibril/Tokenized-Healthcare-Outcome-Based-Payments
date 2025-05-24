;; Payment Calculation Contract
;; Determines outcome-based compensation for providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_PAYMENT (err u501))
(define-constant ERR_PAYMENT_EXISTS (err u502))
(define-constant ERR_INSUFFICIENT_OUTCOMES (err u503))

;; Payment structures
(define-map payment-models
  { model-id: uint }
  {
    base-payment: uint,
    outcome-bonus: uint,
    risk-adjustment-factor: uint,
    minimum-patients: uint,
    payment-period: uint
  }
)

;; Provider payments
(define-map provider-payments
  { provider-id: principal, cohort-id: uint, period: uint }
  {
    base-amount: uint,
    outcome-bonus: uint,
    risk-adjustment: uint,
    total-payment: uint,
    patients-treated: uint,
    successful-outcomes: uint,
    payment-block: uint,
    paid: bool
  }
)

;; Payment model counter
(define-data-var payment-model-counter uint u0)

;; Create payment model
(define-public (create-payment-model (base-payment uint)
                                    (outcome-bonus uint)
                                    (risk-adjustment-factor uint)
                                    (minimum-patients uint)
                                    (payment-period uint))
  (let ((model-id (+ (var-get payment-model-counter) u1)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set payment-models
      { model-id: model-id }
      {
        base-payment: base-payment,
        outcome-bonus: outcome-bonus,
        risk-adjustment-factor: risk-adjustment-factor,
        minimum-patients: minimum-patients,
        payment-period: payment-period
      }
    )
    (var-set payment-model-counter model-id)
    (ok model-id)
  )
)

;; Calculate provider payment
(define-public (calculate-payment (provider-id principal)
                                 (cohort-id uint)
                                 (period uint)
                                 (model-id uint)
                                 (patients-treated uint)
                                 (successful-outcomes uint)
                                 (average-risk-multiplier uint))
  (let ((payment-model (unwrap! (map-get? payment-models { model-id: model-id }) ERR_INVALID_PAYMENT))
        (base-amount (* (get base-payment payment-model) patients-treated))
        (outcome-bonus-amount (* (get outcome-bonus payment-model) successful-outcomes))
        (risk-adjustment (/ (* base-amount average-risk-multiplier) u100))
        (total-payment (+ base-amount outcome-bonus-amount risk-adjustment)))

    (asserts! (>= patients-treated (get minimum-patients payment-model)) ERR_INSUFFICIENT_OUTCOMES)
    (asserts! (is-none (map-get? provider-payments
                                { provider-id: provider-id, cohort-id: cohort-id, period: period })) ERR_PAYMENT_EXISTS)

    (map-set provider-payments
      { provider-id: provider-id, cohort-id: cohort-id, period: period }
      {
        base-amount: base-amount,
        outcome-bonus: outcome-bonus-amount,
        risk-adjustment: risk-adjustment,
        total-payment: total-payment,
        patients-treated: patients-treated,
        successful-outcomes: successful-outcomes,
        payment-block: block-height,
        paid: false
      }
    )
    (ok total-payment)
  )
)

;; Mark payment as completed
(define-public (mark-payment-completed (provider-id principal) (cohort-id uint) (period uint))
  (let ((payment (unwrap! (map-get? provider-payments
                                   { provider-id: provider-id, cohort-id: cohort-id, period: period }) ERR_INVALID_PAYMENT)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set provider-payments
      { provider-id: provider-id, cohort-id: cohort-id, period: period }
      (merge payment { paid: true })
    )
    (ok true)
  )
)

;; Get payment details
(define-read-only (get-payment (provider-id principal) (cohort-id uint) (period uint))
  (map-get? provider-payments { provider-id: provider-id, cohort-id: cohort-id, period: period })
)

;; Get payment model
(define-read-only (get-payment-model (model-id uint))
  (map-get? payment-models { model-id: model-id })
)
