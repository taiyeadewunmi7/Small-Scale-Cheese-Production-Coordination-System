;; Quality Verification Contract
;; Tracks testing for safety and characteristics

;; Define data maps
(define-map quality-tests
  { id: uint }
  {
    producer-id: uint,
    cheese-variety-id: uint,
    batch-identifier: (string-ascii 50),
    tester: principal,
    status: (string-ascii 20)
  }
)

;; Define data maps for test results
(define-map test-results
  { test-id: uint }
  {
    safety-passed: bool,
    flavor-score: uint,
    texture-score: uint,
    overall-score: uint,
    notes: (string-ascii 200)
  }
)

;; Define data maps for certified testers
(define-map certified-testers
  { tester: principal }
  {
    name: (string-ascii 100),
    certification-level: uint,
    active: bool
  }
)

;; Define ID counter
(define-data-var next-test-id uint u1)

;; Error codes
(define-constant err-invalid-input u1)
(define-constant err-not-found u2)
(define-constant err-not-authorized u3)
(define-constant err-not-certified u4)

;; Read-only functions
(define-read-only (get-quality-test (id uint))
  (map-get? quality-tests { id: id })
)

(define-read-only (get-test-result (test-id uint))
  (map-get? test-results { test-id: test-id })
)

(define-read-only (get-certified-tester (tester principal))
  (map-get? certified-testers { tester: tester })
)

(define-read-only (is-certified-tester (tester principal))
  (default-to false (get active (map-get? certified-testers { tester: tester })))
)

;; Public functions
(define-public (register-certified-tester
    (name (string-ascii 100))
    (certification-level uint))

  (begin
    ;; Check inputs
    (asserts! (> (len name) u0) (err err-invalid-input))
    (asserts! (> certification-level u0) (err err-invalid-input))

    ;; Register tester
    (map-set certified-testers
      { tester: tx-sender }
      {
        name: name,
        certification-level: certification-level,
        active: true
      }
    )

    ;; Return success
    (ok true)
  )
)

(define-public (register-quality-test
    (producer-id uint)
    (cheese-variety-id uint)
    (batch-identifier (string-ascii 50)))

  (begin
    ;; Check tester is certified
    (asserts! (is-certified-tester tx-sender) (err err-not-certified))

    ;; Check inputs
    (asserts! (> producer-id u0) (err err-invalid-input))
    (asserts! (> cheese-variety-id u0) (err err-invalid-input))
    (asserts! (> (len batch-identifier) u0) (err err-invalid-input))

    ;; Register quality test
    (map-set quality-tests
      { id: (var-get next-test-id) }
      {
        producer-id: producer-id,
        cheese-variety-id: cheese-variety-id,
        batch-identifier: batch-identifier,
        tester: tx-sender,
        status: "PENDING"
      }
    )

    ;; Increment test ID counter
    (var-set next-test-id (+ (var-get next-test-id) u1))

    ;; Return success with test ID
    (ok (- (var-get next-test-id) u1))
  )
)

(define-public (record-test-results
    (test-id uint)
    (safety-passed bool)
    (flavor-score uint)
    (texture-score uint)
    (overall-score uint)
    (notes (string-ascii 200)))

  (let ((test (unwrap! (get-quality-test test-id) (err err-not-found))))
    ;; Check authorization
    (asserts! (is-eq tx-sender (get tester test)) (err err-not-authorized))

    ;; Check inputs
    (asserts! (<= flavor-score u10) (err err-invalid-input))
    (asserts! (<= texture-score u10) (err err-invalid-input))
    (asserts! (<= overall-score u10) (err err-invalid-input))

    ;; Record test results
    (map-set test-results
      { test-id: test-id }
      {
        safety-passed: safety-passed,
        flavor-score: flavor-score,
        texture-score: texture-score,
        overall-score: overall-score,
        notes: notes
      }
    )

    ;; Update test status
    (map-set quality-tests
      { id: test-id }
      (merge test { status: (if safety-passed "PASSED" "FAILED") })
    )

    ;; Return success
    (ok true)
  )
)

