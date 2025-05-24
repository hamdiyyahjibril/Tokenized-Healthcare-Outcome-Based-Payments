;; Provider Verification Contract
;; Manages healthcare provider registration and verification

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))

;; Provider data structure
(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialty: (string-ascii 50),
    verified: bool,
    registration-block: uint
  }
)

;; Track verified providers
(define-map verified-providers principal bool)

;; Register a new healthcare provider
(define-public (register-provider (name (string-ascii 100))
                                 (license-number (string-ascii 50))
                                 (specialty (string-ascii 50)))
  (let ((provider-id tx-sender))
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (asserts! (> (len license-number) u0) ERR_INVALID_LICENSE)

    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        license-number: license-number,
        specialty: specialty,
        verified: false,
        registration-block: block-height
      }
    )
    (ok provider-id)
  )
)

;; Verify a provider (admin only)
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)

    (map-set verified-providers provider-id true)
    (map-set providers
      { provider-id: provider-id }
      (merge (unwrap-panic (map-get? providers { provider-id: provider-id }))
             { verified: true })
    )
    (ok true)
  )
)

;; Check if provider is verified
(define-read-only (is-verified-provider (provider-id principal))
  (default-to false (map-get? verified-providers provider-id))
)

;; Get provider details
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)
