;; Outcome Measurement Contract
;; Tracks and validates health outcome improvements

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_OUTCOME (err u301))
(define-constant ERR_PATIENT_NOT_FOUND (err u302))
(define-constant ERR_OUTCOME_EXISTS (err u303))

;; Outcome measurements
(define-map patient-outcomes
  { patient-id: (string-ascii 50), cohort-id: uint, measurement-type: (string-ascii 50) }
  {
    baseline-value: uint,
    current-value: uint,
    improvement-percentage: uint,
    measurement-block: uint,
    verified: bool
  }
)

;; Outcome thresholds for success
(define-map outcome-thresholds
  { measurement-type: (string-ascii 50) }
  {
    minimum-improvement: uint,
    target-improvement: uint,
    maximum-timeframe: uint
  }
)

;; Record patient outcome measurement
(define-public (record-outcome (patient-id (string-ascii 50))
                              (cohort-id uint)
                              (measurement-type (string-ascii 50))
                              (baseline-value uint)
                              (current-value uint))
  (let ((improvement (if (> current-value baseline-value)
                        (/ (* (- current-value baseline-value) u100) baseline-value)
                        u0)))
    (asserts! (> (len patient-id) u0) ERR_INVALID_OUTCOME)
    (asserts! (is-none (map-get? patient-outcomes
                                { patient-id: patient-id,
                                  cohort-id: cohort-id,
                                  measurement-type: measurement-type })) ERR_OUTCOME_EXISTS)

    (map-set patient-outcomes
      { patient-id: patient-id, cohort-id: cohort-id, measurement-type: measurement-type }
      {
        baseline-value: baseline-value,
        current-value: current-value,
        improvement-percentage: improvement,
        measurement-block: block-height,
        verified: false
      }
    )
    (ok improvement)
  )
)

;; Set outcome thresholds
(define-public (set-outcome-threshold (measurement-type (string-ascii 50))
                                     (minimum-improvement uint)
                                     (target-improvement uint)
                                     (maximum-timeframe uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set outcome-thresholds
      { measurement-type: measurement-type }
      {
        minimum-improvement: minimum-improvement,
        target-improvement: target-improvement,
        maximum-timeframe: maximum-timeframe
      }
    )
    (ok true)
  )
)

;; Verify outcome measurement (admin only)
(define-public (verify-outcome (patient-id (string-ascii 50))
                              (cohort-id uint)
                              (measurement-type (string-ascii 50)))
  (let ((outcome (unwrap! (map-get? patient-outcomes
                                   { patient-id: patient-id,
                                     cohort-id: cohort-id,
                                     measurement-type: measurement-type }) ERR_PATIENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set patient-outcomes
      { patient-id: patient-id, cohort-id: cohort-id, measurement-type: measurement-type }
      (merge outcome { verified: true })
    )
    (ok true)
  )
)

;; Get patient outcome
(define-read-only (get-patient-outcome (patient-id (string-ascii 50))
                                      (cohort-id uint)
                                      (measurement-type (string-ascii 50)))
  (map-get? patient-outcomes { patient-id: patient-id, cohort-id: cohort-id, measurement-type: measurement-type })
)

;; Check if outcome meets threshold
(define-read-only (meets-outcome-threshold (measurement-type (string-ascii 50)) (improvement uint))
  (match (map-get? outcome-thresholds { measurement-type: measurement-type })
    threshold (>= improvement (get minimum-improvement threshold))
    false
  )
)
