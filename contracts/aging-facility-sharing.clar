;; Aging Facility Sharing Contract
;; Manages access to specialized storage

;; Define data maps
(define-map facilities
  { id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    capacity: uint,
    temperature: (string-ascii 20),
    humidity: (string-ascii 20),
    owner: principal,
    active: bool
  }
)

;; Define data maps for facility slots
(define-map slots
  { facility-id: uint, slot-id: uint }
  {
    name: (string-ascii 50),
    capacity: uint,
    available: bool
  }
)

;; Define data maps for bookings
(define-map bookings
  { facility-id: uint, slot-id: uint, booking-id: uint }
  {
    producer: principal,
    start-time: uint,
    end-time: uint,
    status: (string-ascii 20)
  }
)

;; Define ID counters
(define-data-var next-facility-id uint u1)
(define-data-var next-slot-id uint u1)
(define-data-var next-booking-id uint u1)

;; Error codes
(define-constant err-invalid-input u1)
(define-constant err-not-found u2)
(define-constant err-not-authorized u3)
(define-constant err-not-available u4)

;; Read-only functions
(define-read-only (get-facility (id uint))
  (map-get? facilities { id: id })
)

(define-read-only (get-slot (facility-id uint) (slot-id uint))
  (map-get? slots { facility-id: facility-id, slot-id: slot-id })
)

(define-read-only (get-booking (facility-id uint) (slot-id uint) (booking-id uint))
  (map-get? bookings { facility-id: facility-id, slot-id: slot-id, booking-id: booking-id })
)

;; Public functions
(define-public (register-facility
    (name (string-ascii 100))
    (location (string-ascii 100))
    (capacity uint)
    (temperature (string-ascii 20))
    (humidity (string-ascii 20)))

  (begin
    ;; Check inputs
    (asserts! (> (len name) u0) (err err-invalid-input))
    (asserts! (> (len location) u0) (err err-invalid-input))
    (asserts! (> capacity u0) (err err-invalid-input))
    (asserts! (> (len temperature) u0) (err err-invalid-input))
    (asserts! (> (len humidity) u0) (err err-invalid-input))

    ;; Register facility
    (map-set facilities
      { id: (var-get next-facility-id) }
      {
        name: name,
        location: location,
        capacity: capacity,
        temperature: temperature,
        humidity: humidity,
        owner: tx-sender,
        active: true
      }
    )

    ;; Increment facility ID counter
    (var-set next-facility-id (+ (var-get next-facility-id) u1))

    ;; Return success with facility ID
    (ok (- (var-get next-facility-id) u1))
  )
)

(define-public (add-slot
    (facility-id uint)
    (name (string-ascii 50))
    (capacity uint))

  (let ((facility (unwrap! (get-facility facility-id) (err err-not-found))))
    ;; Check authorization
    (asserts! (is-eq tx-sender (get owner facility)) (err err-not-authorized))

    ;; Check inputs
    (asserts! (> (len name) u0) (err err-invalid-input))
    (asserts! (> capacity u0) (err err-invalid-input))

    ;; Add slot
    (map-set slots
      { facility-id: facility-id, slot-id: (var-get next-slot-id) }
      {
        name: name,
        capacity: capacity,
        available: true
      }
    )

    ;; Increment slot ID counter
    (var-set next-slot-id (+ (var-get next-slot-id) u1))

    ;; Return success with slot ID
    (ok (- (var-get next-slot-id) u1))
  )
)

(define-public (book-slot
    (facility-id uint)
    (slot-id uint)
    (start-time uint)
    (end-time uint))

  (let (
    (facility (unwrap! (get-facility facility-id) (err err-not-found)))
    (slot (unwrap! (get-slot facility-id slot-id) (err err-not-found)))
  )
    ;; Check slot is available
    (asserts! (get available slot) (err err-not-available))

    ;; Check booking time is valid
    (asserts! (> end-time start-time) (err err-invalid-input))
    (asserts! (>= start-time block-height) (err err-invalid-input))

    ;; Create booking
    (map-set bookings
      { facility-id: facility-id, slot-id: slot-id, booking-id: (var-get next-booking-id) }
      {
        producer: tx-sender,
        start-time: start-time,
        end-time: end-time,
        status: "BOOKED"
      }
    )

    ;; Update slot availability
    (map-set slots
      { facility-id: facility-id, slot-id: slot-id }
      (merge slot { available: false })
    )

    ;; Increment booking ID counter
    (var-set next-booking-id (+ (var-get next-booking-id) u1))

    ;; Return success with booking ID
    (ok (- (var-get next-booking-id) u1))
  )
)

(define-public (complete-booking
    (facility-id uint)
    (slot-id uint)
    (booking-id uint))

  (let (
    (facility (unwrap! (get-facility facility-id) (err err-not-found)))
    (booking (unwrap! (get-booking facility-id slot-id booking-id) (err err-not-found)))
    (slot (unwrap! (get-slot facility-id slot-id) (err err-not-found)))
  )
    ;; Check authorization
    (asserts! (or
      (is-eq tx-sender (get owner facility))
      (is-eq tx-sender (get producer booking))
    ) (err err-not-authorized))

    ;; Update booking status
    (map-set bookings
      { facility-id: facility-id, slot-id: slot-id, booking-id: booking-id }
      (merge booking { status: "COMPLETED" })
    )

    ;; Make slot available again
    (map-set slots
      { facility-id: facility-id, slot-id: slot-id }
      (merge slot { available: true })
    )

    ;; Return success
    (ok true)
  )
)

