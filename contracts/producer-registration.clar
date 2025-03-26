;; Producer Registration Contract
;; Records details of artisanal cheesemakers

;; Define data maps
(define-map producers
  { id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    established-year: uint,
    contact: principal,
    active: bool
  }
)

;; Define data maps for cheese varieties
(define-map cheese-varieties
  { producer-id: uint, variety-id: uint }
  {
    name: (string-ascii 100),
    milk-type: (string-ascii 50),
    style: (string-ascii 50),
    aging-time: uint
  }
)

;; Define ID counters
(define-data-var next-producer-id uint u1)
(define-data-var next-variety-id uint u1)

;; Error codes
(define-constant err-invalid-input u1)
(define-constant err-not-found u2)
(define-constant err-not-authorized u3)

;; Read-only functions
(define-read-only (get-producer (id uint))
  (map-get? producers { id: id })
)

(define-read-only (get-cheese-variety (producer-id uint) (variety-id uint))
  (map-get? cheese-varieties { producer-id: producer-id, variety-id: variety-id })
)

;; Public functions
(define-public (register-producer
    (name (string-ascii 100))
    (location (string-ascii 100))
    (established-year uint))

  (begin
    ;; Check inputs
    (asserts! (> (len name) u0) (err err-invalid-input))
    (asserts! (> (len location) u0) (err err-invalid-input))
    (asserts! (> established-year u0) (err err-invalid-input))

    ;; Insert producer data
    (map-set producers
      { id: (var-get next-producer-id) }
      {
        name: name,
        location: location,
        established-year: established-year,
        contact: tx-sender,
        active: true
      }
    )

    ;; Increment producer ID counter
    (var-set next-producer-id (+ (var-get next-producer-id) u1))

    ;; Return success with producer ID
    (ok (- (var-get next-producer-id) u1))
  )
)

(define-public (update-producer
    (id uint)
    (location (string-ascii 100)))

  (let ((producer (unwrap! (get-producer id) (err err-not-found))))
    ;; Check authorization
    (asserts! (is-eq tx-sender (get contact producer)) (err err-not-authorized))

    ;; Check inputs
    (asserts! (> (len location) u0) (err err-invalid-input))

    ;; Update producer data
    (map-set producers
      { id: id }
      (merge producer { location: location })
    )

    ;; Return success
    (ok true)
  )
)

(define-public (set-producer-status (id uint) (active bool))
  (let ((producer (unwrap! (get-producer id) (err err-not-found))))
    ;; Check authorization
    (asserts! (is-eq tx-sender (get contact producer)) (err err-not-authorized))

    ;; Update producer status
    (map-set producers
      { id: id }
      (merge producer { active: active })
    )

    ;; Return success
    (ok true)
  )
)

(define-public (register-cheese-variety
    (producer-id uint)
    (name (string-ascii 100))
    (milk-type (string-ascii 50))
    (style (string-ascii 50))
    (aging-time uint))

  (let ((producer (unwrap! (get-producer producer-id) (err err-not-found))))
    ;; Check authorization
    (asserts! (is-eq tx-sender (get contact producer)) (err err-not-authorized))

    ;; Check inputs
    (asserts! (> (len name) u0) (err err-invalid-input))
    (asserts! (> (len milk-type) u0) (err err-invalid-input))
    (asserts! (> (len style) u0) (err err-invalid-input))

    ;; Register cheese variety
    (map-set cheese-varieties
      { producer-id: producer-id, variety-id: (var-get next-variety-id) }
      {
        name: name,
        milk-type: milk-type,
        style: style,
        aging-time: aging-time
      }
    )

    ;; Increment variety ID counter
    (var-set next-variety-id (+ (var-get next-variety-id) u1))

    ;; Return success with variety ID
    (ok (- (var-get next-variety-id) u1))
  )
)

