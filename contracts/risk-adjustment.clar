;; Risk Adjustment Contract
;; Accounts for patient complexity and risk factors

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_RISK_FACTOR (err u401))
(define-constant ERR_PATIENT_NOT_FOUND (err u402))

;; Risk factor weights
(define-map risk-factor-weights
  { risk-factor: (string-ascii 50) }
  { weight: uint, category: (string-ascii 30) }
)

;; Patient risk scores
(define-map patient-risk-scores
  { patient-id: (string-ascii 50), cohort-id: uint }
  {
    base-risk-score: uint,
    adjusted-risk-score: uint,
    risk-factors: (list 5 (string-ascii 50)),
    calculation-block: uint
  }
)

;; Set risk factor weight
(define-public (set-risk-factor-weight (risk-factor (string-ascii 50))
                                      (weight uint)
                                      (category (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len risk-factor) u0) ERR_INVALID_RISK_FACTOR)

    (map-set risk-factor-weights
      { risk-factor: risk-factor }
      { weight: weight, category: category }
    )
    (ok true)
  )
)

;; Calculate patient risk score
(define-public (calculate-risk-score (patient-id (string-ascii 50))
                                    (cohort-id uint)
                                    (base-score uint)
                                    (risk-factors (list 5 (string-ascii 50))))
  (let ((adjusted-score (fold calculate-risk-adjustment risk-factors base-score)))
    (map-set patient-risk-scores
      { patient-id: patient-id, cohort-id: cohort-id }
      {
        base-risk-score: base-score,
        adjusted-risk-score: adjusted-score,
        risk-factors: risk-factors,
        calculation-block: block-height
      }
    )
    (ok adjusted-score)
  )
)

;; Helper function to calculate risk adjustment
(define-private (calculate-risk-adjustment (risk-factor (string-ascii 50)) (current-score uint))
  (match (map-get? risk-factor-weights { risk-factor: risk-factor })
    weight-data (+ current-score (get weight weight-data))
    current-score
  )
)

;; Get risk adjustment multiplier
(define-read-only (get-risk-multiplier (patient-id (string-ascii 50)) (cohort-id uint))
  (match (map-get? patient-risk-scores { patient-id: patient-id, cohort-id: cohort-id })
    risk-data (if (> (get base-risk-score risk-data) u0)
                 (/ (* (get adjusted-risk-score risk-data) u100) (get base-risk-score risk-data))
                 u100)
    u100
  )
)

;; Get patient risk score
(define-read-only (get-patient-risk-score (patient-id (string-ascii 50)) (cohort-id uint))
  (map-get? patient-risk-scores { patient-id: patient-id, cohort-id: cohort-id })
)
